#!/usr/bin/env python3
"""
Visual Inspection Gate — PFLICHT fuer Bug- und Feature-Workflows

Blockiert Task-Tool-Aufrufe (Investigation Agents) solange keine
visuelle Inspektion stattgefunden hat.

Regel: Bei Bug- und Feature-Workflows MUSS zuerst ein Screenshot
gemacht und via inspection_gate.py validiert werden,
BEVOR Investigate-Agents losgeschickt werden.

Proof-Based: Das Feld visual_inspection_done kann NUR durch
inspection_gate.py gesetzt werden (nicht per set-field).
Zusaetzlich wird geprueft ob die Screenshot-Datei existiert.

Ausnahme: Override-Token vom User (fuer Tasks ohne visuellen Aspekt).

Exit Codes:
- 0: Erlaubt
- 2: Blockiert (stderr wird Claude angezeigt)
"""

import json
import os
import sys
from datetime import datetime
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


def main():
    # Get tool input
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    # Load workflow state
    state_file = get_state_file()
    if not state_file.exists():
        sys.exit(0)  # No state = no enforcement

    try:
        state = json.loads(state_file.read_text())
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    # Get active workflow (session-aware)
    active_name = session_active_name(state)
    if not active_name:
        sys.exit(0)  # No active workflow

    # Skip only explicitly non-inspectable workflows (e.g. chore/docs)
    SKIP_PREFIXES = ("chore-", "docs-", "refactor-")
    if active_name.startswith(SKIP_PREFIXES):
        sys.exit(0)

    workflow = state.get("workflows", {}).get(active_name)
    if not workflow:
        sys.exit(0)

    # New UI features have nothing to screenshot yet — skip inspection
    if workflow.get("is_new_ui", False):
        sys.exit(0)

    # Check if visual inspection is done — proof-based!
    # Either a real screenshot file must exist, or an override reason must be set
    if workflow.get("visual_inspection_done", False):
        screenshot_path = workflow.get("visual_inspection_screenshot", "")
        if screenshot_path and Path(screenshot_path).exists():
            sys.exit(0)  # Proof verified — screenshot exists
        override_reason = workflow.get("visual_inspection_override_reason", "")
        if override_reason:
            sys.exit(0)  # Override with justification accepted

    # Check for user override
    if workflow.get("user_override", False):
        sys.exit(0)

    if has_valid_override_token(active_name):
        sys.exit(0)

    # BLOCK — visual inspection not done (proof-based)
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED: Visuelle Inspektion fehlt!                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Workflow: {active_name[:53]:<53} ║
║                                                                  ║
║  BEVOR du Investigate-Agents losschickst, musst du               ║
║  dir ZUERST ein eigenes Bild vom Problem machen!                 ║
║                                                                  ║
║  PFLICHT-SCHRITTE:                                               ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ 1. Screenshot machen:                                       │ ║
║  │    xcrun simctl io booted screenshot /tmp/inspect.png       │ ║
║  │ 2. Screenshot ansehen (Read Tool auf die Datei)             │ ║
║  │ 3. Beschreiben: Was siehst du? Was stimmt nicht?            │ ║
║  │ 4. Screenshot validieren:                                   │ ║
║  │    python3 .claude/hooks/inspection_gate.py before \\        │ ║
║  │      /tmp/inspect.png                                       │ ║
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
