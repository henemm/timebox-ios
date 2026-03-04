#!/usr/bin/env python3
"""
Stop-Lock Listener - UserPromptSubmit Hook

Listens for stop/resume keywords in user messages.
Creates or removes the stop-lock file accordingly.

Stop keywords: "stop", "stopp", "halt", "anhalten"
Resume keywords: "resume", "weiter", "weitermachen"

This is the ONLY way to create/remove the stop-lock.
Claude CANNOT manipulate this file (blocked by stop_lock_guard.py).

Exit Codes:
- 0: Always (this hook never blocks, only manages lock file)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

LOCK_FILE = Path(__file__).parent.parent / "stop_lock.json"

# Keywords that activate the stop-lock
STOP_KEYWORDS = [
    "stop",
    "stopp",
    "halt",
    "anhalten",
]

# Keywords that deactivate the stop-lock
RESUME_KEYWORDS = [
    "resume",
    "weiter",
    "weitermachen",
]


def is_stop_message(message: str) -> bool:
    """Check if message contains a stop keyword."""
    message_lower = message.lower().strip()
    for keyword in STOP_KEYWORDS:
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, message_lower):
            return True
    return False


def is_resume_message(message: str) -> bool:
    """Check if message contains a resume keyword."""
    message_lower = message.lower().strip()
    for keyword in RESUME_KEYWORDS:
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, message_lower):
            return True
    return False


def create_lock() -> None:
    """Create the stop-lock file."""
    lock = {
        "enabled": True,
        "created": datetime.now().isoformat(),
        "reason": "User requested stop",
    }
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOCK_FILE, "w") as f:
        json.dump(lock, f, indent=2)


def remove_lock() -> None:
    """Remove the stop-lock file."""
    if LOCK_FILE.exists():
        LOCK_FILE.unlink()


def main():
    # Get user input from stdin
    try:
        data = json.load(sys.stdin)
        user_message = data.get("user_prompt", data.get("prompt", ""))
    except (json.JSONDecodeError, Exception):
        user_message = os.environ.get("CLAUDE_USER_PROMPT", "")

    if not user_message:
        sys.exit(0)

    # Check resume FIRST (so "weiter" can unlock even if "stop" also matched)
    if is_resume_message(user_message):
        remove_lock()
        print("Stop-Lock aufgehoben. Claude darf wieder arbeiten.")
        sys.exit(0)

    # Then check stop
    if is_stop_message(user_message):
        create_lock()
        print("STOP-LOCK AKTIVIERT. Alle Claude-Operationen gesperrt bis 'weiter'.")
        sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
