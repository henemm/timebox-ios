#!/usr/bin/env python3
"""
TDD GREEN Gate — Blocks validation until USER approves test results.

After TDD GREEN (tests pass), Claude must present the results summary
to the user. Only when the user says "go" (or similar) can Claude
proceed to /06-validate.

This prevents Claude from dismissing test findings as "irrelevant"
and rushing to validation.

Trigger: PreToolUse on Bash, when command contains:
- "phase phase7_validate"
- "mark-validation-done"

Checks: workflow.tdd_green_approved == True

Exit Codes:
- 0: Allowed
- 2: Blocked (user has not approved GREEN results)
"""

import json
import os
import sys
from pathlib import Path

try:
    from workflow_state_multi import load_state, session_active_name
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import load_state, session_active_name
    except ImportError:
        def load_state():
            return {"version": "2.0", "workflows": {}, "active_workflow": None}
        def session_active_name(state, **kw):
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


def main():
    tool_input = get_tool_input()
    command = tool_input.get("command", "")

    # Only trigger on validation-related commands
    triggers = [
        "phase phase7_validate",
        "mark-validation-done",
    ]
    if not any(t in command for t in triggers):
        sys.exit(0)

    # Load workflow state
    state = load_state()
    active_name = session_active_name(state)
    if not active_name:
        sys.exit(0)

    workflows = state.get("workflows", {})
    workflow = workflows.get(active_name, {})
    if not workflow:
        sys.exit(0)

    phase = workflow.get("current_phase", "phase0_idle")

    # Only enforce in implementation/validation phases
    if phase not in ("phase6_implement", "phase7_validate"):
        sys.exit(0)

    # Check override token
    if workflow.get("user_override", False):
        sys.exit(0)
    if has_valid_token(active_name):
        sys.exit(0)

    # Check if user has approved GREEN results
    if workflow.get("tdd_green_approved", False):
        sys.exit(0)

    # BLOCKED
    print("=" * 70, file=sys.stderr)
    print("BLOCKED — User muss TDD GREEN Ergebnisse freigeben!", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    print(file=sys.stderr)
    print(f"  Workflow: {active_name}", file=sys.stderr)
    print(f"  Phase: {phase}", file=sys.stderr)
    print(file=sys.stderr)
    print("  Die Tests sind durchgelaufen. Bevor du zur Validation", file=sys.stderr)
    print("  weitergehst, MUSS der User die Ergebnisse sehen und", file=sys.stderr)
    print("  freigeben.", file=sys.stderr)
    print(file=sys.stderr)
    print("  Was du tun musst:", file=sys.stderr)
    print("  1. Dem User eine ZUSAMMENFASSUNG der Test-Ergebnisse zeigen:", file=sys.stderr)
    print("     - Welche Tests liefen? Alle bestanden?", file=sys.stderr)
    print("     - Was genau wurde getestet? (User-Sprache, kein Code)", file=sys.stderr)
    print("     - Gab es Auffaelligkeiten oder Warnungen?", file=sys.stderr)
    print("  2. Warten bis der User 'go' sagt", file=sys.stderr)
    print(file=sys.stderr)
    print("  Der User gibt frei mit:", file=sys.stderr)
    print('    "go" / "weiter" / "tests ok" / "green ok"', file=sys.stderr)
    print(file=sys.stderr)
    print("  WICHTIG: Du darfst NICHT selbst entscheiden, ob", file=sys.stderr)
    print("  Test-Ergebnisse relevant sind! Der User entscheidet.", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
