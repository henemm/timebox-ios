#!/usr/bin/env python3
"""
OpenSpec Framework - Strict Code Gate Hook (v2.0)

BLOCKS ALL code file changes unless:
1. Active workflow exists
2. Workflow is in implementation phase (phase6+)
3. RED test is done (red_test_done=true OR ui_test_red_done=true)

MANUAL OVERRIDE:
Set "user_override": true OR "spec_approved": true in workflow to bypass TDD check.
This allows the user to grant explicit permission for edge cases
(e.g., Control Center Widgets that cannot be tested via XCUITest).

This hook uses WHITELIST approach:
- ALL code files are protected by default
- Only explicitly allowed files can be edited without workflow

Exit Codes:
- 0: Allowed
- 2: Blocked (shown to Claude)
"""

import json
import os
import sys
import re
from pathlib import Path

# Try to import state manager
try:
    from workflow_state_multi import load_state, get_active_workflow, PHASE_NAMES
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import load_state, get_active_workflow, PHASE_NAMES
    except ImportError:
        def load_state():
            return {"version": "2.0", "workflows": {}, "active_workflow": None}
        def get_active_workflow():
            return None
        PHASE_NAMES = {}


# Code file extensions that require workflow
CODE_EXTENSIONS = [
    ".swift",
    ".kt",
    ".java",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".go",
    ".rs",
    ".cpp",
    ".c",
    ".h",
    ".hpp",
]

# Directories ALWAYS allowed (whitelist)
ALWAYS_ALLOWED_DIRS = [
    "Tests/",
    "UITests/",
    "Test/",
    "test/",
    "__tests__/",
    "tests/",
    "docs/",
    ".claude/",
    "scripts/",
    "tools/",
]

# File patterns ALWAYS allowed (whitelist)
ALWAYS_ALLOWED_PATTERNS = [
    r"\.md$",              # Markdown
    r"\.txt$",             # Text files
    r"\.json$",            # Config
    r"\.yaml$",            # Config
    r"\.yml$",             # Config
    r"\.gitignore$",       # Git
    r"README",             # README files
    r"CHANGELOG",          # Changelog
    r"LICENSE",            # License
]


def is_always_allowed(file_path: str) -> bool:
    """Check if file is in whitelist (docs, tests, config)."""
    # Check directories
    for allowed_dir in ALWAYS_ALLOWED_DIRS:
        if allowed_dir in file_path:
            return True

    # Check patterns
    for pattern in ALWAYS_ALLOWED_PATTERNS:
        if re.search(pattern, file_path, re.IGNORECASE):
            return True

    return False


def is_code_file(file_path: str) -> bool:
    """Check if file is a code file that requires workflow."""
    return any(file_path.endswith(ext) for ext in CODE_EXTENSIONS)


def check_user_override(workflow: dict) -> bool:
    """Check if user has granted manual override."""
    if workflow.get("user_override", False):
        return True
    if workflow.get("spec_approved", False):
        return True
    return False


def check_red_test_done(workflow: dict) -> bool:
    """Check if RED test phase is done (unit or UI tests)."""
    if workflow.get("red_test_done", False):
        return True
    if workflow.get("ui_test_red_done", False):
        return True
    # Also check test artifacts
    test_artifacts = workflow.get("test_artifacts", [])
    red_artifacts = [a for a in test_artifacts if a.get("phase") == "phase5_tdd_red"]
    if len(red_artifacts) > 0:
        return True
    return False


