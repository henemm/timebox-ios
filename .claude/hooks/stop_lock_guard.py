#!/usr/bin/env python3
"""
Stop-Lock Guard - PreToolUse Hook (Edit|Write + Bash)

Blocks ALL tool usage when a stop-lock is active.
The stop-lock can ONLY be created/removed by the user via stop_lock_listener.py.

MUST be the FIRST hook in both Edit|Write and Bash chains.

Exit Codes:
- 0: Allowed (no stop-lock active)
- 2: Blocked (stop-lock active, or attempt to manipulate lock file)
"""

import json
import os
import sys
from pathlib import Path

LOCK_FILE = Path(__file__).parent.parent / "stop_lock.json"


def is_stop_locked() -> bool:
    """Check if the stop-lock is active."""
    if not LOCK_FILE.exists():
        return False
    try:
        lock = json.loads(LOCK_FILE.read_text())
        return lock.get("enabled", False)
    except (json.JSONDecodeError, Exception):
        return False


def main():
    # Get tool input from environment or stdin
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    tool_name = os.environ.get("CLAUDE_TOOL", "")

    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
            tool_name = data.get("tool_name", tool_name)
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        data = {}

    # --- Protection: Block manipulation of stop_lock.json ---

    # For Edit/Write: check file_path
    file_path = data.get("file_path", "")
    if file_path and "stop_lock.json" in file_path:
        print(
            "BLOCKED: stop_lock.json kann nur vom User gesteuert werden.\n"
            "Tippe 'stopp' zum Sperren, 'weiter' zum Entsperren.",
            file=sys.stderr,
        )
        sys.exit(2)

    # For Bash: check command (only block stop_lock.json, not stop_lock_guard.py etc.)
    command = data.get("command", "")
    if command and "stop_lock.json" in command:
        print(
            "BLOCKED: stop_lock kann nur vom User gesteuert werden.\n"
            "Tippe 'stopp' zum Sperren, 'weiter' zum Entsperren.",
            file=sys.stderr,
        )
        sys.exit(2)

    # --- Main check: Is the stop-lock active? ---

    if is_stop_locked():
        print(
            "STOP-LOCK AKTIV: Der User hat 'stopp' gesagt.\n"
            "Alle Edit/Write/Bash-Operationen sind gesperrt.\n"
            "Warte auf 'weiter' oder 'resume' vom User.",
            file=sys.stderr,
        )
        sys.exit(2)

    # No lock active, allow
    sys.exit(0)


if __name__ == "__main__":
    main()
