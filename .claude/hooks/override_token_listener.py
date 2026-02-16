#!/usr/bin/env python3
"""
Override Token Listener - UserPromptSubmit Hook

Listens for "override" keyword in user messages.
When detected, creates a token file that grants TDD bypass permission.

This is the ONLY way to create an override token.
Claude CANNOT create this file (blocked by guard hooks).

Keywords: "override", "override genehmigt", "ich genehmige"

Exit Codes:
- 0: Always (this hook never blocks, only creates token)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# Import multi-workflow state manager
try:
    from workflow_state_multi import load_state
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import load_state


# Keywords that trigger override token creation
OVERRIDE_KEYWORDS = [
    "override",
    "override genehmigt",
    "ich genehmige",
    "ich genehmige das",
]

TOKEN_FILE = Path(__file__).parent.parent / "user_override_token.json"


def is_override_message(message: str) -> bool:
    """Check if message contains an override keyword."""
    message_lower = message.lower().strip()

    for keyword in OVERRIDE_KEYWORDS:
        # Word boundary match to avoid false positives
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, message_lower):
            return True

    return False


def create_token(workflow_name: str) -> None:
    """Create the override token file."""
    token = {
        "workflow": workflow_name,
        "created": datetime.now().isoformat(),
        "granted_by": "user_prompt",
    }

    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(TOKEN_FILE, 'w') as f:
        json.dump(token, f, indent=2)


def main():
    # Get user input from stdin
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    if not user_message:
        sys.exit(0)

    # Check if this is an override message
    if not is_override_message(user_message):
        sys.exit(0)

    # Check for active workflow
    state = load_state()
    active_name = state.get("active_workflow")

    if not active_name or active_name not in state.get("workflows", {}):
        print("Override requested but no active workflow found.", file=sys.stderr)
        sys.exit(0)

    # Create the token
    create_token(active_name)
    print(f"Override token created for workflow: {active_name}")

    sys.exit(0)


if __name__ == "__main__":
    main()
