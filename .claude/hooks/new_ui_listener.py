#!/usr/bin/env python3
"""
New UI Listener - UserPromptSubmit Hook

Listens for "neues ui" keyword in user messages.
When detected, sets is_new_ui=true on the active workflow,
which skips the visual inspection screenshot requirement.

This is the ONLY way to set is_new_ui — Claude CANNOT set it via set-field.

Keywords: "neues ui", "neues UI", "komplett neu"

Exit Codes:
- 0: Always (this hook never blocks, only sets field)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    from workflow_state_multi import load_state, session_active_name, _state_lock, _save_state_unlocked
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import load_state, session_active_name, _state_lock, _save_state_unlocked


NEW_UI_KEYWORDS = [
    "neues ui",
    "komplett neu",
    "neuer screen",
    "neues feature ohne bestehenden screen",
]


def is_new_ui_message(message: str) -> bool:
    """Check if message indicates this is a new UI feature."""
    message_lower = message.lower().strip()
    for keyword in NEW_UI_KEYWORDS:
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, message_lower):
            return True
    return False


def main():
    # Get user input from stdin
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    if not user_message:
        sys.exit(0)

    if not is_new_ui_message(user_message):
        sys.exit(0)

    # Set is_new_ui on active workflow
    with _state_lock():
        state = load_state()
        active_name = session_active_name(state)

        if not active_name or active_name not in state.get("workflows", {}):
            print("No active workflow — is_new_ui not set.", file=sys.stderr)
            sys.exit(0)

        state["workflows"][active_name]["is_new_ui"] = True
        state["workflows"][active_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

    print(f"is_new_ui=true set for workflow: {active_name}")
    sys.exit(0)


if __name__ == "__main__":
    main()
