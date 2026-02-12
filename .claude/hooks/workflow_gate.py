#!/usr/bin/env python3
"""
OpenSpec Framework - Workflow Gate Hook

Enforces the 4-phase workflow for protected files:
1. idle -> analyse_done (/analyse)
2. analyse_done -> spec_written (/write-spec)
3. spec_written -> spec_approved (user says "approved")
4. spec_approved -> implemented (/implement)
5. implemented -> validated (/validate)

Blocks Edit/Write on protected files unless workflow phase allows it.

MANUAL OVERRIDE:
Set "user_override": true in workflow_state.json to bypass all checks.
This allows the user to grant explicit permission for edge cases.

Exit Codes:
- 0: Allowed
- 2: Blocked (stderr shown to Claude)
"""

import json
import os
import sys
import re
from pathlib import Path

# Import shared config loader
try:
    from config_loader import (
        load_config, get_state_file_path, get_project_root,
        get_protected_paths, get_always_allowed
    )
except ImportError:
    # Fallback for direct execution
    sys.path.insert(0, str(Path(__file__).parent))
    from config_loader import (
        load_config, get_state_file_path, get_project_root,
        get_protected_paths, get_always_allowed
    )


def load_state() -> dict:
    """Load current workflow state."""
    state_file = get_state_file_path()

    if not state_file.exists():
        return {
            "current_phase": "idle",
            "feature_name": None,
            "spec_file": None,
            "spec_approved": False,
            "implementation_done": False,
            "validation_done": False,
        }

    with open(state_file, 'r') as f:
        return json.load(f)


def get_active_workflow(state: dict) -> dict | None:
    """Get the active workflow from v2 state structure."""
    if "workflows" in state and "active_workflow" in state:
        active_name = state.get("active_workflow")
        if active_name and active_name in state["workflows"]:
            return state["workflows"][active_name]
    return None


def find_workflow_for_file(state: dict, file_path: str) -> tuple[dict | None, str | None]:
    """Find the workflow that owns a file via affected_files.

    Returns (workflow_dict, workflow_name) or (None, None) if no match.
    """
    workflows = state.get("workflows", {})
    # Normalize: strip project root prefix for matching
    root = str(get_project_root())
    rel_path = file_path
    if rel_path.startswith(root):
        rel_path = rel_path[len(root):].lstrip("/")

    for name, wf in workflows.items():
        for af in wf.get("affected_files", []):
            # Match if file_path ends with the affected_file or vice versa
            if rel_path == af or rel_path.endswith("/" + af) or af.endswith("/" + rel_path):
                return wf, name
    return None, None


def resolve_workflow(state: dict, file_path: str) -> tuple[dict | None, str | None]:
    """Resolve which workflow applies for a file edit.

    Priority:
    1. Workflow that owns the file (via affected_files)
    2. Active workflow (fallback)
    3. None (no workflow found)
    """
    # First: check if any workflow owns this file
    wf, name = find_workflow_for_file(state, file_path)
    if wf:
        return wf, name

    # Fallback: active workflow ONLY if it has no affected_files defined
    # (i.e., initial state before files are scoped). If affected_files
    # exist but don't match, this file is out of scope - BLOCK.
    active_name = state.get("active_workflow")
    if active_name and active_name in state.get("workflows", {}):
        active_wf = state["workflows"][active_name]
        if not active_wf.get("affected_files"):
            return active_wf, active_name

    return None, None


def check_user_override(state: dict, file_path: str = "") -> bool:
    """Check if user has granted manual override."""
    # Global override
    if state.get("user_override", False):
        return True

    # Resolve the relevant workflow for this file
    workflow, _ = resolve_workflow(state, file_path) if file_path else (get_active_workflow(state), None)
    if workflow and workflow.get("user_override", False):
        return True

    return False


def is_always_allowed(file_path: str) -> bool:
    """Check if file is always allowed without workflow."""
    patterns = get_always_allowed()
    for pattern in patterns:
        if re.search(pattern, file_path):
            return True
    return False


def requires_workflow(file_path: str) -> bool:
    """Check if file requires workflow."""
    protected = get_protected_paths()
    for item in protected:
        pattern = item.get("pattern", item) if isinstance(item, dict) else item
        if re.search(pattern, file_path):
            return True
    return False


def get_current_phase(state: dict, file_path: str = "") -> str:
    """Get current phase from v1 or v2 state structure.

    If file_path is given, resolves the owning workflow first.
    """
    if file_path:
        workflow, _ = resolve_workflow(state, file_path)
        if workflow:
            return workflow.get("current_phase", "idle")

    # Try active workflow
    workflow = get_active_workflow(state)
    if workflow:
        return workflow.get("current_phase", "idle")

    # Fall back to v1
    return state.get("current_phase", "idle")


def get_phase_error(state: dict, file_path: str) -> str | None:
    """Generate error message based on current state."""
    phase = get_current_phase(state)

    # Support both old (v1) and new (v2) phase names
    if phase in ["idle", "phase0_idle"]:
        return """
╔══════════════════════════════════════════════════════════════════╗
║  WORKFLOW NOT STARTED!                                           ║
╠══════════════════════════════════════════════════════════════════╣
║  You're trying to modify code without starting the workflow.     ║
║                                                                  ║
║  REQUIRED WORKFLOW:                                              ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ /context    → Gather relevant context         (Phase 1)     │ ║
║  │ /analyse    → Analyse requirements            (Phase 2)     │ ║
║  │ /write-spec → Create specification            (Phase 3)     │ ║
║  │ "approved"  → User approval                   (Phase 4)     │ ║
║  │ /tdd-red    → Write FAILING tests             (Phase 5)     │ ║
║  │ /implement  → Make tests GREEN                (Phase 6)     │ ║
║  │ /validate   → Manual validation               (Phase 7)     │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  START WITH: /context or /analyse                                ║
║                                                                  ║
║  MANUAL OVERRIDE: User can say "ich genehmige das" to bypass.    ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["phase1_context"]:
        return """
