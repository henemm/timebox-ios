#!/usr/bin/env python3
"""
Adversary Gate — Sets adversary_verdict ONLY with proof of real test execution.

This is the ONLY way to set adversary_verdict on a workflow.
It cannot be set via set-field or direct JSON manipulation (hooks block that).

Requirements for VERIFIED verdict:
1. Test output file must exist and be recent (< 30 min)
2. File must contain real xcodebuild test output patterns
3. Tests must have PASSED (no failures)
4. File must be substantial (> 500 bytes — not fabricated)

Usage:
    python3 .claude/hooks/adversary_gate.py <path-to-test-output-file>
    python3 .claude/hooks/adversary_gate.py --check  # Just check current verdict
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path


def get_state_file() -> Path:
    """Find workflow state file."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        candidate = parent / ".claude" / "workflow_state.json"
        if candidate.exists():
            return candidate
    return cwd / ".claude" / "workflow_state.json"


def load_state() -> dict:
    state_file = get_state_file()
    if not state_file.exists():
        return {}
    with open(state_file, 'r') as f:
        return json.load(f)


def save_state(state: dict):
    state_file = get_state_file()
    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2)


def validate_test_output(filepath: str) -> tuple[bool, str, dict]:
    """
    Validate that a file contains real xcodebuild test output.

    Returns: (is_valid, reason, details)
    """
    path = Path(filepath)

    # 1. File must exist
    if not path.exists():
        return False, f"File not found: {filepath}", {}

    # 2. File must be recent (< 30 minutes)
    mtime = path.stat().st_mtime
    age_minutes = (time.time() - mtime) / 60
    if age_minutes > 30:
        return False, f"Test output is {age_minutes:.0f} min old (max 30 min). Re-run tests.", {}

    # 3. File must be substantial (not fabricated one-liner)
    size = path.stat().st_size
    if size < 500:
        return False, f"Test output too small ({size} bytes). Looks fabricated.", {}

    content = path.read_text(errors='replace')

    # 4. Must contain xcodebuild test patterns
    xcodebuild_patterns = [
        r"Test Suite",
        r"Test Case",
        r"Executed \d+ test",
        r"passed|failed",
    ]
    matches = sum(1 for p in xcodebuild_patterns if re.search(p, content, re.IGNORECASE))
    if matches < 2:
        return False, f"File doesn't look like xcodebuild test output (matched {matches}/4 patterns).", {}

    # 5. Check test results
    # Look for "Executed X tests, with Y failures"
    exec_match = re.search(r"Executed (\d+) tests?, with (\d+) failures?", content)

    # Look for "** TEST SUCCEEDED **" or "** TEST FAILED **"
    succeeded = "TEST SUCCEEDED" in content or "TEST EXECUTE SUCCEEDED" in content or "** BUILD SUCCEEDED **" in content
    test_failed = "TEST FAILED" in content or "TEST EXECUTE FAILED" in content

    # Extract details
    details = {
        "file": filepath,
        "size_bytes": size,
        "age_minutes": round(age_minutes, 1),
        "pattern_matches": matches,
    }

    if exec_match:
        total = int(exec_match.group(1))
        failures = int(exec_match.group(2))
        details["tests_total"] = total
        details["tests_failed"] = failures

        if failures > 0:
            # Extract failure names
            failure_lines = re.findall(r"(?:FAIL|failed).*?[-–]\s*(test\w+)", content, re.IGNORECASE)
            details["failed_tests"] = failure_lines[:10]
            return False, f"Tests FAILED: {failures}/{total} failures", details

        details["tests_passed"] = total
        return True, f"Tests PASSED: {total} tests, 0 failures", details

    if test_failed:
        return False, "Test output contains TEST FAILED marker", details

    if succeeded:
        # Count test cases as backup
        test_cases = re.findall(r"Test Case.*?(passed|failed)", content, re.IGNORECASE)
        passed = sum(1 for t in test_cases if t.lower() == "passed")
        failed = sum(1 for t in test_cases if t.lower() == "failed")
        details["tests_passed"] = passed
        details["tests_failed"] = failed

        if failed > 0:
            return False, f"Tests FAILED: {failed} test cases failed", details
        if passed > 0:
            return True, f"Tests PASSED: {passed} test cases", details
        return True, "TEST SUCCEEDED marker found", details

    return False, "Could not determine test result from output", details


def set_verdict(verdict: str, details: dict):
    """Set adversary_verdict on active workflow."""
    state = load_state()
    active = state.get("active_workflow")
    if not active or active not in state.get("workflows", {}):
        print("ERROR: No active workflow")
        sys.exit(1)

    workflow = state["workflows"][active]
    workflow["adversary_verdict"] = verdict
    workflow["adversary_details"] = details
    workflow["last_updated"] = datetime.now().isoformat()
    save_state(state)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == "--check":
        state = load_state()
        active = state.get("active_workflow")
        if not active or active not in state.get("workflows", {}):
            print("No active workflow")
            sys.exit(1)
        verdict = state["workflows"][active].get("adversary_verdict")
        if verdict:
            print(f"Verdict: {verdict}")
        else:
            print("No adversary verdict set")
        sys.exit(0)

    test_output_file = sys.argv[1]

    print(f"Validating test output: {test_output_file}")
    print()

    is_valid, reason, details = validate_test_output(test_output_file)

    state = load_state()
    active = state.get("active_workflow", "unknown")

    if is_valid:
        verdict = f"VERIFIED:{reason}"
        set_verdict(verdict, details)
        print(f"VERIFIED — {reason}")
        print(f"Workflow: {active}")
        print(f"Commit is now allowed.")
    else:
        verdict = f"FAILED:{reason}"
        set_verdict(verdict, details)
        print(f"FAILED — {reason}")
        print(f"Workflow: {active}")
        print(f"Fix the issues and re-run tests.")
        sys.exit(1)


if __name__ == "__main__":
    main()
