#!/usr/bin/env python3
"""
Visual Inspection Gate — PFLICHT fuer Bug-Workflows

Blockiert Task-Tool-Aufrufe (Investigation Agents) solange keine
visuelle Inspektion stattgefunden hat.

Regel: Bei Bug-Workflows (Name startet mit "bug-") MUSS zuerst
ein Screenshot oder /inspect-ui gemacht und beschrieben werden,
BEVOR Investigate-Agents losgeschickt werden.

Ausnahme: Override-Token vom User (fuer Bugs ohne visuellen Aspekt).

Exit Codes:
- 0: Erlaubt
- 2: Blockiert (stderr wird Claude angezeigt)
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path


def get_state_file() -> Path:
    """Get workflow state file path."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent / ".claude" / "workflow_state.json"
    return cwd / ".claude" / "workflow_state.json"


def has_valid_override_token(workflow_name: str = None) -> bool:
    """Check if a valid override token exists."""
    token_path = get_state_file().parent / "user_override_token.json"
    if not token_path.exists():
        return False
    try:
        token = json.loads(token_path.read_text())
        created = token.get("created", "")
        if created:
            created_dt = datetime.fromisoformat(created)
            if (datetime.now() - created_dt).total_seconds() > 3600:
                return False
        if workflow_name:
            return token.get("workflow") == workflow_name
        return True
    except (json.JSONDecodeError, ValueError, Exception):
        return False


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

    # Get active workflow
    active_name = state.get("active_workflow")
    if not active_name:
        sys.exit(0)  # No active workflow

    # Only enforce for bug workflows
    if not active_name.startswith("bug-"):
        sys.exit(0)

    workflow = state.get("workflows", {}).get(active_name)
    if not workflow:
        sys.exit(0)

    # Check if visual inspection is done
    if workflow.get("visual_inspection_done", False):
        sys.exit(0)  # Already inspected

    # Check for user override
    if workflow.get("user_override", False):
        sys.exit(0)

    if has_valid_override_token(active_name):
        sys.exit(0)

    # BLOCK — visual inspection not done
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED: Visuelle Inspektion fehlt!                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Bug-Workflow: {active_name[:47]:<47} ║
║                                                                  ║
║  BEVOR du Investigate-Agents losschickst, musst du               ║
║  dir ZUERST ein eigenes Bild vom Problem machen!                 ║
║                                                                  ║
║  PFLICHT-SCHRITTE:                                               ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ 1. Screenshot: xcrun simctl io booted screenshot /tmp/x.png │ ║
║  │    ODER /inspect-ui ausfuehren                              │ ║
║  │ 2. Screenshot ansehen (Read Tool)                           │ ║
║  │ 3. Beschreiben: Was siehst du? Was stimmt nicht?            │ ║
║  │ 4. Feld setzen:                                             │ ║
║  │    python3 .claude/hooks/workflow_state_multi.py \\           │ ║
║  │      set-field visual_inspection_done true                  │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  KEIN SCREENSHOT SINNVOLL?                                       ║
║  Erklaere Henning WARUM und bitte um Override.                   ║
║  (z.B. "Dieser Bug betrifft reine Datenlogik,                   ║
║   ein Screenshot wuerde nichts zeigen.")                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
