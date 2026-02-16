#!/usr/bin/env python3
"""
Override Token Guard - PreToolUse Edit|Write Hook

Blocks Claude from creating or editing the override token file.
This ensures only the UserPromptSubmit hook (triggered by user input)
can create the token.

MUST be the FIRST hook in the Edit|Write chain (before strict_code_gate).

Exit Codes:
- 0: Allowed (file is not the token file)
- 2: Blocked (attempt to write to token file)
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
        file_path = data.get("file_path", "")
    except json.JSONDecodeError:
        file_path = ""

    if not file_path:
        sys.exit(0)

    # Block any attempt to write to the override token file
    if "user_override_token.json" in file_path:
        print(
            "BLOCKED: Override token kann nur vom User gesetzt werden.\n"
            "Tippe 'override' im Chat um den Override zu genehmigen.",
            file=sys.stderr
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
