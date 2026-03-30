#!/usr/bin/env python3
"""
Post-Bash v3 — PostToolUse Hook for Bash

Releases build lock after xcodebuild commands complete.

Exit Codes: 0 always (never blocks)
"""

import json
import os
import sys
from pathlib import Path


def _project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


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
    if not command or "xcodebuild" not in command:
        sys.exit(0)

    # Release build lock if we hold it
    lock_path = _project_root() / ".claude" / "build_lock.json"
    if lock_path.exists():
        try:
            lock = json.loads(lock_path.read_text())
            if lock.get("ppid") == os.getppid():
                lock_path.unlink()
        except (json.JSONDecodeError, OSError):
            pass

    sys.exit(0)


if __name__ == "__main__":
    main()
