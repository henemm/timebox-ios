#!/usr/bin/env python3
"""
SessionStart Hook — Sets CLAUDE_SESSION_ID for the session.

Reads session_id from Claude Code's hook JSON input and writes it
to CLAUDE_ENV_FILE so all subsequent Bash commands in this session
can access it via $CLAUDE_SESSION_ID.
"""

import json
import os
import sys


def main():
    env_file = os.environ.get("CLAUDE_ENV_FILE", "")
    if not env_file:
        sys.exit(0)

    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    session_id = data.get("session_id", "")
    if not session_id:
        sys.exit(0)

    with open(env_file, "a") as f:
        f.write(f'export CLAUDE_SESSION_ID="{session_id}"\n')


if __name__ == "__main__":
    main()
