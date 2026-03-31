#!/usr/bin/env python3
"""
Workflow v4 — Session-Aware State Manager

Each workflow gets its own JSON file in .claude/workflows/.
Active workflow tracked per-session via .sessions.json mapping.
Fallback to .active symlink for backward compatibility.

Session identification:
  - $CLAUDE_SESSION_ID env var (set by session_start.py hook via CLAUDE_ENV_FILE)
  - Hooks receive session_id in stdin JSON

Usage:
    python3 workflow.py start <name>
    python3 workflow.py switch <name>
    python3 workflow.py status
    python3 workflow.py phase <phase>
    python3 workflow.py set-field <key> <value>
    python3 workflow.py set-affected-files [--replace] <f1> <f2> ...
    python3 workflow.py add-artifact <type> <path> <desc> <phase>
    python3 workflow.py mark-red <result>
    python3 workflow.py mark-ui-red <result>
    python3 workflow.py complete
    python3 workflow.py list
    python3 workflow.py snapshot-tests
"""

import fcntl
import json
import os
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path

PHASES = [
    "phase0_idle",
    "phase1_context",
    "phase2_analyse",
    "phase3_spec",
    "phase4_approved",
    "phase5_tdd_red",
    "phase6_implement",
    "phase6b_adversary",
    "phase7_validate",
    "phase8_complete",
]

PHASE_NAMES = {
    "phase0_idle": "Idle",
    "phase1_context": "Context Generation",
    "phase2_analyse": "Analysis",
    "phase3_spec": "Specification Writing",
    "phase4_approved": "Spec Approved",
    "phase5_tdd_red": "TDD RED - Write Failing Tests",
    "phase6_implement": "Implementation (TDD GREEN)",
    "phase6b_adversary": "Adversary Verification",
    "phase7_validate": "Validation",
    "phase8_complete": "Complete",
}


def _project_root() -> Path:
    """Find project root (dir with .git), or use CLAUDE_PROJECT_DIR env."""
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _workflows_dir() -> Path:
    return _project_root() / ".claude" / "workflows"


def _active_link() -> Path:
    return _workflows_dir() / ".active"


def _workflow_file(name: str) -> Path:
    return _workflows_dir() / f"{name}.json"


def _archive_dir() -> Path:
    return _workflows_dir() / "_archive"


