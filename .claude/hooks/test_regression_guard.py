#!/usr/bin/env python3
"""
OpenSpec Framework - Test Regression Guard

Prevents silent removal of tests during implementation (GREEN) phase.

Problem solved:
- 6 tests written in TDD RED
- During GREEN, Claude quietly deletes 3 tests
- No hook noticed the scope reduction

This hook:
1. Detects when test files are edited during phase6_implement or later
2. Extracts test method names from the NEW content
3. Compares against the snapshot taken at end of TDD RED phase
4. BLOCKS if any test methods were removed without PO approval

The snapshot is stored in workflow state as:
  "red_test_snapshot": {
    "FocusBloxTests/FooTests.swift": ["testA", "testB", "testC"],
    "FocusBloxUITests/FooUITests.swift": ["testX", "testY"]
  }

Exit Codes:
- 0: Allowed (not a test file, not in GREEN phase, or no tests removed)
- 2: Blocked (test methods removed without override)
"""

import json
import os
import re
import sys
from pathlib import Path

# Import workflow state manager
try:
    from workflow_state_multi import (
        load_state, session_active_name, find_workflow_for_file
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import (
        load_state, session_active_name, find_workflow_for_file
    )

# Import override token check
try:
    from override_token import has_valid_token
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from override_token import has_valid_token
    except ImportError:
        def has_valid_token(_name: str) -> bool:
            return False


# Phases where test removal is blocked (post-RED)
GUARDED_PHASES = [
    "phase6_implement",
    "phase6b_adversary",
    "phase7_validate",
    "phase8_complete",
]

# Test file directories
TEST_DIRS = ["FocusBloxTests", "FocusBloxUITests"]

# Regex to extract Swift test method names
TEST_METHOD_PATTERN = re.compile(
    r'^\s*func\s+(test\w+)\s*\(\s*\)', re.MULTILINE
)


def is_test_file(file_path: str) -> bool:
    """Check if file is a test file in a known test directory."""
    return any(d in file_path for d in TEST_DIRS) and file_path.endswith(".swift")


def extract_test_methods(content: str) -> list[str]:
    """Extract test method names from Swift test file content."""
    return TEST_METHOD_PATTERN.findall(content)


def get_relative_path(file_path: str) -> str:
    """Get relative path suitable for snapshot key matching."""
    for d in TEST_DIRS:
        idx = file_path.find(d)
        if idx >= 0:
            return file_path[idx:]
    return Path(file_path).name


def get_active_workflow_for_file(file_path: str) -> tuple:
    """Get the active workflow relevant to this file."""
    # Try file-based lookup first
    candidates = find_workflow_for_file(file_path)
    if candidates:
        name, wf = candidates[0]
        return name, wf

    # Fallback to session-active workflow
    state = load_state()
    active_name = session_active_name(state)
    if active_name and active_name in state.get("workflows", {}):
        return active_name, state["workflows"][active_name]

    return None, None


def block_removal(rel_path, wf_name, removed_list, snapshot_count, remaining_count):
    """Print block message and exit."""
    print(f"""
+======================================================================+
|  BLOCKED: Test Regression Detected!                                   |
+======================================================================+
|                                                                       |
|  You are REMOVING tests that were written in the TDD RED phase.       |
|  This is a SCOPE CHANGE that requires PO approval.                    |
|                                                                       |
|  File: {rel_path[:60]:<60} |
|  Workflow: {(wf_name or 'unknown')[:56]:<56} |
|                                                                       |
|  Tests being removed:                                                 |""", file=sys.stderr)

    for t in removed_list[:8]:
        print(f"|    - {t[:60]:<60} |", file=sys.stderr)

    print(f"""|                                                                       |
|  RED snapshot: {snapshot_count} tests -> Now: {remaining_count} remaining ({len(removed_list)} removed)       |
|                                                                       |
|  Options:                                                             |
|  1. Keep the tests (adjust implementation instead)                    |
|  2. Ask PO for approval to remove tests (scope change)                |
|  3. If PO approves: request override token                            |
|                                                                       |
|  REASON: Tests define the contract. Removing them changes the scope.  |
+======================================================================+
""", file=sys.stderr)
    sys.exit(2)


def main():
    # Get tool input
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

    # Only guard test files
    if not is_test_file(file_path):
        sys.exit(0)

    # Get workflow
    wf_name, workflow = get_active_workflow_for_file(file_path)
    if not workflow:
        sys.exit(0)

    phase = workflow.get("current_phase", "phase0_idle")

    # Only guard in post-RED phases
    if phase not in GUARDED_PHASES:
        sys.exit(0)

    # Check for override token
    if wf_name and has_valid_token(wf_name):
        sys.exit(0)

    # Get RED test snapshot
    snapshot = workflow.get("red_test_snapshot", {})
    if not snapshot:
        # No snapshot recorded — can't guard
        sys.exit(0)

    # Get the relative path key for this file
    rel_path = get_relative_path(file_path)

    # Find matching snapshot entry (try exact and basename match)
    snapshot_tests = None
    for key, tests in snapshot.items():
        if key == rel_path or Path(key).name == Path(rel_path).name:
            snapshot_tests = tests
            break

    if snapshot_tests is None:
        # This test file wasn't in the RED snapshot — it's new, allow
        sys.exit(0)

    snapshot_set = set(snapshot_tests)

    # --- Write tool: full file content available ---
    new_content = data.get("content", "")
    if new_content:
        new_tests = set(extract_test_methods(new_content))
        removed = snapshot_set - new_tests
        if removed:
            remaining = len(new_tests & snapshot_set)
            block_removal(rel_path, wf_name, sorted(removed),
                          len(snapshot_tests), remaining)
        sys.exit(0)

    # --- Edit tool: old_string / new_string ---
    old_string = data.get("old_string", "")
    new_string = data.get("new_string", "")

    if not old_string:
        sys.exit(0)

    old_tests = set(extract_test_methods(old_string))
    new_tests = set(extract_test_methods(new_string))

    removed_in_edit = old_tests - new_tests
    if not removed_in_edit:
        sys.exit(0)

    # Only block if removed tests were in the RED snapshot
    removed_from_red = removed_in_edit & snapshot_set
    if not removed_from_red:
        sys.exit(0)

    remaining = len(snapshot_set - removed_from_red)
    block_removal(rel_path, wf_name, sorted(removed_from_red),
                  len(snapshot_tests), remaining)


if __name__ == "__main__":
    main()
