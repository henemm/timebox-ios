#!/usr/bin/env python3
"""
Result Inspection Gate — Post-Implementation Screenshot Proof

Blocks phase transitions to adversary/validate phases unless
a result screenshot has been validated via inspection_gate.py.

Trigger: PreToolUse Bash — blocks commands that advance to phase6b or phase7.

Proof-Based: result_inspection_done can ONLY be set by inspection_gate.py.
This gate checks both the flag AND that the screenshot file exists.

Exit Codes:
- 0: Allowed
- 2: Blocked (stderr shown to Claude)
"""

import json
import os
import re
import sys
from pathlib import Path

try:
    from workflow_state_multi import session_active_name, load_state as load_wf_state
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import session_active_name, load_state as load_wf_state
    except ImportError:
        def session_active_name(state):
            return state.get("active_workflow")


def get_state_file() -> Path:
    """Get workflow state file path."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent / ".claude" / "workflow_state.json"
    return cwd / ".claude" / "workflow_state.json"


def has_valid_override_token(workflow_name: str = None) -> bool:
    """Check if a valid override token exists."""
    try:
        from override_token import has_valid_token
    except ImportError:
        sys.path.insert(0, str(Path(__file__).parent))
        from override_token import has_valid_token
    return has_valid_token(workflow_name)


def get_command() -> str:
    """Extract the bash command from hook input."""
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            return ""
    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        return ""
    return data.get("command", "")


def is_phase_advance_command(command: str) -> bool:
    """Check if command advances to adversary or validate phase."""
    # Match phase transitions that need result inspection
    patterns = [
        r"phase\s+phase6b",
        r"phase\s+phase7",
        r"phase\s+phase8",
        r"adversary_gate\.py",
    ]
    for pattern in patterns:
        if re.search(pattern, command):
            return True
    return False


def main():
    command = get_command()
    if not command:
        sys.exit(0)

    # Only check phase-advance commands
    if not is_phase_advance_command(command):
        sys.exit(0)

    # Allow running inspection_gate.py itself
    if "inspection_gate.py" in command:
        sys.exit(0)

    # Load workflow state
    state_file = get_state_file()
    if not state_file.exists():
        sys.exit(0)

    try:
        state = json.loads(state_file.read_text())
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    # Get active workflow
    active_name = session_active_name(state)
    if not active_name:
        sys.exit(0)

    # Only enforce for bug and feature workflows
    if not (active_name.startswith("bug-") or active_name.startswith("feature-")):
        sys.exit(0)

    workflow = state.get("workflows", {}).get(active_name)
    if not workflow:
        sys.exit(0)

    # Check for user override
    if workflow.get("user_override", False):
        sys.exit(0)
    if has_valid_override_token(active_name):
        sys.exit(0)

    # Check if result inspection is done — proof-based!
    if workflow.get("result_inspection_done", False):
        screenshot_path = workflow.get("result_inspection_screenshot", "")
        if screenshot_path and Path(screenshot_path).exists():
            sys.exit(0)  # Proof verified — screenshot exists
        override_reason = workflow.get("result_inspection_override_reason", "")
        if override_reason:
            sys.exit(0)  # Override with justification accepted

    # BLOCK — result inspection not done
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED: Result-Inspektion fehlt!                               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Workflow: {active_name[:53]:<53} ║
║                                                                  ║
║  Du hast Code geschrieben. Jetzt musst du PRUEFEN ob er          ║
║  funktioniert — BEVOR du zur Adversary-Phase wechselst.          ║
║                                                                  ║
║  PFLICHT-SCHRITTE:                                               ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ 1. App bauen & starten:                                     │ ║
║  │    ./scripts/sim.sh build && ./scripts/sim.sh launch        │ ║
║  │ 2. Screenshot machen:                                       │ ║
║  │    ./scripts/sim.sh screenshot /tmp/result.png              │ ║
║  │    ODER: xcrun simctl io booted screenshot /tmp/result.png  │ ║
║  │ 3. Screenshot ansehen (Read Tool)                           │ ║
║  │ 4. Screenshot validieren:                                   │ ║
║  │    python3 .claude/hooks/inspection_gate.py after \\         │ ║
║  │      /tmp/result.png                                        │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  KEIN SCREENSHOT MOEGLICH?                                       ║
║  → FRAGE HENNING um Override.                                    ║
║  Verbringe KEINE Zeit damit, einen Workaround zu suchen.        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
