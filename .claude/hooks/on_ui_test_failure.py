#!/usr/bin/env python3
"""
OpenSpec Framework - ON_UI_TEST_FAILURE Hook

PostToolUse hook that enforces Analysis-First when UI tests fail.
BLOCKS immediate code rewrites and demands root cause analysis.

Triggers:
- After xcodebuild test commands for UI tests
- When exit code != 0

Actions:
- Blocks code changes until failure is analyzed
- Demands Accessibility Tree inspection for "Element not found"
- Distinguishes between Simulator issues (Exit 64) and actual test failures

Exit Codes:
- 0: Analysis complete or not a UI test failure
- 2: Blocked - requires analysis before code changes
"""

import json
import os
import sys
import re
from pathlib import Path

# State file to track if analysis was done
STATE_FILE = Path(__file__).parent.parent / "ui_test_failure_state.json"


def load_failure_state():
    """Load the current failure analysis state."""
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except json.JSONDecodeError:
            pass
    return {"last_failure": None, "analysis_done": False, "exit_code": None}


def save_failure_state(state):
    """Save the failure analysis state."""
    STATE_FILE.write_text(json.dumps(state, indent=2))


def clear_failure_state():
    """Clear failure state after successful tests."""
    if STATE_FILE.exists():
        STATE_FILE.unlink()


def extract_failure_info(output: str) -> dict:
    """Extract detailed failure information from test output."""
    info = {
        "element_not_found": [],
        "assertion_failures": [],
        "crashes": [],
        "timeout_errors": [],
    }

    # Element not found patterns
    not_found_patterns = [
        r'No matches found for.*"([^"]+)"',
        r"Failed to find.*identifier.*['\"]([^'\"]+)['\"]",
        r"XCTAssertTrue failed.*waitForExistence.*['\"]([^'\"]+)['\"]",
        r"element.*not.*exist.*['\"]([^'\"]+)['\"]",
    ]
    for pattern in not_found_patterns:
        matches = re.findall(pattern, output, re.IGNORECASE)
        info["element_not_found"].extend(matches)

    # Assertion failures
    assertion_patterns = [
        r"XCTAssert\w+ failed[^)]*\) - (.+?)(?:\n|$)",
        r"XCTFail\(\"([^\"]+)\"\)",
    ]
    for pattern in assertion_patterns:
        matches = re.findall(pattern, output)
        info["assertion_failures"].extend(matches)

    # App crashes
    if "crashed" in output.lower() or "SIGABRT" in output or "SIGSEGV" in output:
        info["crashes"].append("App crashed during test")

    # Timeout
    if "timed out" in output.lower():
        info["timeout_errors"].append("Test timed out")

    return info