╔══════════════════════════════════════════════════════════════════╗
║  CONTEXT PHASE - Analysis Required                               ║
╠══════════════════════════════════════════════════════════════════╣
║  Context is being gathered, but analysis isn't complete.         ║
║                                                                  ║
║  NEXT: /analyse                                                  ║
║                                                                  ║
║  Complete the analysis before modifying code!                    ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["analyse_done", "phase2_analyse"]:
        return """
╔══════════════════════════════════════════════════════════════════╗
║  SPEC MISSING!                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  Analysis is complete, but no spec has been written.             ║
║                                                                  ║
║  NEXT: /write-spec                                               ║
║                                                                  ║
║  The spec defines WHAT to build and HOW to test it.              ║
║  NO implementation without a spec!                               ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["spec_written", "phase3_spec"]:
        spec_file = state.get("spec_file", "unknown")
        return f"""
╔══════════════════════════════════════════════════════════════════╗
║  SPEC NOT APPROVED!                                              ║
╠══════════════════════════════════════════════════════════════════╣
║  Spec exists but USER hasn't approved it yet.                    ║
║                                                                  ║
║  Spec: {spec_file[:55]:<55}║
║                                                                  ║
║  USER must confirm with one of:                                  ║
║    "approved" | "freigabe" | "spec ok" | "lgtm"                  ║
║                                                                  ║
║  Claude CANNOT approve specs - only the user can!                ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["spec_approved", "phase4_approved"]:
        workflow = get_active_workflow(state)
        red_done = state.get("red_test_done", False)
        if workflow:
            red_done = workflow.get("red_test_done", False) or workflow.get("ui_test_red_done", False)
        if not red_done:
            return """
╔══════════════════════════════════════════════════════════════════╗
║  TDD RED PHASE REQUIRED!                                         ║
╠══════════════════════════════════════════════════════════════════╣
║  Spec is approved, but you must write FAILING tests first!       ║
║                                                                  ║
║  TDD = Test-Driven Development:                                  ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │  RED   → Write tests that FAIL (feature doesn't exist)      │ ║
║  │  GREEN → Write code to make tests PASS                      │ ║
║  │  REFACTOR → Clean up (optional)                             │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  NEXT: /tdd-red                                                  ║
║                                                                  ║
║  Write tests, run them, capture the FAILURE as artifact!         ║
║                                                                  ║
║  MANUAL OVERRIDE: User can say "ich genehmige das" to bypass.    ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["phase5_tdd_red"]:
        workflow = get_active_workflow(state)
        red_done = False
        if workflow:
            red_done = workflow.get("red_test_done", False) or workflow.get("ui_test_red_done", False)
        if not red_done:
            return """
╔══════════════════════════════════════════════════════════════════╗
║  TDD RED PHASE - Capture Failure First!                          ║
╠══════════════════════════════════════════════════════════════════╣
║  You're in the RED phase but haven't captured test failure yet.  ║
║                                                                  ║
║  REQUIRED:                                                       ║
║  1. Write tests for the new functionality                        ║
║  2. Run tests - they MUST FAIL                                   ║
║  3. Capture failure: /add-artifact                               ║
║                                                                  ║
║  Only after capturing RED failure can you implement!             ║
║                                                                  ║
║  MANUAL OVERRIDE: User can say "ich genehmige das" to bypass.    ║
╚══════════════════════════════════════════════════════════════════╝
"""

    if phase in ["implemented", "phase6_implement"]:
        if not state.get("validation_done", False) and not state.get("green_test_done", False):
            return """
╔══════════════════════════════════════════════════════════════════╗
║  VALIDATION REQUIRED!                                            ║
╠══════════════════════════════════════════════════════════════════╣
║  Implementation done, but not validated yet.                     ║
║                                                                  ║
║  NEXT: /validate                                                 ║
║                                                                  ║
║  Verify tests are GREEN and do manual testing!                   ║
╚══════════════════════════════════════════════════════════════════╝
"""

    return None


def main():
    # Get tool input from environment or stdin
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
        sys.exit(0)  # No file_path, allow through

    # Check if file is always allowed
    if is_always_allowed(file_path):
        sys.exit(0)

    # Check if file requires workflow
    if not requires_workflow(file_path):
        sys.exit(0)

    # Load state
    state = load_state()

    # Check for user override FIRST (file-aware)
    if check_user_override(state, file_path):
        sys.exit(0)  # User has granted override, allow through

    # Resolve which workflow applies for this file
    workflow, wf_name = resolve_workflow(state, file_path)

    # No workflow found at all -> allow (don't block unowned files)
    if not workflow and not state.get("workflows"):
        sys.exit(0)

    # Get phase from the resolved workflow
    phase = workflow.get("current_phase", "idle") if workflow else get_current_phase(state, file_path)

    # Allowed phases for implementation (v1 and v2 names)
    allowed_phases = [
        "spec_approved", "implemented", "validated",
        "phase4_approved", "phase5_tdd_red", "phase6_implement",
        "phase7_validate", "phase8_complete"
    ]

    if phase in allowed_phases:
        # Additional check: in phase5, need red_test_done
        if phase in ["phase5_tdd_red"]:
            if workflow:
                red_done = workflow.get("red_test_done", False) or workflow.get("ui_test_red_done", False)
                if red_done:
                    sys.exit(0)
            # Fall through to error
        else:
            sys.exit(0)  # Workflow correct, allow through

    # Block with appropriate error message
    error = get_phase_error(state, file_path)
    if error:
        print(error, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
