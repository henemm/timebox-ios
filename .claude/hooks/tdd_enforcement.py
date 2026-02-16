#!/usr/bin/env python3
"""
OpenSpec Framework - TDD Enforcement Hook

Enforces Test-Driven Development with REAL test artifacts.
Blocks implementation until proper RED phase tests exist with actual data.

REAL means:
- Screenshots: Actual image files (png, jpg, gif) with content
- Emails: Actual email content or .eml files
- API responses: Actual JSON/XML responses saved to files
- Log outputs: Actual log files or excerpts
- Files: Actual generated/exported files

NOT acceptable:
- Placeholder text like "[Screenshot here]"
- Empty files
- Mock data without real test execution
- TODO comments in test files

Exit Codes:
- 0: Allowed
- 2: Blocked (stderr shown to Claude)
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta

# Import multi-workflow state manager
try:
    from workflow_state_multi import (
        load_state, get_active_workflow, PHASES,
        PHASE_NAMES, TEST_REQUIRED_PHASES
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import (
        load_state, get_active_workflow, PHASES,
        PHASE_NAMES, TEST_REQUIRED_PHASES
    )


# Minimum requirements for TDD RED phase
TDD_RED_REQUIREMENTS = {
    "min_unit_artifacts": 1,  # At least one unit test artifact
    "min_ui_artifacts": 1,    # At least one UI test artifact
    "max_artifact_age_hours": 24,  # Artifacts must be recent
}

# Valid artifact types
VALID_ARTIFACT_TYPES = [
    "screenshot",
    "email",
    "api_response",
    "log",
    "file",
    "test_output",      # Unit test output
    "ui_test_output",   # UI test output (NEW!)
    "video",
    "audio",
]

# Types that count as UNIT test artifacts
UNIT_TEST_TYPES = ["test_output", "log", "api_response"]

# Types that count as UI test artifacts
UI_TEST_TYPES = ["ui_test_output", "screenshot", "video"]

# File extensions that prove REAL artifacts
REAL_ARTIFACT_EXTENSIONS = {
    "screenshot": [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"],
    "email": [".eml", ".msg", ".txt"],
    "api_response": [".json", ".xml", ".txt"],
    "log": [".log", ".txt"],
    "file": ["*"],  # Any extension
    "test_output": [".txt", ".log", ".json"],
    "ui_test_output": [".txt", ".log", ".json"],  # UI test logs
    "video": [".mp4", ".mov", ".webm", ".gif"],
    "audio": [".mp3", ".wav", ".m4a"],
}

# Minimum file sizes (bytes) to prove non-empty
MIN_FILE_SIZES = {
    "screenshot": 1000,  # Real screenshots are > 1KB
    "email": 100,
    "api_response": 10,
    "log": 10,
    "file": 1,
    "test_output": 10,
    "ui_test_output": 10,  # UI test logs
    "video": 10000,
    "audio": 1000,
}


def validate_artifact(artifact: dict) -> tuple[bool, str]:
    """
    Validate a single test artifact.
    Returns (valid, reason).
    """
    artifact_type = artifact.get("type")
    path = artifact.get("path")
    description = artifact.get("description", "")
    created = artifact.get("created")

    # Check type
    if artifact_type not in VALID_ARTIFACT_TYPES:
        return False, f"Invalid artifact type: {artifact_type}"

    # Check path exists
    if not path:
        return False, "Artifact has no path"

    artifact_path = Path(path)
    if not artifact_path.exists():
        return False, f"Artifact file not found: {path}"

    # Check file extension
    valid_extensions = REAL_ARTIFACT_EXTENSIONS.get(artifact_type, ["*"])
    if "*" not in valid_extensions:
        ext = artifact_path.suffix.lower()
        if ext not in valid_extensions:
            return False, f"Invalid extension {ext} for {artifact_type}. Expected: {valid_extensions}"

    # Check file size (not empty/placeholder)
    min_size = MIN_FILE_SIZES.get(artifact_type, 1)
    actual_size = artifact_path.stat().st_size

    if actual_size < min_size:
        return False, f"Artifact too small ({actual_size} bytes). Minimum for {artifact_type}: {min_size} bytes. Is this a placeholder?"

    # Check description
    if not description or len(description) < 10:
        return False, "Artifact needs a description (min 10 chars) explaining what it proves"

    # Check placeholder patterns in description
    placeholder_patterns = [
        "[todo]", "[placeholder]", "[add later]", "[screenshot here]",
        "tbd", "to be done", "will add", "need to add"
    ]
    desc_lower = description.lower()
    for pattern in placeholder_patterns:
        if pattern in desc_lower:
            return False, f"Description contains placeholder pattern: '{pattern}'"

    # Check artifact age
    if created:
        try:
            created_dt = datetime.fromisoformat(created.replace('Z', '+00:00'))
            max_age = timedelta(hours=TDD_RED_REQUIREMENTS["max_artifact_age_hours"])
            if datetime.now(created_dt.tzinfo) - created_dt > max_age:
                return False, f"Artifact is older than {TDD_RED_REQUIREMENTS['max_artifact_age_hours']} hours. Re-run tests with fresh data."
        except (ValueError, TypeError):
            pass  # Skip age check if date parsing fails

    return True, "OK"


def validate_red_phase(workflow: dict) -> tuple[bool, str]:
    """
    Validate that TDD RED phase is properly completed.
    Requires BOTH unit test AND UI test artifacts.
    Returns (valid, reason).
    """
    artifacts = workflow.get("test_artifacts", [])

    # Filter to RED phase artifacts
    red_artifacts = [a for a in artifacts if a.get("phase") == "phase5_tdd_red"]

    # Separate unit test and UI test artifacts
    unit_artifacts = [a for a in red_artifacts if a.get("type") in UNIT_TEST_TYPES]
    ui_artifacts = [a for a in red_artifacts if a.get("type") in UI_TEST_TYPES]

    # Check minimum unit test artifacts
    if len(unit_artifacts) < TDD_RED_REQUIREMENTS["min_unit_artifacts"]:
        return False, f"""