def verify_file_in_workflow(workflow: dict, file_path: str) -> tuple[bool, str]:
    """
    Verify that file is part of the workflow.

    Returns (allowed, reason).
    """
    affected_files = workflow.get("affected_files", [])

    # If no affected_files declared, allow (user_override case)
    if len(affected_files) == 0:
        # If user has approved, allow any file
        if check_user_override(workflow):
            return True, "User override - no affected_files check"
        return False, "Workflow has no affected_files declared - update spec first!"

    # Normalize paths for comparison
    # Handle both absolute and relative paths
    normalized_file = file_path.replace("./", "")
    normalized_affected = [f.replace("./", "") for f in affected_files]

    # Check if file is in affected_files (exact match or path ends with)
    for affected in normalized_affected:
        # Exact match
        if normalized_file == affected:
            return True, "File is in workflow's affected_files"
        # Absolute path ends with relative affected_file
        if normalized_file.endswith("/" + affected) or normalized_file.endswith(affected):
            return True, "File is in workflow's affected_files"

    # Check if file matches any pattern in affected_files
    for pattern in normalized_affected:
        if "*" in pattern:
            # Simple glob pattern matching
            regex_pattern = pattern.replace("*", ".*")
            if re.match(regex_pattern, normalized_file):
                return True, f"File matches pattern: {pattern}"
            # Also check if absolute path ends with pattern
            if normalized_file.endswith("/" + pattern.replace("*", "")):
                return True, f"File matches pattern: {pattern}"

    # If user has approved, allow any file (override scope check)
    if check_user_override(workflow):
        return True, "User override - scope check bypassed"

    return False, f"File not in workflow's affected_files: {affected_files}"


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

    # Check if file is in whitelist (docs, tests, config)
    if is_always_allowed(file_path):
        sys.exit(0)

    # Check if file is a code file
    if not is_code_file(file_path):
        sys.exit(0)

    # CODE FILE → Workflow required!
    workflow = get_active_workflow()

    if not workflow:
        print("""
╔══════════════════════════════════════════════════════════════════╗
║  🔴 BLOCKED: No Active Workflow!                                 ║
╠══════════════════════════════════════════════════════════════════╣
║  You're trying to modify a code file without an active workflow. ║
║                                                                  ║
║  File: {:<58}║
║                                                                  ║
║  REQUIRED WORKFLOW:                                              ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ /11-feature  → Start feature planning                       │ ║
║  │ /10-bug      → Start bug analysis                           │ ║
║  │                                                              │ ║
║  │ Feature agent will:                                         │ ║
║  │   - Analyze requirements                                    │ ║
║  │   - Create workflow state                                   │ ║
║  │   - Define test strategy                                    │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  NO SHORTCUTS ALLOWED!                                           ║
║                                                                  ║
║  This hook enforces:                                             ║
║  - Analysis-First principle                                      ║
║  - TDD workflow (RED → GREEN)                                    ║
║  - Proper documentation                                          ║
╚══════════════════════════════════════════════════════════════════╝
""".format(file_path[:58]), file=sys.stderr)
        sys.exit(2)

    # Workflow exists → Check phase
    workflow_name = workflow.get("name", "unknown")
    phase = workflow.get("current_phase", "phase0_idle")
    phase_name = PHASE_NAMES.get(phase, phase)

    # Allow in implementation phases
    ALLOWED_PHASES = [
        "phase6_implement",
        "phase7_validate",
        "phase8_complete",
    ]

    if phase not in ALLOWED_PHASES:
        print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  🔴 BLOCKED: Wrong Phase!                                        ║
╠══════════════════════════════════════════════════════════════════╣
║  Workflow: {workflow_name:<54}║
║  Current Phase: {phase_name:<49}║
║                                                                  ║
║  Implementation requires phase6_implement or later!              ║
║                                                                  ║
║  NEXT STEPS:                                                     ║
║  1. /write-spec  → Create specification (if not done)           ║
║  2. User: "approved" → Get spec approval                         ║
║  3. /tdd-red     → Write FAILING tests                          ║
║  4. /implement   → Make tests GREEN                             ║
║                                                                  ║
║  Current phase does not allow code modification!                 ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
        sys.exit(2)

    # Check if RED test is done (TDD enforcement) OR user override
    if not check_red_test_done(workflow) and not check_user_override(workflow):
        print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  🔴 BLOCKED: TDD RED Phase Not Complete!                         ║
╠══════════════════════════════════════════════════════════════════╣
║  Workflow: {workflow_name:<54}║
║                                                                  ║
║  You must write FAILING tests BEFORE implementation!             ║
║                                                                  ║
║  TDD = Test-Driven Development:                                  ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │  1. RED   → Write tests that FAIL (feature doesn't exist)   │ ║
║  │  2. GREEN → Write code to make tests PASS                   │ ║
║  │  3. REFACTOR → Clean up (optional)                          │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  REQUIRED STEPS:                                                 ║
║  1. Write XCUITests or Unit Tests for this feature               ║
║  2. Run tests → they MUST FAIL                                   ║
║  3. Use /add-artifact to register test failure                   ║
║                                                                  ║
║  Only after capturing RED failure can you implement!             ║
║                                                                  ║
║  MANUAL OVERRIDE: User can say "ich genehmige das" to bypass.    ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
        sys.exit(2)

    # Verify file belongs to workflow (if affected_files declared)
    allowed, reason = verify_file_in_workflow(workflow, file_path)

    if not allowed:
        print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  🔴 BLOCKED: File Not in Workflow!                               ║
╠══════════════════════════════════════════════════════════════════╣
║  Workflow: {workflow_name:<54}║
║  File: {file_path[:58]:<58}║
║                                                                  ║
║  This file is NOT registered in the workflow's affected_files.   ║
║                                                                  ║
║  Reason: {reason[:55]:<55}║
║                                                                  ║
║  This indicates:                                                 ║
║  - You're working on a DIFFERENT feature/bug than the workflow   ║
║  - Scope creep (changing unrelated files)                        ║
║  - Missing file in workflow planning                             ║
║                                                                  ║
║  ACTION REQUIRED:                                                ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ OPTION 1: File belongs to CURRENT workflow                  │ ║
║  │   → Update spec to include this file in affected_files      │ ║
║  │   → Re-run /analyse to update workflow state                │ ║
║  │                                                             │ ║
║  │ OPTION 2: This is a DIFFERENT task (bug/feature)            │ ║
║  │   → First: /reset to clear current workflow                 │ ║
║  │   → Then: /10-bug or /11-feature to start NEW workflow      │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  NO SCOPE CREEP ALLOWED! Each task needs its own workflow.       ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
        # BLOCK - do not allow files outside workflow scope
        sys.exit(2)

    # All checks passed
    sys.exit(0)


if __name__ == "__main__":
    main()