def main():
    """Main hook entry point."""
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    tool_output = data.get("tool_output", {})

    # === Handle Bash commands (UI test execution) ===
    if tool_name == "Bash":
        command = tool_input.get("command", "")

        # Check if this was an xcodebuild test command for UI tests
        is_xcodebuild_test = "xcodebuild" in command and "test" in command
        is_ui_test = "UITests" in command or "FocusBloxUITests" in command

        # Also check for DebugHierarchy (analysis tool)
        is_hierarchy_analysis = "DebugHierarchyTest" in command

        if is_hierarchy_analysis:
            # User/Claude is doing analysis - mark as done
            state = load_failure_state()
            if state.get("last_failure"):
                state["analysis_done"] = True
                save_failure_state(state)
                print("[ON_UI_TEST_FAILURE] Accessibility Tree analysiert - Code-Aenderungen erlaubt", file=sys.stderr)
            sys.exit(0)

        if not (is_xcodebuild_test and is_ui_test):
            sys.exit(0)

        # Check exit code and output
        exit_code = tool_output.get("exit_code", 0)
        stdout = tool_output.get("stdout", "") or ""
        stderr = tool_output.get("stderr", "") or ""
        output = stdout + stderr

        # Test succeeded - clear failure state
        if exit_code == 0 and "TEST SUCCEEDED" in output.upper():
            clear_failure_state()
            sys.exit(0)

        # Test failed - record failure and block until analysis
        if exit_code != 0 or "FAILED" in output.upper():
            failure_info = extract_failure_info(output)

            state = {
                "last_failure": {
                    "exit_code": exit_code,
                    "element_not_found": failure_info["element_not_found"],
                    "assertion_failures": failure_info["assertion_failures"],
                    "crashes": failure_info["crashes"],
                    "timeout_errors": failure_info["timeout_errors"],
                    "is_exit_64": exit_code == 64,
                },
                "analysis_done": False,
                "exit_code": exit_code,
            }
            save_failure_state(state)

            # Print diagnostic guidance
            if exit_code == 64:
                print(f"""
+======================================================================+
|  UI TEST FAILURE: EXIT CODE 64 (Simulator/Syntax Problem)            |
+======================================================================+
|                                                                      |
|  Dies ist KEIN Code-Problem! Pruefe zuerst:                          |
|                                                                      |
|  1. Simulator existiert?                                             |
|     xcrun simctl list devices available | grep FocusBlox             |
|                                                                      |
|  2. Simulator haengt?                                                |
|     killall "Simulator" && xcrun simctl shutdown all                 |
|                                                                      |
|  3. UUID in CLAUDE.md aktuell?                                       |
|     Falls Simulator neu erstellt wurde, UUID aktualisieren!          |
|                                                                      |
|  KEINE CODE-AENDERUNGEN bis Simulator-Status geklaert!               |
+======================================================================+
""", file=sys.stderr)
            elif failure_info["element_not_found"]:
                elements = ", ".join(failure_info["element_not_found"][:3])
                print(f"""
+======================================================================+
|  UI TEST FAILURE: Element(e) nicht gefunden                          |
+======================================================================+
|                                                                      |
|  Nicht gefunden: {elements[:50]:<50}|
|                                                                      |
|  ANALYSE ERFORDERLICH bevor Code geaendert wird:                     |
|                                                                      |
|  1. Fuehre /inspect-ui aus, um zu sehen was STATTDESSEN da ist       |
|  2. Pruefe ob Element existiert aber falschen Identifier hat         |
|  3. Pruefe ob Element verdeckt oder nicht hittable ist               |
|  4. Pruefe ob Navigation zum richtigen Screen erfolgt ist            |
|                                                                      |
|  KEINE SPEKULATIVEN CODE-AENDERUNGEN!                                |
|  Erst Accessibility Tree analysieren, dann gezielt fixen.            |
+======================================================================+
""", file=sys.stderr)
            else:
                print(f"""
+======================================================================+
|  UI TEST FAILURE (Exit Code: {exit_code})                                       |
+======================================================================+
|                                                                      |
|  Analyse erforderlich bevor Code geaendert wird.                     |
|                                                                      |
|  Optionen:                                                           |
|  1. /inspect-ui - Accessibility Tree anzeigen                        |
|  2. Test-Output genau lesen                                          |
|  3. Root Cause identifizieren                                        |
|                                                                      |
+======================================================================+
""", file=sys.stderr)

        sys.exit(0)

    # === Handle Edit/Write commands ===
    if tool_name in ["Edit", "Write"]:
        file_path = tool_input.get("file_path", "")

        # Only block production code changes, not test code
        is_production_code = "/Sources/" in file_path
        is_test_code = "Tests" in file_path or "Test" in file_path

        if is_production_code and not is_test_code:
            state = load_failure_state()
            failure = state.get("last_failure")

            if failure and not state.get("analysis_done", False):
                # Exit 64 - absolutely block until simulator fixed
                if failure.get("is_exit_64"):
                    print(f"""
+======================================================================+
|  BLOCKED: Exit Code 64 nicht aufgeloest!                             |
+======================================================================+
|                                                                      |
|  Du versuchst Produktionscode zu aendern, aber der letzte            |
|  UI-Test ist mit Exit Code 64 fehlgeschlagen.                        |
|                                                                      |
|  Exit Code 64 = Simulator/Syntax-Problem, NICHT Code-Problem!        |
|                                                                      |
|  ERFORDERLICH:                                                       |
|  1. Simulator-Status pruefen                                         |
|  2. Tests erneut ausfuehren                                          |
|  3. Erst bei Exit 65 (echter Test-Failure) Code aendern              |
|                                                                      |
+======================================================================+
""", file=sys.stderr)
                    sys.exit(2)

                # Element not found - require accessibility analysis
                if failure.get("element_not_found"):
                    elements = ", ".join(failure["element_not_found"][:2])
                    print(f"""
+======================================================================+
|  BLOCKED: Accessibility-Analyse fehlt!                               |
+======================================================================+
|                                                                      |
|  Element(e) nicht gefunden: {elements[:40]:<40}|
|                                                                      |
|  Bevor du Code aenderst:                                             |
|  1. Fuehre /inspect-ui aus                                           |
|  2. Analysiere was STATTDESSEN auf dem Screen ist                    |
|  3. Identifiziere die echte Ursache                                  |
|                                                                      |
|  Spekulative Aenderungen sind VERBOTEN!                              |
|                                                                      |
+======================================================================+
""", file=sys.stderr)
                    sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