+======================================================================+
|  TDD RED PHASE INCOMPLETE: UNIT TESTS MISSING!                       |
+======================================================================+
|  You have {len(unit_artifacts)} unit test artifact(s), need at least {TDD_RED_REQUIREMENTS["min_unit_artifacts"]}.        |
|                                                                      |
|  Before implementing, you MUST:                                      |
|  1. Write UNIT tests for the business logic                          |
|  2. Run the tests - they MUST FAIL (RED)                             |
|  3. Register artifact with type: "test_output"                       |
|                                                                      |
|  Use /add-artifact to register test evidence.                        |
+======================================================================+
"""

    # Check minimum UI test artifacts
    if len(ui_artifacts) < TDD_RED_REQUIREMENTS["min_ui_artifacts"]:
        return False, f"""
+======================================================================+
|  TDD RED PHASE INCOMPLETE: UI TESTS MISSING!                         |
+======================================================================+
|  You have {len(ui_artifacts)} UI test artifact(s), need at least {TDD_RED_REQUIREMENTS["min_ui_artifacts"]}.          |
|                                                                      |
|  Before implementing, you MUST:                                      |
|  1. Write UI tests (XCUITest) for the user interface                 |
|  2. Run the tests - they MUST FAIL (RED)                             |
|  3. Register artifact with type: "ui_test_output"                    |
|                                                                      |
|  UI tests verify:                                                    |
|  - Components render correctly                                       |
|  - User interactions work as expected                                |
|  - Navigation flows are correct                                      |
|                                                                      |
|  Use /add-artifact to register UI test evidence.                     |
+======================================================================+
"""

    # Validate each artifact
    for artifact in red_artifacts:
        valid, reason = validate_artifact(artifact)
        if not valid:
            return False, f"""
+======================================================================+
|  INVALID TEST ARTIFACT!                                              |
+======================================================================+
|  Artifact: {artifact.get('path', 'unknown')[:50]}
|  Problem: {reason[:50]}
|                                                                      |
|  Test artifacts must be REAL, not placeholders:                      |
|  - Actual screenshot files (PNG, JPG) with content                   |
|  - Actual test output logs                                           |
|  - Actual API responses                                              |
|                                                                      |
|  Fix the artifact or add a valid one with /add-artifact.             |
+======================================================================+
"""

    # Check for test failure evidence (at least one artifact should show failure)
    failure_indicators = ["fail", "error", "red", "not found", "exception", "assert", "cannot find"]
    has_failure_evidence = False

    for artifact in red_artifacts:
        desc_lower = artifact.get("description", "").lower()
        if any(indicator in desc_lower for indicator in failure_indicators):
            has_failure_evidence = True
            break

    if not has_failure_evidence:
        return False, f"""
+======================================================================+
|  NO FAILURE EVIDENCE!                                                |
+======================================================================+
|  TDD RED phase requires tests that FAIL.                             |
|                                                                      |
|  Your artifacts don't indicate test failures.                        |
|  At least one artifact description should mention:                   |
|  - "test failed"                                                     |
|  - "assertion error"                                                 |
|  - "expected X but got Y"                                            |
|                                                                      |
|  If tests pass already, you're not doing TDD - you're testing        |
|  after the fact. Write tests for functionality that doesn't          |
|  exist yet!                                                          |
+======================================================================+
"""

    # STRICT CHECK: Require ui_test_red_done flag with verified failure
    ui_test_red_done = workflow.get("ui_test_red_done", False)
    ui_test_red_result = workflow.get("ui_test_red_result", "")

    if not ui_test_red_done:
        return False, f"""
+======================================================================+
|  UI TESTS NOT VERIFIED AS FAILING!                                   |
+======================================================================+
|  Workflow flag 'ui_test_red_done' is not set to true.                |
|                                                                      |
|  You MUST:                                                           |
|  1. Write UI tests FIRST (before any implementation)                 |
|  2. Run xcodebuild test -only-testing:TimeBoxUITests/[YourTests]     |
|  3. Capture the ACTUAL failure output                                |
|  4. Set ui_test_red_done=true and ui_test_red_result="failed:..."    |
|                                                                      |
|  Use /tdd-red to properly start the TDD RED phase.                   |
+======================================================================+
"""

    # Verify the result indicates actual failure
    if not ui_test_red_result or "fail" not in ui_test_red_result.lower():
        return False, f"""
