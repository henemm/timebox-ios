#!/usr/bin/env python3
"""
Build Lock Release - PostToolUse Hook (Bash)

Releases the build lock after an xcodebuild command finishes.
Only releases if the lock belongs to this session (same PPID).

Always exits 0 — PostToolUse hooks must never block.
"""

import json
import os
import sys
from pathlib import Path

LOCK_FILE = Path(__file__).parent.parent / "build_lock.json"


def is_xcodebuild_command(command: str) -> bool:
    """Check if this Bash command invokes xcodebuild."""
    stripped = command.strip()
    if stripped.startswith("git "):
        return False
    return "xcodebuild" in stripped


def main():
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        sys.exit(0)

    command = data.get("command", "")
    if not command or not is_xcodebuild_command(command):
        sys.exit(0)

    # Release lock if we hold it
    if not LOCK_FILE.exists():
        sys.exit(0)

    try:
        lock_data = json.loads(LOCK_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        LOCK_FILE.unlink(missing_ok=True)
        sys.exit(0)

    if lock_data.get("ppid") == os.getppid():
        LOCK_FILE.unlink(missing_ok=True)

    sys.exit(0)


if __name__ == "__main__":
    main()
