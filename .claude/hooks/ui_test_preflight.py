#!/usr/bin/env python3
"""
UI Test Preflight Gate

Two checks for FocusBloxUITests/*.swift:
1. PREFLIGHT: Blocks if /inspect-ui has not been run in the last 15 minutes
2. ANTI-PATTERNS: Blocks if code contains known bad patterns (sleep, wrong tab access)

Reads state from: .claude/ui_test_preflight_state.json
Exception: DebugHierarchyTest.swift (used by /inspect-ui itself)

Exit Codes:
- 0: Allowed
- 2: Blocked (preflight missing or anti-pattern detected)
"""

import json
import re
import sys
import os
from datetime import datetime, timedelta
from pathlib import Path

# Import multi-workflow state manager for TDD RED phase detection
try:
    from workflow_state_multi import (
        load_state, session_active_name
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import (
        load_state, session_active_name
    )


PREFLIGHT_MAX_AGE_MINUTES = 15
STATE_FILE_NAME = "ui_test_preflight_state.json"
UI_TEST_DIR = "FocusBloxUITests"
EXCEPTION_FILES = {"DebugHierarchyTest.swift", "DebugBacklogHierarchyTest.swift"}

# Anti-patterns: (regex, human-readable message, fix suggestion)
ANTI_PATTERNS = [
    (
        r'\bsleep\s*\(',
        'sleep() ist verboten in UI Tests',
        'Nutze stattdessen: element.waitForExistence(timeout: N)',
    ),
    (
        r'app\.buttons\["tab[_-]',
        'Tab-Zugriff ueber app.buttons ist falsch',
        'Nutze stattdessen: app.tabBars.buttons["TabLabel"]',
    ),
]


def is_tdd_red_phase() -> bool:
    """Check if the active workflow is in TDD RED phase.
    During TDD RED, views don't exist yet, so /inspect-ui cannot be run."""
    try:
        state = load_state()
        active_name = session_active_name(state)
        if not active_name:
            return False
        workflows = state.get("workflows", {})
        workflow = workflows.get(active_name, {})
        return workflow.get("current_phase") == "phase5_tdd_red"
    except Exception:
        return False


def get_project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def get_state_file() -> Path:
    return get_project_root() / ".claude" / STATE_FILE_NAME


def is_ui_test_file(file_path: str) -> bool:
    """Check if file is inside FocusBloxUITests/."""
    return UI_TEST_DIR in file_path and file_path.endswith(".swift")


def is_exception_file(file_path: str) -> bool:
    """Check if file is an exception (DebugHierarchyTest etc.)."""
    basename = Path(file_path).name
    return basename in EXCEPTION_FILES


def preflight_is_recent() -> bool:
    """Check if /inspect-ui was run within the last 15 minutes."""
    state_file = get_state_file()
    if not state_file.exists():
        return False

    try:
        with open(state_file, "r") as f:
            state = json.load(f)

        last_run = datetime.fromisoformat(state.get("last_run", ""))
        age = datetime.now() - last_run
        return age < timedelta(minutes=PREFLIGHT_MAX_AGE_MINUTES)
    except (json.JSONDecodeError, ValueError, KeyError):
        return False


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
        file_path = data.get("file_path", "")
    except json.JSONDecodeError:
        file_path = ""

    if not file_path:
        sys.exit(0)

    # Only gate UI test files
    if not is_ui_test_file(file_path):
        sys.exit(0)

    # Allow exception files (DebugHierarchyTest etc.)
    if is_exception_file(file_path):
        sys.exit(0)

    # Skip preflight in TDD RED phase — views don't exist yet, nothing to inspect
    if is_tdd_red_phase():
        # Still check anti-patterns below, but skip /inspect-ui requirement
        pass
    elif not preflight_is_recent():
        basename = Path(file_path).name
        print(f"""
BLOCKED: UI Test Preflight erforderlich!

Du versuchst {basename} zu editieren, aber /inspect-ui wurde nicht
in den letzten {PREFLIGHT_MAX_AGE_MINUTES} Minuten ausgefuehrt.

PFLICHT vor jedem UI Test Edit:
1. /inspect-ui ausfuehren (Accessibility Tree lesen)
2. Identifier verifizieren
3. Dann erst Test schreiben/aendern

Fuehre zuerst /inspect-ui aus!
""", file=sys.stderr)
        sys.exit(2)

    # Check content for anti-patterns
    content = data.get("new_string", "") or data.get("content", "")
    if content:
        violations = []
        for pattern, message, fix in ANTI_PATTERNS:
            if re.search(pattern, content):
                violations.append(f"  - {message}\n    Fix: {fix}")

        if violations:
            print(
                "\nBLOCKED: Anti-Pattern in UI Test erkannt!\n\n"
                + "\n".join(violations)
                + "\n\nBitte Code korrigieren und erneut versuchen.\n",
                file=sys.stderr,
            )
            sys.exit(2)


if __name__ == "__main__":
    main()
