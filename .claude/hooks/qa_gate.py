#!/usr/bin/env python3
"""
QA Gate v4 — Validates test output (utility, no longer sets workflow state).

With the 3-Checkpoint system, qa_gate is a pure validation utility.
Claude uses it to prepare Checkpoint 3 presentations, but only Henning
typing 'commit' actually unlocks the commit gate.

Usage:
    python3 qa_gate.py <test-output-file>
    python3 qa_gate.py <test-output-file> --infra
    python3 qa_gate.py <test-output-file> --screenshot <path>
    python3 qa_gate.py --check

Exit Codes: 0 = valid, 1 = invalid
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


def _project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def validate_test_output(filepath: str, infra: bool = False) -> tuple[bool, str]:
    """Validate test output file. Returns (valid, message)."""
    path = Path(filepath)

    if not path.exists():
        return False, f"File not found: {filepath}"

    age_min = (time.time() - path.stat().st_mtime) / 60
    if age_min > 30:
        return False, f"Test output is {age_min:.0f} min old (max 30). Re-run tests."

    size = path.stat().st_size
    if size < 100:
        return False, f"Test output too small ({size} bytes). Looks fabricated."

    content = path.read_text(errors="replace")

    # Must contain test patterns (XCTest or Python unittest)
    xctest_patterns = [r"Test Suite", r"Test Case", r"Executed \d+ test", r"passed|failed"]
    py_patterns = [r"Ran \d+ tests?", r"\bOK\b|FAILED", r"unittest", r"\.\.\."]
    xctest_matches = sum(1 for p in xctest_patterns if re.search(p, content, re.IGNORECASE))
    py_matches = sum(1 for p in py_patterns if re.search(p, content, re.IGNORECASE))
    best_matches = max(xctest_matches, py_matches)
    if best_matches < 2:
        return False, f"Doesn't look like test output (matched {best_matches}/4 patterns)."

    # Check test targets (skip for --infra)
    if not infra:
        has_unit = bool(re.search(r"FocusBlox(?:Mac)?Tests", content))
        has_ui = bool(re.search(r"FocusBlox(?:Mac)?UITests", content))
        if not has_unit and not has_ui:
            return False, "No FocusBloxTests or FocusBloxUITests found."
        if not has_ui:
            return False, "UI Tests missing — only unit tests found."
        if not has_unit:
            return False, "Unit Tests missing — only UI tests found."

    # Check for failures
    exec_matches = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", content)
    if exec_matches:
        total = sum(int(m[0]) for m in exec_matches)
        failures = sum(int(m[1]) for m in exec_matches)
        if failures > 0:
            return False, f"Tests FAILED: {failures}/{total} failures"
        return True, f"Tests PASSED: {total} tests across {len(exec_matches)} runs, 0 failures"

    # Python unittest
    py_exec = re.search(r"Ran (\d+) tests? in", content)
    if py_exec:
        total = int(py_exec.group(1))
        if re.search(r"^FAILED", content, re.MULTILINE):
            py_failures = re.search(r"failures=(\d+)", content)
            fail_count = int(py_failures.group(1)) if py_failures else 1
            return False, f"Python tests FAILED: {fail_count}/{total} failures"
        if re.search(r"^OK", content, re.MULTILINE):
            return True, f"Python tests PASSED: {total} tests, 0 failures"

    if "TEST FAILED" in content:
        return False, "TEST FAILED marker found."

    if "TEST SUCCEEDED" in content:
        return True, "TEST SUCCEEDED"

    return False, "Could not determine test result."


def _hook_mode() -> int:
    """PreToolUse-Hook-Modus: prüft Bash-Commands die mark-red/green aufrufen.

    Liest Bash-Command aus CLAUDE_TOOL_INPUT oder stdin. Wenn der Command
    workflow.py mark-red/mark-ui-red/mark-green/mark-ui-green enthält,
    extrahiert das Test-Output-Argument und validiert es.

    Returns Exit Code (0 = pass, 2 = block).
    """
    if os.environ.get("CLAUDE_ADMIN"):
        return 0

    tool_input_raw = os.environ.get("CLAUDE_TOOL_INPUT", "")
    command = ""
    if tool_input_raw:
        try:
            data = json.loads(tool_input_raw)
            command = data.get("command", "") if isinstance(data, dict) else ""
        except json.JSONDecodeError:
            command = ""
    if not command:
        try:
            data = json.load(sys.stdin)
            if isinstance(data, dict):
                ti = data.get("tool_input", data)
                command = ti.get("command", "") if isinstance(ti, dict) else ""
        except (json.JSONDecodeError, ValueError, OSError):
            return 0  # No input — passthrough

    if not command:
        return 0

    mark_pattern = re.search(
        r"workflow\.py\s+(mark-red|mark-ui-red|mark-green|mark-ui-green)\s+(\S+)",
        command,
    )
    if not mark_pattern:
        return 0  # Not a mark-* command — passthrough

    output_path = mark_pattern.group(2)
    # Strip quotes if any
    output_path = output_path.strip("'\"")

    # Determine infra flag from active workflow
    infra = False
    try:
        wf_dir = _project_root() / ".claude" / "workflows"
        active = wf_dir / ".active"
        if active.exists():
            wf_data = json.loads(active.resolve().read_text() if active.is_symlink()
                                 else active.read_text())
            wf_type = wf_data.get("workflow_type", "")
            if wf_type == "feature" and not wf_data.get("is_new_ui"):
                # Heuristic: infra-features have no UI
                if any(p in str(wf_data.get("affected_files", []))
                       for p in [".claude/", "scripts/", "tests/"]):
                    infra = True
    except (json.JSONDecodeError, OSError):
        pass

    valid, message = validate_test_output(output_path, infra=infra)
    if not valid:
        print(
            f"BLOCKED: qa_gate validation failed for {mark_pattern.group(1)}: {message}\n"
            f"Output file: {output_path}\n"
            f"Run tests again and re-mark with the new output file.",
            file=sys.stderr,
        )
        return 2
    return 0


def main():
    args = sys.argv[1:]

    if args and args[0] == "--hook-mode":
        sys.exit(_hook_mode())

    if not args or args[0] == "--check":
        workflow_py = _project_root() / ".claude" / "hooks" / "workflow.py"
        subprocess.run([sys.executable, str(workflow_py), "status"])
        sys.exit(0)

    filepath = args[0]
    infra = "--infra" in args
    screenshot = None

    if "--screenshot" in args:
        idx = args.index("--screenshot")
        if idx + 1 < len(args):
            screenshot = args[idx + 1]

    print(f"Validating test output: {filepath}")

    valid, message = validate_test_output(filepath, infra=infra)

    if not valid:
        print(f"\nFAILED — {message}")
        print("Fix the issues and re-run tests.")
        sys.exit(1)

    # Validate screenshot if provided
    if screenshot:
        ss_path = Path(screenshot)
        if not ss_path.exists():
            print(f"\nFAILED — Screenshot not found: {screenshot}")
            sys.exit(1)
        if ss_path.stat().st_size < 1000:
            print(f"\nFAILED — Screenshot too small ({ss_path.stat().st_size} bytes)")
            sys.exit(1)

    print(f"\nVALID — {message}")
    print("Present this to Henning for Checkpoint 3 approval ('commit').")
    sys.exit(0)


if __name__ == "__main__":
    main()
