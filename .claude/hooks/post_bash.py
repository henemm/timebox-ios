#!/usr/bin/env python3
"""
Post-Bash v4 — PostToolUse Hook for Bash

1. Releases build lock after xcodebuild commands complete.
2. Analyzes test output from sim.sh test/unit commands.
3. Auto-registers test artifacts in workflow state.
4. Warns on phase-inconsistent test results (RED should fail, GREEN should pass).

Exit Codes: 0 always (PostToolUse hooks observe, never block)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Session ID extracted from stdin JSON (set during main())
_STDIN_SESSION_ID = ""


def _project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _read_active_workflow() -> dict | None:
    """Read the active workflow for the current session."""
    wf_dir = _project_root() / ".claude" / "workflows"
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
                        return json.loads(wf_path.read_text())
            except (OSError, json.JSONDecodeError):
                pass
    # Fallback: .active symlink
    link = wf_dir / ".active"
    if not link.exists():
        return None
    try:
        target = Path(os.readlink(str(link)))
        if not target.is_absolute():
            target = link.parent / target
        if target.exists():
            return json.loads(target.read_text())
    except (OSError, json.JSONDecodeError):
        pass
    return None


def _analyze_test_output(command: str, output: str) -> None:
    """Analyze test output, register artifacts, warn on phase-inconsistent results."""
    exec_matches = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", output)
    if not exec_matches:
        return

    total = sum(int(m[0]) for m in exec_matches)
    failures = sum(int(m[1]) for m in exec_matches)
    passed = failures == 0
    result_str = (f"PASSED: {total} tests, 0 failures" if passed
                  else f"FAILED: {failures}/{total} failures")

    # Read active workflow
    workflow = _read_active_workflow()
    if not workflow:
        return
    phase = workflow.get("current_phase", "phase0_idle")

    # Register artifact via workflow.py CLI
    test_type = "ui_test" if "sim.sh test" in command else "unit_test"
    workflow_py = _project_root() / ".claude" / "hooks" / "workflow.py"
    try:
        subprocess.run(
            [sys.executable, str(workflow_py), "add-artifact",
             "test_output", test_type, result_str, phase],
            capture_output=True, text=True, timeout=5
        )
    except (subprocess.TimeoutExpired, OSError):
        pass

    # Phase-specific warnings (stderr only, no blocking)
    if phase == "phase4_tdd_red" and passed:
        print(f"WARNING: Tests PASSED in TDD RED phase! "
              f"Tests sollen in phase5 FEHLSCHLAGEN (RED). "
              f"Ergebnis: {result_str}", file=sys.stderr)

    elif phase == "phase5_implement" and not passed:
        print(f"WARNING: Tests FAILED in Implementation phase! "
              f"Ergebnis: {result_str}. "
              f"Tests muessen GRUEN sein bevor weitergearbeitet wird.", file=sys.stderr)

    elif phase == "phase6_adversary" and not passed:
        print(f"WARNING: Tests FAILED in Adversary phase! "
              f"Ergebnis: {result_str}. "
              f"Adversary hat moeglicherweise ein Problem gefunden.", file=sys.stderr)


def main():
    global _STDIN_SESSION_ID
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    tool_response = ""

    if not tool_input:
        try:
            raw_input = json.load(sys.stdin)
            tool_input = json.dumps(raw_input.get("tool_input", {}))
            _STDIN_SESSION_ID = raw_input.get("session_id", "")
            resp = raw_input.get("tool_response", "")
            tool_response = resp if isinstance(resp, str) else json.dumps(resp)
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        sys.exit(0)

    command = data.get("command", "")
    if not command:
        sys.exit(0)

    # 1. Release build lock after xcodebuild
    if "xcodebuild" in command:
        lock_path = _project_root() / ".claude" / "build_lock.json"
        if lock_path.exists():
            try:
                lock = json.loads(lock_path.read_text())
                session_id = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
                my_id = f"session:{session_id}" if session_id else f"ppid:{os.getppid()}"
                holder_id = lock.get("holder_id", "")
                if not holder_id and "ppid" in lock:
                    holder_id = f"ppid:{lock['ppid']}"
                if holder_id == my_id:
                    lock_path.unlink()
            except (json.JSONDecodeError, OSError):
                pass

    # 2. Analyze test output from sim.sh test/unit
    is_test_cmd = ("sim.sh test" in command or "sim.sh unit" in command)
    if is_test_cmd and tool_response:
        _analyze_test_output(command, tool_response)

    sys.exit(0)


if __name__ == "__main__":
    main()
