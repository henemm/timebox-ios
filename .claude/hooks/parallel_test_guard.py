#!/usr/bin/env python3
"""
Parallel Test Guard - PreToolUse Hook (Bash)

TWO-LAYER protection against parallel test runs:

1. WORKFLOW CONFLICT CHECK:
   Blocks xcodebuild test when OTHER recently active workflows have
   unfinished TDD RED tests that pollute the build/test results.

2. PROCESS LOCK CHECK:
   Blocks xcodebuild test when another Claude Code session is already
   running tests (pgrep + lock file with PPID tracking).

Lock File (.claude/test_execution_lock.json):
{
  "ppid": 12345,           # Claude Code CLI PID (parent of hook)
  "created": "ISO timestamp",
  "command": "xcodebuild test ..."
}

Stale lock detection:
- PPID alive AND pgrep finds xcodebuild -> BLOCK (real lock)
- PPID alive but no xcodebuild -> stale lock, cleanup
- PPID dead -> stale lock, cleanup

Exit Codes:
- 0: Allowed (no conflicts)
- 2: Blocked (parallel conflict or active test lock)
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Import load_state from the correct module (reads workflow_state.json)
try:
    from workflow_state_multi import load_state
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import load_state
    except ImportError:
        def load_state():
            return {"version": "2.0", "workflows": {}, "active_workflow": None}


STALE_THRESHOLD_HOURS = 48


def has_valid_override_token() -> bool:
    """Check if user has granted an override token (1h TTL)."""
    token_path = Path(__file__).parent.parent / "user_override_token.json"
    if not token_path.exists():
        return False
    try:
        token = json.loads(token_path.read_text())
        created = datetime.fromisoformat(token.get("created", ""))
        return datetime.now() - created < timedelta(hours=1)
    except (json.JSONDecodeError, ValueError, OSError):
        return False


def is_test_command(command: str) -> bool:
    """Check if this is an xcodebuild test command (not just text containing those words)."""
    stripped = command.strip()
    if stripped.startswith("git "):
        return False
    return bool(re.search(r'(?:^|[;&|]\s*)xcodebuild\s+.*\btest\b', command))


def is_recently_active(wf: dict) -> bool:
    """Check if workflow was updated within the last 48 hours."""
    ts = wf.get("last_updated") or wf.get("created")
    if not ts:
        return False
    try:
        updated = datetime.fromisoformat(str(ts))
        return datetime.now() - updated < timedelta(hours=STALE_THRESHOLD_HOURS)
    except (ValueError, TypeError):
        return False


def get_conflicting_workflows() -> list[dict]:
    """Find recently active workflows with unfinished TDD RED tests."""
    state = load_state()

    workflows = state.get("workflows", {})
    active = state.get("active_workflow", "")

    conflicts = []
    for name, wf in workflows.items():
        if name == active:
            continue

        phase = wf.get("current_phase", wf.get("phase", ""))
        if phase == "phase8_complete":
            continue

        if not is_recently_active(wf):
            continue

        has_red = wf.get("red_test_done", False)
        if not has_red:
            continue

        artifacts = wf.get("test_artifacts", [])
        if not artifacts:
            continue

        conflicts.append({
            "name": name,
            "phase": phase,
            "description": wf.get("description", ""),
            "red_result": wf.get("red_test_result", ""),
        })

    return conflicts


# --- Process Lock Layer ---

def get_lock_file() -> Path:
    """Get path to the test execution lock file."""
    return Path(__file__).parent.parent / "test_execution_lock.json"


def is_process_alive(pid: int) -> bool:
    """Check if a process with given PID is still running."""
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def find_running_xcodebuild_tests() -> list[dict]:
    """Find running xcodebuild test processes via pgrep."""
    try:
        result = subprocess.run(
            ["pgrep", "-fl", "xcodebuild"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode != 0:
            return []

        running = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(" ", 1)
            if len(parts) < 2:
                continue
            pid = parts[0]
            cmdline = parts[1]
            if "test" in cmdline or "build-for-testing" in cmdline:
                running.append({"pid": pid, "command": cmdline[:100]})
        return running
    except (subprocess.TimeoutExpired, Exception):
        return []


def check_test_lock() -> tuple[bool, str]:
    """
    Check if another Claude Code session holds the test lock.

    Returns (blocked, reason).
    """
    lock_file = get_lock_file()
    if not lock_file.exists():
        return False, ""

    try:
        lock_data = json.loads(lock_file.read_text())
    except (json.JSONDecodeError, OSError):
        # Corrupted lock file -> clean up
        lock_file.unlink(missing_ok=True)
        return False, ""

    lock_ppid = lock_data.get("ppid", 0)
    my_ppid = os.getppid()

    # Same session -> allow (we're the lock holder)
    if lock_ppid == my_ppid:
        return False, ""

    # Check if lock holder is still alive
    if not is_process_alive(lock_ppid):
        # PPID dead -> stale lock
        lock_file.unlink(missing_ok=True)
        return False, ""

    # PPID alive -> check if xcodebuild is actually running
    running = find_running_xcodebuild_tests()
    if not running:
        # PPID alive but no xcodebuild -> stale lock
        lock_file.unlink(missing_ok=True)
        return False, ""

    # PPID alive AND xcodebuild running -> real lock
    pids = ", ".join(r["pid"] for r in running)
    return True, (
        f"Andere Claude Code Session (PID {lock_ppid}) fuehrt bereits Tests aus.\n"
        f"Laufende xcodebuild Prozesse: {pids}\n"
        f"Parallele Test-Laeufe blockieren sich gegenseitig (Simulator-Lock).\n"
        f"Warte bis der laufende Test fertig ist."
    )


def acquire_test_lock(command: str) -> None:
    """Write the test execution lock file."""
    lock_file = get_lock_file()
    lock_data = {
        "ppid": os.getppid(),
        "created": datetime.now().isoformat(),
        "command": command[:200],
    }
    try:
        lock_file.parent.mkdir(parents=True, exist_ok=True)
        lock_file.write_text(json.dumps(lock_data, indent=2))
    except OSError:
        pass  # Non-fatal: lock is best-effort


def main():
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
        command = data.get("command", "")
    except json.JSONDecodeError:
        sys.exit(0)

    if not command or not is_test_command(command):
        sys.exit(0)

    # Layer 1: Process lock check (pgrep + PPID)
    blocked, reason = check_test_lock()
    if blocked:
        print(f"\nBLOCKED: {reason}", file=sys.stderr)
        sys.exit(2)

    # Layer 2: Workflow conflict check (skipped with valid override token)
    conflicts = get_conflicting_workflows()
    if conflicts and not has_valid_override_token():
        lines = [
            "",
            "BLOCKED: Parallele Workflows mit unfertigen RED-Tests erkannt!",
            "",
            f"{len(conflicts)} andere Workflow(s) haben TDD-RED-Tests die den Build/Test stoeren:",
            "",
        ]
        for c in conflicts[:5]:
            lines.append(f"  - {c['name']}: {c['description']}")
            lines.append(f"    Phase: {c['phase']}, RED: {c['red_result'][:60]}")
            lines.append("")
        lines.extend([
            "Optionen:",
            "  1. Nur EIGENE Tests isoliert ausfuehren (-only-testing:...)",
            "  2. Henning informieren und auf parallelen Workflow warten",
            "",
        ])
        print("\n".join(lines), file=sys.stderr)
        sys.exit(2)

    # All checks passed -> acquire lock and allow
    acquire_test_lock(command)
    sys.exit(0)


if __name__ == "__main__":
    main()
