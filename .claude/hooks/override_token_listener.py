#!/usr/bin/env python3
from __future__ import annotations
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
    from workflow_state_multi import load_state, session_active_name
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from workflow_state_multi import load_state, session_active_name


# Keywords that trigger override token creation
OVERRIDE_KEYWORDS = [
    "override",
    "override genehmigt",
    "ich genehmige",
    "ich genehmige das",
]

TOKEN_FILE = Path(__file__).parent.parent / "user_override_token.json"


def is_override_message(message: str) -> tuple[bool, str | None]:
    """Check if message contains an override keyword.

    Returns (is_override, explicit_workflow_name_or_None).
    Supports "override <workflow-name>" for explicit targeting.
    """
    message_lower = message.lower().strip()

    # Check for "override <workflow-name>" pattern first
    explicit_match = re.match(r'^override\s+([\w-]+)$', message_lower)
    if explicit_match:
        return True, explicit_match.group(1)

    for keyword in OVERRIDE_KEYWORDS:
        # Word boundary match to avoid false positives
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, message_lower):
            return True, None

    return False, None


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
    is_override, explicit_name = is_override_message(user_message)
    if not is_override:
        sys.exit(0)

    # Resolve target workflow
    state = load_state()

    if explicit_name:
        # Explicit workflow name provided — validate it exists
        if explicit_name not in state.get("workflows", {}):
            print(f"Override requested for unknown workflow: {explicit_name}", file=sys.stderr)
            sys.exit(0)
        target_name = explicit_name
    else:
        # No explicit name — fall back to active workflow
        target_name = session_active_name(state)
        if not target_name or target_name not in state.get("workflows", {}):
            print("Override requested but no active workflow found.", file=sys.stderr)
            sys.exit(0)

    # Create the token
    create_token(target_name)
    print(f"Override token created for workflow: {target_name}")

    sys.exit(0)


if __name__ == "__main__":
    main()
