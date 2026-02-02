#!/usr/bin/env python3
"""
OpenSpec Framework - UI Test Debugger Hint

PostToolUse hook that recommends using the ui-test-debugger agent
when UI tests fail.

Triggers:
- After xcodebuild test commands
- When exit code != 0
- When testing FocusBloxUITests

Exit Codes:
- 0: Always (this hook only provides hints, never blocks)
"""

import json
import os
import sys
import re


def main():
    """Main hook entry point."""
    # Get tool output from stdin (PostToolUse receives output)
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    tool_output = data.get("tool_output", {})

    # Only check Bash commands
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")

    # Check if this was an xcodebuild test command for UI tests
    is_xcodebuild_test = "xcodebuild" in command and "test" in command
    is_ui_test = "UITests" in command or "FocusBloxUITests" in command

    if not (is_xcodebuild_test and is_ui_test):
        sys.exit(0)

    # Check exit code and output
    exit_code = tool_output.get("exit_code", 0)
    stdout = tool_output.get("stdout", "") or ""
    stderr = tool_output.get("stderr", "") or ""
    output = stdout + stderr

    # Determine if tests failed
    test_failed = False

    # Exit code 65 = test failure
    if exit_code == 65:
        test_failed = True

    # Exit code 64 = usage error (usually simulator/destination problem)
    if exit_code == 64:
        test_failed = True

    # Check output for failure indicators
    if "TEST FAILED" in output.upper() or "FAILED" in output:
        test_failed = True

    if "XCTAssert" in output and "failed" in output.lower():
        test_failed = True

    if not test_failed:
        sys.exit(0)

    # UI Tests failed - recommend the debugger agent
    print("""
+======================================================================+
|  UI TEST FAILURE DETECTED                                            |
+======================================================================+
|                                                                      |
|  Empfehlung: Verwende den ui-test-debugger Agent!                    |
|                                                                      |
|  Dieser Agent ist spezialisiert auf:                                 |
|  - Environment Propagation Probleme                                  |
|  - @AppStorage Timing Issues                                         |
|  - Async Loading Race Conditions                                     |
|  - Mock-Setup Fehler                                                 |
|  - AccessibilityIdentifier Probleme                                  |
|  - xcodebuild Exit Codes (64, 65, 70)                                |
|                                                                      |
|  Der Agent folgt einem systematischen Diagnose-Prozess:              |
|  1. Exit Code prüfen                                                 |
|  2. Test-Output analysieren                                          |
|  3. Environment Chain verifizieren                                   |
|  4. Mock-Setup kontrollieren                                         |
|  5. Root Cause identifizieren                                        |
|  6. Gezielten Fix implementieren                                     |
|                                                                      |
|  Starte den Agent mit:                                               |
|  Task(subagent_type="ui-test-debugger", prompt="...")                |
|                                                                      |
+======================================================================+
""", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
