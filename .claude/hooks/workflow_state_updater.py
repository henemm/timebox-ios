#!/usr/bin/env python3
"""
OpenSpec Framework - Workflow State Updater Hook (v2.0 Multi-Workflow)

Listens for user approval phrases in UserPromptSubmit events.
When detected, updates the ACTIVE workflow to mark spec as approved.

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
        load_state, set_phase, _state_lock, _save_state_unlocked, session_active_name
    )
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import (
        load_state, set_phase, _state_lock, _save_state_unlocked, session_active_name
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


def main():
    # Get user input from environment or stdin
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    if not user_message:
        sys.exit(0)

    if not is_approval_message(user_message):
        sys.exit(0)

    # Find active workflow in v2 multi-workflow format
    state = load_state()
    active_name = session_active_name(state)
    if not active_name or active_name not in state.get("workflows", {}):
        sys.exit(0)

    workflow = state["workflows"][active_name]

    # Only process if workflow is in phase3_spec (spec written, awaiting approval)
    if workflow.get("current_phase") != "phase3_spec":
        sys.exit(0)

    # Set spec_approved flag with proper file-locking
    with _state_lock():
        state = load_state()
        if active_name not in state["workflows"]:
            sys.exit(0)
        state["workflows"][active_name]["spec_approved"] = True
        state["workflows"][active_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

    # Advance phase to phase4_approved
    success, message = set_phase(active_name, "phase4_approved", force=True)

    if success:
        print(f"Spec approved for '{active_name}'! You may now run /04-tdd-red")
    else:
        print(f"Spec approved but phase change failed: {message}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
