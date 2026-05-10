#!/usr/bin/env python3
"""
Bash Gate v3 — Consolidated PreToolUse Hook for Bash

Replaces 15 separate hooks with 1. Sequential logic:

1. Stop-Lock → BLOCK
2. State-Integrity: protected file + write indicator → BLOCK (whitelist exceptions)
3. Secrets: sensitive file + content output → BLOCK
4. Sim-Enforcer: xcrun/xcodebuild without sim.sh → BLOCK
5. Build-Lock: xcodebuild → acquire/wait
6. Git Commit gates (ACTIVE-todos, adversary, etc.)
7. TDD GREEN Gate
8. ALLOW

Exit Codes: 0 = allowed, 2 = blocked
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

# Session ID extracted from stdin JSON (set during _get_command())
_STDIN_SESSION_ID = ""

# --- Configuration ---

SENSITIVE_PATTERNS = [
    r"\.env", r"credentials\.json", r"service[_-]?account.*\.json",
    r"_key", r"_secret", r"\.pem$", r"\.key$",
]

ALWAYS_BLOCKED_SECRETS = [
    r"credentials\.json", r"service[_-]?account.*\.json",
    r"_key", r"_secret", r"\.pem$", r"\.key$",
]

CONTENT_OUTPUT_COMMANDS = [
    r"\bcat\b", r"\bhead\b", r"\btail\b", r"\bless\b", r"\bmore\b",
    r"\bsed\b.*-n.*p", r"\bawk\b.*print",
]

PROTECTED_FILE_PATTERNS = [
    r"\.claude/workflows/[^\s]*\.json",
    r"workflow_state\.json",
    r"user_override_token\.json",
    r"\.claude/hooks/[^\s]*\.py",
    r"\.claude/settings\.json",
    r"project\.pbxproj",
]

WRITE_INDICATORS = [
    r"json\.dump", r"open\(", r"write\(", r"sed\s+-i", r"mv\s", r"cp\s",
    r"echo\s", r"printf\s", r"python3?\s+-c", r"tee\s", r"rm\s",
    r"touch\s", r"cat\s*<<", r"unlink", r"truncate",
]

WHITELIST_COMMANDS = [
    "workflow.py", "qa_gate.py",
    "git add", "git commit", "git diff", "git status", "git log", "git push",
    "add_file_to_project.py",
]

ALLOWED_SCRIPTS = ["sim.sh", "run_resilient_tests.sh", "adversary_screenshot.sh",
                   "run-mac-ui-tests.sh", "run-mac-unit-tests.sh"]

BLOCKED_SIMCTL = {
    "boot", "shutdown", "erase", "delete", "install", "uninstall",
    "launch", "terminate", "io", "create", "clone",
}

READONLY_XCODEBUILD = {"-list", "-showBuildSettings", "-showdestinations", "-version"}

BUILD_LOCK_FILE = None  # Set lazily
POLL_INTERVAL = 5
MAX_WAIT = 240


def _project_root() -> Path:
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _build_lock_path() -> Path:
    return _project_root() / ".claude" / "build_lock.json"


def _is_stop_locked() -> bool:
    """Check if stop-lock is active for the current session."""
    lock = _project_root() / ".claude" / "stop_lock.json"
    if not lock.exists():
        return False
    try:
        data = json.loads(lock.read_text())
        # v2: per-session stop locks
        if data.get("version") == 2:
            sessions = data.get("sessions", {})
            if not sessions:
                return False
            sid = os.environ.get("CLAUDE_SESSION_ID", "")
            # Locked if this session or __global__ is in the map
            return sid in sessions or "__global__" in sessions
        # v1 backward compat
        return data.get("enabled", False)
    except (json.JSONDecodeError, OSError):
        return False


def _get_command() -> str:
    global _STDIN_SESSION_ID
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
            _STDIN_SESSION_ID = data.get("session_id", "")
        except (json.JSONDecodeError, Exception):
            return ""
    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        return ""
    return data.get("command", "")


def _is_whitelisted(command: str) -> bool:
    for allowed in WHITELIST_COMMANDS:
        if allowed in command:
            return True
    return False


def _references_protected(command: str) -> bool:
    for p in PROTECTED_FILE_PATTERNS:
        if re.search(p, command):
            return True
    return False


def _has_write_indicator(command: str) -> bool:
    for p in WRITE_INDICATORS:
        if re.search(p, command):
            return True
    redirect = re.finditer(r"(?<!\d)>{1,2}\s*(\S+)", command)
    for m in redirect:
        if m.group(1) != "/dev/null":
            return True
    return False


def _is_sensitive(path: str, patterns: list) -> bool:
    for p in patterns:
        if re.search(p, path, re.IGNORECASE):
            return True
    return False


def _outputs_content(command: str) -> bool:
    for p in CONTENT_OUTPUT_COMMANDS:
        if re.search(p, command):
            return True
    return False


def _uses_wrapper(command: str) -> bool:
    return any(s in command for s in ALLOWED_SCRIPTS)


def _is_xcodebuild(command: str) -> bool:
    if command.strip().startswith("git "):
        return False
    return "xcodebuild" in command


def _get_session_id() -> str:
    """Get session identifier. Prefers env var, then stdin, falls back to PPID."""
    sid = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    if sid:
        return f"session:{sid}"
    return f"ppid:{os.getppid()}"


def _try_acquire_build_lock(command: str) -> bool:
    lock_path = _build_lock_path()
    my_id = _get_session_id()
    if lock_path.exists():
        try:
            lock = json.loads(lock_path.read_text())
            holder_id = lock.get("holder_id", "")
            # Backward compat: old locks have "ppid" but no "holder_id"
            if not holder_id and "ppid" in lock:
                holder_id = f"ppid:{lock['ppid']}"
            if holder_id == my_id:
                return True
            # Check if holder process is still alive (only for ppid-based)
            if holder_id.startswith("ppid:"):
                try:
                    os.kill(int(holder_id.split(":")[1]), 0)
                except (OSError, ProcessLookupError, ValueError):
                    lock_path.unlink(missing_ok=True)
                    # Fall through to acquire
                else:
                    return False
            elif holder_id.startswith("session:"):
                # Session-based: check staleness by timestamp (max 10 min)
                created = lock.get("created", "")
                if created:
                    try:
                        age = (datetime.now() - datetime.fromisoformat(created)).total_seconds()
                        if age > 600:  # 10 min stale threshold
                            lock_path.unlink(missing_ok=True)
                            # Fall through to acquire
                        else:
                            return False
                    except (ValueError, TypeError):
                        return False
                else:
                    return False
            else:
                return False
        except (json.JSONDecodeError, OSError):
            lock_path.unlink(missing_ok=True)
    # Acquire
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.write_text(json.dumps({
        "holder_id": my_id,
        "ppid": os.getppid(),  # Keep for backward compat / debugging
        "created": datetime.now().isoformat(),
        "command": command[:200],
    }))
    return True


def main():
    if os.environ.get("CLAUDE_ADMIN"):
        sys.exit(0)
    command = _get_command()
    if not command:
        sys.exit(0)

    # 1. Stop-lock
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active.", file=sys.stderr)
        sys.exit(2)

    # Git commands always pass (early exit for performance) — EXCEPT git commit
    if command.lstrip().startswith("git ") and "git commit" not in command:
        sys.exit(0)

    # 2. State-integrity: protected file + write indicator
    if _references_protected(command):
        if _is_whitelisted(command):
            sys.exit(0)
        if _has_write_indicator(command):
            print("BLOCKED: Direct state file manipulation. Use workflow.py CLI.", file=sys.stderr)
            sys.exit(2)

    # 3. Secrets guard
    if _is_sensitive(command, SENSITIVE_PATTERNS) and _outputs_content(command):
        if _is_sensitive(command, ALWAYS_BLOCKED_SECRETS):
            print("BLOCKED: Secrets guard — sensitive credentials/keys.", file=sys.stderr)
            sys.exit(2)
        # .env in non-staging
        staging = (_project_root() / ".claude" / "staging").exists()
        if not staging:
            print("BLOCKED: Secrets guard — .env file. Enable staging mode with: touch .claude/staging", file=sys.stderr)
            sys.exit(2)

    # 4. Sim-enforcer
    has_simctl = "xcrun simctl" in command
    has_xcodebuild = "xcodebuild" in command
    if has_simctl or has_xcodebuild:
        if _uses_wrapper(command):
            pass  # Allowed — handled by build lock below
        elif has_simctl:
            match = re.search(r"xcrun\s+simctl\s+(\w+)", command)
            if match and match.group(1) in BLOCKED_SIMCTL:
                print("BLOCKED: Direct xcrun simctl. Use ./scripts/sim.sh instead.", file=sys.stderr)
                sys.exit(2)
            elif match and match.group(1) not in {"list", "listapps", "getenv", "get_app_container"}:
                print("BLOCKED: Direct xcrun simctl. Use ./scripts/sim.sh instead.", file=sys.stderr)
                sys.exit(2)
        elif has_xcodebuild:
            if any(f in command for f in READONLY_XCODEBUILD):
                pass  # Read-only
            else:
                print("BLOCKED: Direct xcodebuild. Use ./scripts/sim.sh instead.", file=sys.stderr)
                sys.exit(2)

    # 5. Build-lock for xcodebuild
    if _is_xcodebuild(command):
        if not _try_acquire_build_lock(command):
            waited = 0
            while waited < MAX_WAIT:
                time.sleep(POLL_INTERVAL)
                waited += POLL_INTERVAL
                if _try_acquire_build_lock(command):
                    break
            else:
                print(f"BLOCKED: Build-lock timeout after {MAX_WAIT}s.", file=sys.stderr)
                sys.exit(2)

    # 6. Git commit gates
    if "git commit" in command and "--amend" not in command:
        # 6a. Issue-Link fuer fix:/feat: Commits
        is_fix_or_feat = bool(re.search(r'(?:^|[\n"\'])(?:fix|feat)[:(]', command, re.MULTILINE))
        has_issue_ref = bool(re.search(r'#\d+', command))
        if is_fix_or_feat and not has_issue_ref:
            print("BLOCKED: fix:/feat: commits must reference a GitHub Issue (e.g. 'fixes #42').", file=sys.stderr)
            sys.exit(2)

        # 6b. Checkpoint 3 Gate — kein Commit ohne Hennings Freigabe
        if is_fix_or_feat:
            wf_dir = _project_root() / ".claude" / "workflows"
            active_wf = None
            # Try session mapping
            session_id = os.environ.get("CLAUDE_SESSION_ID", "")
            if session_id:
                sessions_file = wf_dir / ".sessions.json"
                if sessions_file.exists():
                    try:
                        sessions = json.loads(sessions_file.read_text())
                        wf_name = sessions.get(session_id)
                        if wf_name:
                            wf_path = wf_dir / f"{wf_name}.json"
                            if wf_path.exists():
                                active_wf = json.loads(wf_path.read_text())
                    except (json.JSONDecodeError, OSError):
                        pass
            # Fallback: .active symlink
            if not active_wf:
                link = wf_dir / ".active"
                if link.is_symlink():
                    try:
                        target = Path(os.readlink(str(link)))
                        if not target.is_absolute():
                            target = link.parent / target
                        if target.exists():
                            active_wf = json.loads(target.read_text())
                    except (json.JSONDecodeError, OSError):
                        pass
            if active_wf:
                if not active_wf.get("checkpoint3_approved"):
                    print("BLOCKED: Kein Commit ohne Checkpoint 3! "
                          "Präsentiere Henning das Ergebnis (ALL GREEN + Screenshot). "
                          "Henning muss 'commit' sagen.", file=sys.stderr)
                    sys.exit(2)
                # 6c. Adversary-Findings Gate
                findings = active_wf.get("adversary_findings", [])
                unresolved = [f for f in findings if f.get("status") is None]
                if unresolved:
                    print(f"BLOCKED: {len(unresolved)} Adversary-Finding(s) noch offen. "
                          "Jedes Finding muss von Henning beantwortet werden.",
                          file=sys.stderr)
                    sys.exit(2)
                # 6d. Adversary-Verdict Gate
                verdict = active_wf.get("adversary_verdict")
                ambiguous_override = active_wf.get("adversary_override_ambiguous", False)

                if verdict is None:
                    print(
                        "BLOCKED: Kein Adversary-Lauf für diesen Workflow. "
                        "Phase 6 (Adversary) muss vor dem Commit abgeschlossen sein.",
                        file=sys.stderr
                    )
                    sys.exit(2)
                elif verdict == "BROKEN":
                    print(
                        "BLOCKED: Adversary-Verdict ist BROKEN. "
                        "Implementation muss korrigiert werden.",
                        file=sys.stderr
                    )
                    sys.exit(2)
                elif verdict == "AMBIGUOUS" and not ambiguous_override:
                    print(
                        "BLOCKED: Adversary-Verdict ist AMBIGUOUS. "
                        "Entweder Befunde klären oder 'override-ambiguous' ausführen.",
                        file=sys.stderr
                    )
                    sys.exit(2)

                # 6e. Localize Gate — kein Commit ohne Lokalisierungs-Check
                loc_checked = active_wf.get("localize_checked", False)
                no_strings = active_wf.get("no_user_strings", False)
                if not loc_checked and not no_strings:
                    print("BLOCKED: /13-localize ist PFLICHT vor dem Commit. "
                          "Führe /13-localize aus oder setze no_user_strings: "
                          "workflow.py set-field no_user_strings true",
                          file=sys.stderr)
                    sys.exit(2)

    # 7. Allow
    sys.exit(0)


if __name__ == "__main__":
    main()
