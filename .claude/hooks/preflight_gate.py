#!/usr/bin/env python3
"""
Preflight Gate — Updates ui_test_preflight_state.json

Called by /inspect-ui after a successful accessibility tree dump.
This is the ONLY approved way to write ui_test_preflight_state.json.

Usage:
    python3 .claude/hooks/preflight_gate.py <screen>

Example:
    python3 .claude/hooks/preflight_gate.py main
    python3 .claude/hooks/preflight_gate.py backlog
    python3 .claude/hooks/preflight_gate.py settings

Exit Codes:
- 0: State written successfully
- 1: Error (missing argument, write failure)
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def get_project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 preflight_gate.py <screen>", file=sys.stderr)
        print("Example: python3 preflight_gate.py main", file=sys.stderr)
        sys.exit(1)

    screen = sys.argv[1]

    state_file = get_project_root() / ".claude" / "ui_test_preflight_state.json"

    state = {
        "last_run": datetime.now().isoformat(),
        "screen": screen,
    }

    try:
        with open(state_file, "w") as f:
            json.dump(state, f, indent=2)
        print(f"Preflight state saved (screen: {screen})")
    except OSError as e:
        print(f"Error writing state file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
