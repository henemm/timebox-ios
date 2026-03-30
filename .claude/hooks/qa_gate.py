#!/usr/bin/env python3
"""
QA Gate v3 — Validates test output and sets adversary_verdict.

Replaces adversary_gate.py. Works with v3 workflow system
(.claude/workflows/ instead of workflow_state.json).

Usage:
    python3 qa_gate.py <test-output-file> --no-visual "reason"
    python3 qa_gate.py <test-output-file> --screenshot <path>
    python3 qa_gate.py <test-output-file> --infra --no-visual "reason"
    python3 qa_gate.py --check

Exit Codes: 0 = VERIFIED, 1 = FAILED
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


def _set_verdict(verdict: str) -> None:
    """Set adversary_verdict on active workflow via workflow.py CLI."""
    workflow_py = _project_root() / ".claude" / "hooks" / "workflow.py"
    subprocess.run(
        [sys.executable, str(workflow_py), "set-field", "adversary_verdict", verdict],
        capture_output=True, text=True
    )


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

    # Must contain test patterns
    patterns = [r"Test Suite", r"Test Case", r"Executed \d+ test", r"passed|failed"]
    matches = sum(1 for p in patterns if re.search(p, content, re.IGNORECASE))
    if matches < 2:
        return False, f"Doesn't look like test output (matched {matches}/4 patterns)."

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

    if "TEST FAILED" in content:
        return False, "TEST FAILED marker found."

    if "TEST SUCCEEDED" in content:
        return True, "TEST SUCCEEDED"

    return False, "Could not determine test result."


def main():
    args = sys.argv[1:]

    if not args or args[0] == "--check":
        # Just show current verdict
        workflow_py = _project_root() / ".claude" / "hooks" / "workflow.py"
        subprocess.run([sys.executable, str(workflow_py), "status"])
        sys.exit(0)

    filepath = args[0]
    infra = "--infra" in args
    no_visual = "--no-visual" in args
    screenshot = None

    if "--screenshot" in args:
        idx = args.index("--screenshot")
        if idx + 1 < len(args):
            screenshot = args[idx + 1]

    if no_visual:
        idx = args.index("--no-visual")
        reason = args[idx + 1] if idx + 1 < len(args) else "no reason given"
        print(f"Screenshot skipped: {reason}")

    # Get active workflow name for output
    workflow_py = _project_root() / ".claude" / "hooks" / "workflow.py"
    result = subprocess.run(
        [sys.executable, str(workflow_py), "status"],
        capture_output=True, text=True
    )
    wf_name = "unknown"
    for line in result.stdout.splitlines():
        if line.startswith("Workflow:"):
            wf_name = line.split(":", 1)[1].strip()

    print(f"Validating test output: {filepath}")

    valid, message = validate_test_output(filepath, infra=infra)

    if not valid:
        print(f"\nFAILED — {message}")
        print(f"Workflow: {wf_name}")
        print("Fix the issues and re-run tests.")
        sys.exit(1)

    # Validate screenshot if required
    if screenshot and not no_visual:
        ss_path = Path(screenshot)
        if not ss_path.exists():
            print(f"\nFAILED — Screenshot not found: {screenshot}")
            sys.exit(1)
        if ss_path.stat().st_size < 1000:
            print(f"\nFAILED — Screenshot too small ({ss_path.stat().st_size} bytes)")
            sys.exit(1)

    verdict = f"VERIFIED:{message}"
    _set_verdict(verdict)

    print(f"\n{verdict}")
    print(f"Workflow: {wf_name}")
    print("Commit is now allowed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
