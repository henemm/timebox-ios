#!/usr/bin/env python3
"""
OpenSpec Framework - Workflow State Updater Hook (v2.0 Multi-Workflow)

Listens for user approval phrases in UserPromptSubmit events.
When detected, finds the workflow awaiting approval and marks it as approved.
Handles race conditions where the active workflow may have switched or the
phase was already advanced to phase4_approved before the flag was set.

Uses workflow_state_multi.py API for proper file-locking and v2 format.

Exit Codes:
- 0: Always (this hook never blocks, only updates state)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    from config_loader import get_approval_phrases
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from config_loader import get_approval_phrases

try:
    from workflow_state_multi import (
        load_state, set_phase, _state_lock, _save_state_unlocked,
        session_active_name, publish_session_id
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import (
        load_state, set_phase, _state_lock, _save_state_unlocked,
        session_active_name, publish_session_id
    )


def is_approval_message(message: str) -> bool:
    """Check if message contains an approval phrase."""
    message_lower = message.lower().strip()
    approval_phrases = get_approval_phrases()

    for phrase in approval_phrases:
        pattern = r'\b' + re.escape(phrase.lower()) + r'\b'
        if re.search(pattern, message_lower):
            return True

    return False


def _find_approval_target(state: dict, active_name: str | None) -> str | None:
    """Find the workflow that should receive the approval.

    Priority:
    1. Active workflow, if it's awaiting approval
    2. Any other workflow awaiting approval (handles workflow-switch race condition)
    Returns None if no workflow needs approval.
    """
    workflows = state.get("workflows", {})

    def _needs_approval(wf: dict) -> bool:
        return (
            wf.get("current_phase") in ("phase3_spec", "phase4_approved")
            and not wf.get("spec_approved")
        )

    # Prefer active workflow
    if active_name and active_name in workflows:
        if _needs_approval(workflows[active_name]):
            return active_name

    # Fallback: find any workflow awaiting approval
    for name, wf in workflows.items():
        if _needs_approval(wf):
            return name

    return None


def main():
    # Get user input from environment or stdin
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        data = {}
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    # ALWAYS publish session_id to temp file so Bash commands can read it.
    # This is the bridge between hooks (which have session_id) and CLI calls
    # (which don't). The temp file is read by _session_id() in workflow_state_multi.py.
    session_id = data.get("session_id", "")
    if session_id:
        publish_session_id(session_id)

    if not user_message:
        sys.exit(0)

    if not is_approval_message(user_message):
        sys.exit(0)

    # Find the workflow awaiting approval.
    # Strategy: search ALL workflows for one pending approval, not just the active one.
    # This prevents the bug where switching active workflow between spec-write and
    # user-approval causes the approval to hit the wrong workflow.
    state = load_state()
    session_id = data.get("session_id", "")
    active_name = session_active_name(state, session_id=session_id)

    target_name = _find_approval_target(state, active_name)
    if not target_name:
        sys.exit(0)

    # Set spec_approved flag with proper file-locking
    with _state_lock():
        state = load_state()
        if target_name not in state["workflows"]:
            sys.exit(0)
        state["workflows"][target_name]["spec_approved"] = True
        state["workflows"][target_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

    # Advance phase to phase4_approved
    success, message = set_phase(target_name, "phase4_approved", force=True)

    if success:
        print(f"Spec approved for '{target_name}'! You may now run /04-tdd-red")
    else:
        print(f"Spec approved but phase change failed: {message}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
