#!/usr/bin/env python3
"""
Adversary Verdict Guard — Blocks direct manipulation of adversary_verdict.

Prevents Claude from bypassing the adversary gate by:
1. Blocking `set-field adversary_verdict` commands
2. Blocking direct writes to workflow_state.json that contain adversary_verdict
3. Blocking python/sed/jq commands that modify the verdict

The ONLY allowed way to set adversary_verdict is via adversary_gate.py
which requires real test output as proof.
"""

import json
import os
import re
import sys


def get_tool_input() -> dict:
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass
    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except Exception:
        return {}


def main():
    tool_input = get_tool_input()
    command = tool_input.get("command", "")

    if not command:
        sys.exit(0)

    # Patterns that indicate adversary_verdict manipulation
    blocked_patterns = [
        r"adversary_verdict",
        r"adversary_details",
    ]

    # Allowed: running adversary_gate.py itself
    if "adversary_gate.py" in command:
        sys.exit(0)

    # Allowed: just checking/reading the verdict (grep, cat, python -c with only reads)
    read_only_patterns = [
        r"^(grep|rg|cat|head|tail|less|more)\s",
        r"adversary_gate\.py\s+--check",
        r"\.get\(['\"]adversary_verdict",  # Python dict reads
    ]
    for pattern in read_only_patterns:
        if re.search(pattern, command):
            sys.exit(0)

    # Check if command manipulates adversary_verdict
    for pattern in blocked_patterns:
        if re.search(pattern, command, re.IGNORECASE):
            # Is it a write/modification command?
            write_indicators = [
                "set-field",
                "json.dump",
                "json.dumps",
                "save_state",
                r">\s",  # redirect
                "echo.*>",
                "sed ",
                "awk ",
                "jq ",
                "python3 -c",
                "python -c",
                "write(",
                "open(",
            ]
            for indicator in write_indicators:
                if re.search(indicator, command, re.IGNORECASE):
                    print("=" * 70, file=sys.stderr)
                    print("BLOCKED — Adversary Verdict Protection", file=sys.stderr)
                    print("=" * 70, file=sys.stderr)
                    print(file=sys.stderr)
                    print("You cannot directly set adversary_verdict.", file=sys.stderr)
                    print(file=sys.stderr)
                    print("The ONLY way to set it is via adversary_gate.py", file=sys.stderr)
                    print("which requires REAL test output as proof:", file=sys.stderr)
                    print(file=sys.stderr)
                    print("  python3 .claude/hooks/adversary_gate.py <test-output-file>", file=sys.stderr)
                    print(file=sys.stderr)
                    print("Run the implementation-validator agent, let it run tests,", file=sys.stderr)
                    print("capture the output, then feed it to adversary_gate.py.", file=sys.stderr)
                    print("=" * 70, file=sys.stderr)
                    sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