def _atomic_write(path: Path, data: dict) -> None:
    """Write JSON atomically via tempfile + rename."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.rename(tmp, str(path))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read_workflow(path: Path) -> dict:
    """Read workflow JSON file."""
    return json.loads(path.read_text())


def _sessions_file() -> Path:
    return _workflows_dir() / ".sessions.json"


def _get_session_id() -> str:
    """Get current session ID from environment."""
    return os.environ.get("CLAUDE_SESSION_ID", "")


def _read_sessions() -> dict:
    """Read session -> workflow mapping (unlocked, for read-only use)."""
    sf = _sessions_file()
    if sf.exists():
        try:
            return json.loads(sf.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {}


@contextmanager
def _locked_sessions(timeout: float = 5.0):
    """Context manager for atomic Read-Modify-Write on .sessions.json.

    Usage:
        with _locked_sessions() as sessions:
            sessions["my_id"] = "my_workflow"
            # File is written and lock released on exit

    Yields a mutable dict. Changes are written back atomically on __exit__.
    """
    sf = _sessions_file()
    sf.parent.mkdir(parents=True, exist_ok=True)
    # Create file if missing so we can flock it
    if not sf.exists():
        sf.write_text("{}")
    lock_fd = os.open(str(sf), os.O_RDWR)
    try:
        # Blocking lock with timeout via alarm (POSIX)
        import signal

        def _timeout_handler(signum, frame):
            raise TimeoutError(f"Could not acquire lock on {sf} within {timeout}s")

        old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
        signal.setitimer(signal.ITIMER_REAL, timeout)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, old_handler)

        # Read current state
        try:
            content = sf.read_text()
            sessions = json.loads(content) if content.strip() else {}
        except (json.JSONDecodeError, OSError):
            sessions = {}

        yield sessions

        # Write back atomically
        _atomic_write(sf, sessions)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def _read_active() -> tuple[dict, str]:
    """Read the active workflow for the current session. Returns (data, name).

    Priority:
    1. Session mapping (.sessions.json) if CLAUDE_SESSION_ID is set
    2. Fallback to .active symlink
    """
    session_id = _get_session_id()
    if session_id:
        sessions = _read_sessions()
        wf_name = sessions.get(session_id)
        if wf_name:
            wf_file = _workflow_file(wf_name)
            if wf_file.exists():
                data = _read_workflow(wf_file)
                return data, data.get("name", wf_name)

    # Fallback: .active symlink
    link = _active_link()
    if not link.exists():
        print("No active workflow.", file=sys.stderr)
        sys.exit(1)
    target = Path(os.readlink(str(link)))
    if not target.is_absolute():
        target = link.parent / target
    if not target.exists():
        print(f"Active workflow file missing: {target}", file=sys.stderr)
        sys.exit(1)
    data = _read_workflow(target)
    return data, data.get("name", target.stem)


def _set_active(name: str) -> None:
    """Set active workflow for current session.

    Updates .sessions.json if CLAUDE_SESSION_ID is set.
    Always updates .active symlink for backward compatibility.
    """
    # Update session mapping (locked to prevent lost updates)
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions[session_id] = name

    # Update .active symlink (backward compat)
    link = _active_link()
    target = f"{name}.json"
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.is_symlink() or link.exists():
        link.unlink()
    os.symlink(target, str(link))


def _save_active(data: dict) -> None:
    """Save the active workflow back to its file."""
    name = data["name"]
    data["last_updated"] = datetime.now().isoformat()
    _atomic_write(_workflow_file(name), data)


def _new_workflow(name: str) -> dict:
    """Create a new workflow data structure."""
    return {
        "name": name,
        "current_phase": "phase1_context",
        "created": datetime.now().isoformat(),
        "last_updated": datetime.now().isoformat(),
        "spec_file": None,
        "spec_approved": False,
        "context_file": None,
        "affected_files": [],
        "test_artifacts": [],
        "is_new_ui": False,
        "red_test_done": False,
        "ui_test_red_done": False,
        "green_approved": False,
        "adversary_verdict": None,
    }


# --- Phase Transition Validation ---

def _validate_transition(data: dict, target: str) -> str | None:
    """Validate phase transition prerequisites. Returns error message or None."""
    current = data.get("current_phase", "phase0_idle")
    cur_idx = PHASES.index(current) if current in PHASES else 0
    tgt_idx = PHASES.index(target) if target in PHASES else -1

    if tgt_idx < 0:
        return f"Unknown phase: {target}"

    # Allow backward transitions (reset) and same-phase
    if tgt_idx <= cur_idx:
        return None

    # Forward transitions: validate prerequisites for each step
    if tgt_idx >= PHASES.index("phase2_analyse"):
        if not data.get("context_file"):
            return "context_file not set — run /01-context first"

    if tgt_idx >= PHASES.index("phase3_spec"):
        if not data.get("analysis_findings"):
            # Allow if context_file exists (analysis may be inline)
            pass

    if tgt_idx >= PHASES.index("phase4_approved"):
        if not data.get("spec_file"):
            return "spec_file not set — run /03-write-spec first"
        if not data.get("spec_approved"):
            return "Spec not approved — user must say 'approved'"

    if tgt_idx >= PHASES.index("phase6_implement"):
        # Need RED test artifacts
        red_artifacts = [a for a in data.get("test_artifacts", [])
                        if a.get("phase") == "phase5_tdd_red"]
        if not red_artifacts:
            return "No RED test artifacts — run /04-tdd-red first"

    if tgt_idx >= PHASES.index("phase7_validate"):
        # Need GREEN test artifacts
        green_artifacts = [a for a in data.get("test_artifacts", [])
                          if a.get("phase") == "phase6_implement"]
        if not green_artifacts and not data.get("green_approved"):
            pass  # Allow — validation might be the step that creates them

    if tgt_idx >= PHASES.index("phase8_complete"):
        verdict = data.get("adversary_verdict", "")
        if not verdict or not str(verdict).startswith("VERIFIED"):
            return "Adversary verdict missing or not VERIFIED"

    return None


# --- Commands ---

def cmd_start(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py start <name>", file=sys.stderr)
        sys.exit(1)
    name = args[0]
    wf_file = _workflow_file(name)
    if wf_file.exists():
        print(f"Workflow {name} already exists. Use 'switch' to activate.", file=sys.stderr)
        sys.exit(1)
    data = _new_workflow(name)
    _atomic_write(wf_file, data)
    _set_active(name)
    print(f"Started workflow: {name}")


def cmd_switch(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py switch <name>", file=sys.stderr)
        sys.exit(1)
    name = args[0]
    wf_file = _workflow_file(name)
    if not wf_file.exists():
        print(f"Workflow {name} not found.", file=sys.stderr)
        sys.exit(1)
    _set_active(name)
    print(f"Switched to workflow: {name}")


def cmd_status(args: list[str]) -> None:
    data, name = _read_active()
    phase = data.get("current_phase", "phase0_idle")
    phase_name = PHASE_NAMES.get(phase, phase)
    spec = data.get("spec_file") or "Not created"
    approved = "Yes" if data.get("spec_approved") else "No"
    green_ok = "Yes" if data.get("green_approved") else "No"
    artifacts = len(data.get("test_artifacts", []))
    print(f"Workflow: {name}")
    print(f"Phase: {phase_name}")
    print(f"Spec: {spec}")
    print(f"Approved: {approved}")
    print(f"GREEN Approved: {green_ok}")
    print(f"Test Artifacts: {artifacts}")


def cmd_phase(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py phase <phase>", file=sys.stderr)
        sys.exit(1)
    target = args[0]
    data, name = _read_active()
    error = _validate_transition(data, target)
    if error:
        print(f"BLOCKED: {error}", file=sys.stderr)
        sys.exit(1)
    data["current_phase"] = target
    _save_active(data)
    print(f"Set phase to: {target}")


def cmd_set_field(args: list[str]) -> None:
    if len(args) < 2:
        print("Usage: workflow.py set-field <key> <value>", file=sys.stderr)
        sys.exit(1)
    key, value = args[0], " ".join(args[1:])
    # Parse booleans
    if value.lower() in ("true", "yes"):
        value = True
    elif value.lower() in ("false", "no"):
        value = False
    else:
        # Try parsing as JSON (for lists, dicts, numbers)
        import json as _json
        try:
            parsed = _json.loads(value)
            if isinstance(parsed, (list, dict, int, float)):
                value = parsed
        except (ValueError, TypeError):
            pass
    data, name = _read_active()
    data[key] = value
    _save_active(data)
    print(f"Set {key} = {value} on workflow {name}")


def cmd_set_affected_files(args: list[str]) -> None:
    replace = "--replace" in args
    files = [a for a in args if a != "--replace"]
    data, name = _read_active()
    if replace:
        data["affected_files"] = files
    else:
        existing = set(data.get("affected_files", []))
        existing.update(files)
        data["affected_files"] = sorted(existing)
    _save_active(data)
    print(f"Set affected_files on workflow {name}: {len(data['affected_files'])} files")


def cmd_add_artifact(args: list[str]) -> None:
    if len(args) < 4:
        print("Usage: workflow.py add-artifact <type> <path> <desc> <phase>", file=sys.stderr)
        sys.exit(1)
    art_type, art_path, desc, phase = args[0], args[1], args[2], args[3]
    data, _ = _read_active()
    data.setdefault("test_artifacts", []).append({
        "type": art_type,
        "path": art_path,
        "description": desc,
        "phase": phase,
        "created": datetime.now().isoformat(),
    })
    _save_active(data)
    name = data["name"]
    print(f"Artifact added to {name}: {art_type} ({desc})")


def cmd_mark_red(args: list[str]) -> None:
    result = " ".join(args) if args else "failed"
    data, name = _read_active()
    data["red_test_done"] = True
    data["red_test_result"] = result
    _save_active(data)
    print(f"RED unit test marked done: {result}")


def cmd_mark_ui_red(args: list[str]) -> None:
    result = " ".join(args) if args else "failed"
    data, name = _read_active()
    data["ui_test_red_done"] = True
    data["ui_test_red_result"] = result
    _save_active(data)
    print(f"RED UI test marked done: {result}")


def cmd_complete(args: list[str]) -> None:
    data, name = _read_active()
    data["current_phase"] = "phase8_complete"
    archive = _archive_dir()
    archive.mkdir(parents=True, exist_ok=True)
    _atomic_write(archive / f"{name}.json", data)
    # Remove from active workflows
    wf_file = _workflow_file(name)
    if wf_file.exists():
        wf_file.unlink()
    # Remove own session from mapping (locked to prevent lost updates)
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions.pop(session_id, None)
    # Remove .active symlink only if it points to this workflow
    link = _active_link()
    if link.is_symlink():
        target = os.readlink(str(link))
        if Path(target).stem == name:
            link.unlink()
    print(f"Workflow {name} completed and archived.")


def cmd_list(args: list[str]) -> None:
    wf_dir = _workflows_dir()
    if not wf_dir.exists():
        print("No workflows.")
        return
    # Get session-based active workflow
    session_id = _get_session_id()
    sessions = _read_sessions()
    my_active = sessions.get(session_id) if session_id else None
    # Fallback to .active symlink
    if not my_active:
        link = _active_link()
        if link.is_symlink():
            target = os.readlink(str(link))
            my_active = Path(target).stem
    # Build reverse map: workflow -> list of short session IDs
    wf_sessions = {}
    for sid, wname in sessions.items():
        wf_sessions.setdefault(wname, []).append(sid[:8])
    for f in sorted(wf_dir.glob("*.json")):
        if f.name == ".sessions.json":
            continue
        data = _read_workflow(f)
        name = data.get("name", f.stem)
        phase = data.get("current_phase", "?")
        marker = " *" if name == my_active else ""
        session_info = f" [{', '.join(wf_sessions[name])}]" if name in wf_sessions else ""
        print(f"  {name}: {PHASE_NAMES.get(phase, phase)}{marker}{session_info}")


def cmd_snapshot_tests(args: list[str]) -> None:
    """Snapshot all test methods for regression guard."""
    import glob
    import re
    root = _project_root()
    test_dirs = [root / "FocusBloxTests", root / "FocusBloxUITests",
                 root / "FocusBloxMacTests", root / "FocusBloxMacUITests"]
    total_tests = 0
    total_files = 0
    for test_dir in test_dirs:
        if not test_dir.exists():
            continue
        for swift_file in sorted(test_dir.glob("**/*.swift")):
            content = swift_file.read_text()
            test_methods = re.findall(r'func\s+(test\w+)\s*\(', content)
            if test_methods:
                total_files += 1
                total_tests += len(test_methods)
                rel = swift_file.relative_to(root)
                print(f"  {rel}: {len(test_methods)} tests")
    print(f"Snapshot saved: {total_tests} tests in {total_files} files")


COMMANDS = {
    "start": cmd_start,
    "switch": cmd_switch,
    "status": cmd_status,
    "phase": cmd_phase,
    "set-field": cmd_set_field,
    "set-affected-files": cmd_set_affected_files,
    "add-artifact": cmd_add_artifact,
    "mark-red": cmd_mark_red,
    "mark-ui-red": cmd_mark_ui_red,
    "complete": cmd_complete,
    "list": cmd_list,
    "snapshot-tests": cmd_snapshot_tests,
}


def main():
    if len(sys.argv) < 2:
        print("Usage: workflow.py <command> [args...]", file=sys.stderr)
        print(f"Commands: {', '.join(COMMANDS.keys())}", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

    COMMANDS[cmd](sys.argv[2:])


if __name__ == "__main__":
    main()
