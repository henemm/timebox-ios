#!/usr/bin/env python3
"""
Feature Understanding Gate — PFLICHT fuer Feature-Workflows

Blockiert Task-Tool-Aufrufe (Investigation/Planning Agents) solange
kein User-Advocate Agent die User-Perspektive beschrieben hat.

Regel: Bei Feature-Workflows (Name startet mit "feature-") MUSS zuerst
der user-advocate Agent die User-Erwartung formuliert haben,
BEVOR technische Analyse-Agents losgeschickt werden.

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
        sys.exit(0)

    try:
        state = json.loads(state_file.read_text())
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    # Get active workflow (session-aware)
    active_name = session_active_name(state)
    if not active_name:
        sys.exit(0)

    # Only enforce for feature workflows
    if not active_name.startswith("feature-"):
        sys.exit(0)

    workflow = state.get("workflows", {}).get(active_name)
    if not workflow:
        sys.exit(0)

    # Check if user expectation is done
    if workflow.get("user_expectation_done", False):
        sys.exit(0)

    # Check for user override
    if workflow.get("user_override", False):
        sys.exit(0)

    if has_valid_override_token(active_name):
        sys.exit(0)

    # BLOCK
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED: User-Perspektive fehlt!                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Feature-Workflow: {active_name[:43]:<43} ║
║                                                                  ║
║  BEVOR du technische Analyse-Agents losschickst, muss           ║
║  zuerst die USER-PERSPEKTIVE geklaert werden!                   ║
║                                                                  ║
║  PFLICHT-SCHRITTE:                                               ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ 1. user-advocate Agent starten                              │ ║
║  │    Input: NUR die Feature-Beschreibung                      │ ║
║  │    KEIN Code-Kontext, KEINE Architektur-Details!            │ ║
║  │ 2. Agent beschreibt User-Erwartung                          │ ║
║  │ 3. Erwartung als Massstab festhalten:                       │ ║
║  │    python3 .claude/hooks/workflow_state_multi.py \\           │ ║
║  │      set-field user_expectation_done true                   │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                  ║
║  WARUM? Damit du das Feature aus User-Sicht verstehst,          ║
║  BEVOR du in Code und Architektur abtauchst.                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
