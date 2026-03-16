#!/usr/bin/env python3
"""
Adversary Gate — Sets adversary_verdict ONLY with proof of real test execution + screenshots.

This is the ONLY way to set adversary_verdict on a workflow.
It cannot be set via set-field or direct JSON manipulation (hooks block that).

Requirements for VERIFIED verdict:
1. Test output file must exist and be recent (< 30 min)
2. File must contain real xcodebuild test output patterns
3. Tests must have PASSED (no failures)
4. File must be substantial (> 500 bytes — not fabricated)
5. Screenshot must exist (< 30 min old) — unless --no-visual flag is passed with reason

Usage:
    python3 .claude/hooks/adversary_gate.py <path-to-test-output-file>
    python3 .claude/hooks/adversary_gate.py <path-to-test-output-file> --screenshot <path-to-screenshot>
    python3 .claude/hooks/adversary_gate.py <path-to-test-output-file> --no-visual "reason why no screenshot"
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


def validate_screenshot(filepath: str) -> tuple[bool, str]:
    """
    Validate that a screenshot file exists and is recent.

    Returns: (is_valid, reason)
    """
    path = Path(filepath)

    if not path.exists():
        return False, f"Screenshot not found: {filepath}"

    # Must be recent (< 30 minutes)
    mtime = path.stat().st_mtime
    age_minutes = (time.time() - mtime) / 60
    if age_minutes > 30:
        return False, f"Screenshot is {age_minutes:.0f} min old (max 30 min). Take a new one."

    # Must be a real image (> 10KB — not a placeholder)
    size = path.stat().st_size
    if size < 10000:
        return False, f"Screenshot too small ({size} bytes). Looks like a placeholder, not a real screenshot."

    # Must be an image file
    suffix = path.suffix.lower()
    if suffix not in ('.png', '.jpg', '.jpeg', '.tiff'):
        return False, f"Screenshot must be an image file, got: {suffix}"

    return True, f"Screenshot valid: {filepath} ({size} bytes, {age_minutes:.1f} min old)"


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

    # Parse optional screenshot / --no-visual arguments
    screenshot_path = None
    no_visual_reason = None
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--screenshot" and i + 1 < len(sys.argv):
            screenshot_path = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--no-visual" and i + 1 < len(sys.argv):
            no_visual_reason = sys.argv[i + 1]
            i += 2
        else:
            i += 1

    print(f"Validating test output: {test_output_file}")
    print()

    # 1. Validate test output
    is_valid, reason, details = validate_test_output(test_output_file)

    state = load_state()
    active = state.get("active_workflow", "unknown")

    if not is_valid:
        verdict = f"FAILED:{reason}"
        set_verdict(verdict, details)
        print(f"FAILED — {reason}")
        print(f"Workflow: {active}")
        print(f"Fix the issues and re-run tests.")
        sys.exit(1)

    # 2. Validate screenshot (required unless --no-visual with reason)
    if no_visual_reason:
        details["screenshot"] = f"NO_VISUAL: {no_visual_reason}"
        print(f"Screenshot skipped: {no_visual_reason}")
    elif screenshot_path:
        ss_valid, ss_reason = validate_screenshot(screenshot_path)
        if not ss_valid:
            verdict = f"FAILED:Screenshot invalid — {ss_reason}"
            details["screenshot_error"] = ss_reason
            set_verdict(verdict, details)
            print(f"FAILED — {ss_reason}")
            print(f"Take a real screenshot and try again.")
            sys.exit(1)
        details["screenshot"] = screenshot_path
        print(f"Screenshot: {ss_reason}")
    else:
        # No screenshot argument at all — try default location
        default_screenshots = [
            Path("/tmp/adversary_screenshot.png"),
            Path("/tmp/adversary_screenshot.jpg"),
        ]
        found = None
        for sp in default_screenshots:
            if sp.exists():
                ss_valid, ss_reason = validate_screenshot(str(sp))
                if ss_valid:
                    found = sp
                    details["screenshot"] = str(sp)
                    print(f"Screenshot (auto-detected): {ss_reason}")
                    break

        if not found:
            verdict = "FAILED:No screenshot provided. Use --screenshot <path> or --no-visual <reason>."
            details["screenshot_error"] = "missing"
            set_verdict(verdict, details)
            print("FAILED — No screenshot found.")
            print()
            print("Options:")
            print("  --screenshot <path>        Provide screenshot path")
            print('  --no-visual "reason"       Skip screenshot with explanation')
            print()
            print("Default locations checked: /tmp/adversary_screenshot.png")
            sys.exit(1)

    # 3. All checks passed
    verdict = f"VERIFIED:{reason}"
    set_verdict(verdict, details)
    print()
    print(f"VERIFIED — {reason}")
    print(f"Workflow: {active}")
    print(f"Commit is now allowed.")


if __name__ == "__main__":
    main()
