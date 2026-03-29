#!/usr/bin/env python3
"""
TDD GREEN Listener — Listens for user approval of GREEN test results.

When the user says "go", "weiter", "tests ok", or "green ok",
this hook sets tdd_green_approved=True on the active workflow.

This is the counterpart to tdd_green_gate.py which blocks validation
until the user has approved.

Pattern: Same as workflow_state_updater.py handles "approved" for specs.

Exit Codes:
- 0: Always (listener never blocks)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    from workflow_state_multi import (
        load_state, _state_lock, _save_state_unlocked,
        session_active_name, publish_session_id
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import (
            load_state, _state_lock, _save_state_unlocked,
            session_active_name, publish_session_id
        )
    except ImportError:
        def load_state():
            return {"version": "2.0", "workflows": {}, "active_workflow": None}
        def _state_lock():
            import contextlib
            return contextlib.nullcontext()
        def _save_state_unlocked(state):
            pass
        def session_active_name(state, **kw):
            return state.get("active_workflow")
        def publish_session_id(sid):
            pass

# Phrases that approve GREEN test results
GREEN_APPROVAL_PHRASES = [
    "go",
    "weiter",
    "tests ok",
    "green ok",
    "tdd ok",
    "ergebnisse ok",
]


def is_green_approval(message: str) -> bool:
    """Check if message contains a GREEN approval phrase."""
    message_lower = message.lower().strip()

    for phrase in GREEN_APPROVAL_PHRASES:
        pattern = r'\b' + re.escape(phrase) + r'\b'
        if re.search(pattern, message_lower):
            return True

    return False


def _find_green_target(state: dict, active_name: str | None) -> str | None:
    """Find the workflow that needs GREEN approval.

    Priority:
    1. Active workflow in phase6_implement with tests done but not approved
    2. Any workflow in that state (handles race conditions)
    """
    workflows = state.get("workflows", {})

    def _needs_green_approval(wf: dict) -> bool:
        phase = wf.get("current_phase", "")
        # Must be in implementation or validation phase
        if phase not in ("phase6_implement", "phase7_validate"):
            return False
        # Must have GREEN test results but no user approval
        has_green = (
            wf.get("unit_test_green_done", False)
            or wf.get("ui_test_green_done", False)
        )
        not_approved = not wf.get("tdd_green_approved", False)
        return has_green and not_approved

    # Prefer active workflow
    if active_name and active_name in workflows:
        if _needs_green_approval(workflows[active_name]):
            return active_name

    # Fallback: any workflow needing approval
    for name, wf in workflows.items():
        if _needs_green_approval(wf):
            return name

    return None


def main():
    # Get user input
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        data = {}
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    # Publish session ID
    session_id = data.get("session_id", "")
    if session_id:
        publish_session_id(session_id)

    if not user_message:
        sys.exit(0)

    if not is_green_approval(user_message):
        sys.exit(0)

    # Find workflow needing GREEN approval
    state = load_state()
    session_id = data.get("session_id", "")
    active_name = session_active_name(state, session_id=session_id)

    target_name = _find_green_target(state, active_name)
    if not target_name:
        sys.exit(0)

    # Set tdd_green_approved flag
    with _state_lock():
        state = load_state()
        if target_name not in state["workflows"]:
            sys.exit(0)
        state["workflows"][target_name]["tdd_green_approved"] = True
        state["workflows"][target_name]["tdd_green_approved_at"] = datetime.now().isoformat()
        state["workflows"][target_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

    print(f"TDD GREEN freigegeben fuer '{target_name}'! Du kannst jetzt /06-validate ausfuehren.")
    sys.exit(0)


if __name__ == "__main__":
    main()
