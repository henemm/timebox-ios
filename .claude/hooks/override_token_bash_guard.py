#!/usr/bin/env python3
"""
Override Token Bash Guard - PreToolUse Bash Hook

Blocks Claude from creating the override token file via Bash commands.
Simple string check - blocks any command referencing the token file.

Exit Codes:
- 0: Allowed (command doesn't reference token file)
- 2: Blocked (command references token file)
"""

import json
import os
import sys


def main():
    # Get tool input
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            sys.exit(0)

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
        command = data.get("command", "")
    except json.JSONDecodeError:
        command = ""

    if not command:
        sys.exit(0)

    # Block any Bash command that references the override token file
    if "user_override_token" in command:
        print(
            "BLOCKED: Override token kann nur vom User gesetzt werden.\n"
            "Tippe 'override' im Chat um den Override zu genehmigen.",
            file=sys.stderr
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