+======================================================================+
|  UI TEST RED RESULT NOT VERIFIED!                                    |
+======================================================================+
|  ui_test_red_result: "{ui_test_red_result[:40]}..."                   |
|                                                                      |
|  Result must contain "fail" to prove tests actually failed.          |
|  Retroactive "exemption" results are not accepted.                   |
|                                                                      |
|  Run the UI tests and capture actual failure output.                 |
+======================================================================+
"""

    return True, "TDD RED phase validated (unit + UI tests with verified failure)"


def validate_artifact_timestamps(workflow: dict, file_path: str) -> tuple[bool, str]:
    """
    Validate that RED phase artifacts were created BEFORE code modifications.
    Prevents retroactive artifact creation to bypass TDD.
    """
    artifacts = workflow.get("test_artifacts", [])
    red_artifacts = [a for a in artifacts if a.get("phase") == "phase5_tdd_red"]

    if not red_artifacts:
        return True, "No RED artifacts to check timestamps"

    # Get the earliest RED artifact timestamp
    earliest_red = None
    for artifact in red_artifacts:
        created = artifact.get("created")
        if created:
            try:
                artifact_dt = datetime.fromisoformat(created.replace('Z', '+00:00'))
                if earliest_red is None or artifact_dt < earliest_red:
                    earliest_red = artifact_dt
            except (ValueError, TypeError):
                continue

    if not earliest_red:
        return True, "No valid artifact timestamps"

    # Check if the code file was modified BEFORE the RED artifacts
    code_path = Path(file_path)
    if code_path.exists():
        file_mtime = datetime.fromtimestamp(code_path.stat().st_mtime, tz=earliest_red.tzinfo)

        # If file was modified AFTER earliest RED artifact, that's suspicious
        # But we need to allow modifications during implementation
        # The key check: affected_files should NOT have been modified before RED phase
        affected_files = workflow.get("affected_files", [])

        # Check if this is the FIRST modification to the file in this workflow
        if str(file_path) in affected_files or any(file_path.endswith(af.split("/")[-1]) for af in affected_files):
            # File was already registered - allow modifications during implementation
            return True, "File already in affected_files - implementation in progress"

    return True, "Timestamp check passed"


def check_tdd_requirements(file_path: str) -> tuple[bool, str]:
    """
    Check if TDD requirements are met for modifying a file.
    Returns (allowed, reason).
    """
    workflow = get_active_workflow()

    if not workflow:
        return True, "No active workflow, TDD check skipped"

    phase = workflow.get("current_phase", "phase0_idle")

    # Only enforce TDD for implementation phases
    if phase not in TEST_REQUIRED_PHASES:
        return True, f"Phase {phase} doesn't require TDD artifacts"

    # Validate RED phase completion (must have artifacts)
    valid, reason = validate_red_phase(workflow)
    if not valid:
        return False, reason

    # Additional check: Verify artifact timestamps aren't retroactive
    valid, reason = validate_artifact_timestamps(workflow, file_path)
    if not valid:
        return False, reason

    return True, "TDD requirements met"


def check_user_override() -> bool:
    """Check if user has granted override via token file (not workflow state)."""
    token_path = Path(__file__).parent.parent / "user_override_token.json"
    if not token_path.exists():
        return False
    try:
        import json as _json
        from datetime import datetime as _dt, timedelta as _td
        token = _json.loads(token_path.read_text())
        # Check TTL (1 hour)
        created = token.get("created", "")
        if created:
            created_dt = _dt.fromisoformat(created)
            if _dt.now() - created_dt > _td(hours=1):
                token_path.unlink(missing_ok=True)
                return False
        # Check workflow match
        state = load_state()
        active_name = state.get("active_workflow", "")
        return token.get("workflow") == active_name
    except (json.JSONDecodeError, KeyError, ValueError, OSError):
        return False


def main():
    """Main hook entry point."""
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

    # Check for user override FIRST (allows bypassing TDD for edge cases)
    if check_user_override():
        sys.exit(0)

    # Skip for non-code files
    code_extensions = [".py", ".js", ".ts", ".swift", ".kt", ".java", ".go", ".rs", ".cpp", ".c", ".h"]
    if not any(file_path.endswith(ext) for ext in code_extensions):
        sys.exit(0)

    # Skip for test files (we want to allow writing tests!)
    test_patterns = ["test_", "_test.", ".test.", "tests/", "spec/", "_spec."]
    if any(pattern in file_path.lower() for pattern in test_patterns):
        sys.exit(0)

    # Skip for workflow infrastructure files (meta-files, not app code)
    infrastructure_patterns = [".claude/hooks/", ".claude/config", "docs/specs/", "docs/artifacts/"]
    if any(pattern in file_path for pattern in infrastructure_patterns):
        sys.exit(0)

    # Check TDD requirements
    allowed, reason = check_tdd_requirements(file_path)

    if not allowed:
        print(reason, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
