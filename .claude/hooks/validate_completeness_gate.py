#!/usr/bin/env python3
"""
Validate Completeness Gate — Blocks git commit without full validation.

Ensures that /06-validate was actually executed with ALL 4 checks:
1. Test Check (feature tests pass)
2. Spec Compliance (acceptance criteria met)
3. Regression Check (full test suite, no regressions)
4. Scope Check (file count + LoC limits)

Without this gate, Claude can skip the regression check and go straight
to commit after feature tests pass.

Checks workflow state flags:
- regression_check_done: Full test suite was run (not just feature tests)
- validation_phase_done: All 4 validation checks completed

Exit Codes:
- 0: Allowed
- 2: Blocked
"""

import json
import os
import sys
from pathlib import Path

try:
    from workflow_state_multi import session_active_name
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import session_active_name
    except ImportError:
        def session_active_name(state):
            return state.get("active_workflow")

try:
    from override_token import has_valid_token
except ImportError:
    def has_valid_token(name):
        return False


def get_tool_input() -> dict:
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass
    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except Exception:
        return {}


def load_workflow_state() -> dict | None:
    state_file = Path(__file__).parent.parent / "workflow_state.json"
    if not state_file.exists():
        return None
    try:
        with open(state_file, 'r') as f:
            return json.load(f)
    except Exception:
        return None


def main():
    tool_input = get_tool_input()
    command = tool_input.get("command", "")

    # Only trigger on git commit (not amend)
    if "git commit" not in command or "--amend" in command:
        sys.exit(0)

    state = load_workflow_state()
    if not state:
        sys.exit(0)

    workflows = state.get("workflows", {})
    active_name = session_active_name(state)
    if not active_name or active_name not in workflows:
        sys.exit(0)

    workflow = workflows[active_name]
    phase = workflow.get("current_phase", "phase0_idle")

    # Only enforce for commit-ready phases
    if phase not in ("phase7_validate", "phase8_complete"):
        sys.exit(0)

    # Respect override token
    if workflow.get("user_override", False):
        sys.exit(0)
    if has_valid_token(active_name):
        sys.exit(0)

    # Check regression_check_done
    regression_done = workflow.get("regression_check_done", False)
    if not regression_done:
        print("=" * 70, file=sys.stderr)
        print("BLOCKED — Regression Check nicht durchgefuehrt", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(file=sys.stderr)
        print(f"  Workflow: {active_name}", file=sys.stderr)
        print(f"  Phase: {phase}", file=sys.stderr)
        print(file=sys.stderr)
        print("  Du hast die Feature-Tests ausgefuehrt, aber NICHT die", file=sys.stderr)
        print("  vollstaendige Test-Suite (Regression Check).", file=sys.stderr)
        print(file=sys.stderr)
        print("  /06-validate verlangt 4 parallele Checks:", file=sys.stderr)
        print("  1. Test Check        <- Feature-Tests", file=sys.stderr)
        print("  2. Spec Compliance   <- Acceptance Criteria", file=sys.stderr)
        print("  3. REGRESSION CHECK  <- FEHLEND! Volle Test-Suite", file=sys.stderr)
        print("  4. Scope Check       <- Datei/LoC-Limits", file=sys.stderr)
        print(file=sys.stderr)
        print("  Fuehre die volle Test-Suite aus und markiere:", file=sys.stderr)
        print("  python3 .claude/hooks/workflow_state_multi.py mark-regression-done \"All N tests passed\"", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(2)

    # Check validation_phase_done
    validation_done = workflow.get("validation_phase_done", False)
    if not validation_done:
        print("=" * 70, file=sys.stderr)
        print("BLOCKED — Validation Phase nicht abgeschlossen", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(file=sys.stderr)
        print(f"  Workflow: {active_name}", file=sys.stderr)
        print(f"  Phase: {phase}", file=sys.stderr)
        print(file=sys.stderr)
        print("  /06-validate wurde nicht vollstaendig durchgefuehrt.", file=sys.stderr)
        print("  Alle 4 Checks muessen bestanden sein.", file=sys.stderr)
        print(file=sys.stderr)
        print("  Status:", file=sys.stderr)
        print(f"    regression_check_done: {regression_done}", file=sys.stderr)
        print(f"    docs_updated: {workflow.get('docs_updated', False)}", file=sys.stderr)
        print(f"    adversary_verdict: {workflow.get('adversary_verdict', 'MISSING')}", file=sys.stderr)
        print(file=sys.stderr)
        print("  Fuehre /06-validate vollstaendig durch.", file=sys.stderr)
        print("  Dann markiere:", file=sys.stderr)
        print("  python3 .claude/hooks/workflow_state_multi.py mark-validation-done \"All 4 checks passed\"", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
