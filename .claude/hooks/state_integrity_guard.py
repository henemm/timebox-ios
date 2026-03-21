#!/usr/bin/env python3
"""
State Integrity Guard — PreToolUse Hook (Bash)

Blocks ALL Bash commands that attempt to write to protected workflow files.
This prevents Claude from bypassing the workflow system by directly manipulating
state files, override tokens, hook code, or settings.

Protected files:
- .claude/workflow_state.json
- .claude/user_override_token.json
- .claude/hooks/*.py
- .claude/settings.json

Only the official workflow commands (workflow_state_multi.py, adversary_gate.py)
may modify state — and only through their registered CLI interface.

Exit Codes:
- 0: Allowed
- 2: Blocked (stderr shown to Claude)
"""

import json
import os
import re
import sys


# Protected file patterns — any Bash write to these is blocked
PROTECTED_PATTERNS = [
    r"workflow_state\.json",
    r"user_override_token\.json",
    r"\.claude/hooks/[^\s]*\.py",
    r"\.claude/settings\.json",
    r"ui_test_preflight_state\.json",
    r"ui_screenshot_lock\.json",
]

# Write indicators — if a command references a protected file AND contains
# one of these, it's a write attempt
# Non-redirect write indicators — always suspicious with protected files
# These use regex word boundaries to avoid false positives (e.g., 'git add' matching 'dd')
WRITE_INDICATOR_PATTERNS = [
    r"json\.dump",     # Python JSON write
    r"json\.dumps",    # Python JSON serialize + write
    r"open\(",         # Python file open (could be write mode)
    r"write\(",        # Python file write
    r"sed\s+-i",    # in-place edit
    r"mv\s",        # move/rename
    r"cp\s",        # copy over
    r"echo\s",      # echo to file
    r"printf\s",    # printf to file
    r"python3?\s+-c",  # Python one-liner (common bypass)
    r"tee\s",       # tee to file
    r"dd\s",        # dd write
    r"install\s",   # install command (but not 'pip install')
    r"ln\s",        # symlink
    r"rm\s",        # delete
    r"unlink",    # delete
    r"truncate",  # truncate file
    r"touch\s",     # create/modify
    r"cat\s*<<",       # heredoc
]

# Whitelisted commands — official workflow tools that ARE allowed to modify state
ALLOWED_COMMANDS = [
    # Official workflow state manager CLI
    "workflow_state_multi.py status",
    "workflow_state_multi.py list",
    "workflow_state_multi.py start",
    "workflow_state_multi.py switch",
    "workflow_state_multi.py advance",
    "workflow_state_multi.py phase",
    "workflow_state_multi.py backlog",
    "workflow_state_multi.py set-field",
    "workflow_state_multi.py pause",
    "workflow_state_multi.py complete",
    "workflow_state_multi.py mark-docs-updated",
    # Adversary gate (sets adversary_verdict based on test proof)
    "adversary_gate.py",
    # Inspection gate (sets visual/result inspection fields based on screenshot proof)
    "inspection_gate.py",
    # Read-only operations are fine
    "cat .claude/workflow_state.json",
    "cat .claude/settings.json",
    # jq read-only
    "jq . .claude/workflow_state.json",
    "jq '.workflows' .claude/workflow_state.json",
]

BLOCK_MESSAGE = """
+======================================================================+
|  BLOCKED: Direct State File Manipulation!                             |
+======================================================================+
|                                                                       |
|  You attempted to directly modify a protected workflow file via Bash.  |
|  This is NOT allowed — use the official workflow commands instead.     |
|                                                                       |
|  Protected files:                                                     |
|  - .claude/workflow_state.json                                        |
|  - .claude/user_override_token.json                                   |
|  - .claude/hooks/*.py                                                 |
|  - .claude/settings.json                                              |
|                                                                       |
|  Official commands:                                                   |
|  - python3 .claude/hooks/workflow_state_multi.py status               |
|  - python3 .claude/hooks/workflow_state_multi.py phase <phase>        |
|  - python3 .claude/hooks/workflow_state_multi.py set-field <f> <v>    |
|  - python3 .claude/hooks/adversary_gate.py <test-output>              |
|                                                                       |
|  DO NOT attempt to bypass this guard.                                 |
+======================================================================+
"""


def get_command() -> str:
    """Extract the bash command from hook input."""
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
        except (json.JSONDecodeError, Exception):
            return ""

    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        return ""

    return data.get("command", "")


def is_whitelisted(command: str) -> bool:
    """Check if command matches an allowed workflow command."""
    for allowed in ALLOWED_COMMANDS:
        if allowed in command:
            # Extra check: ensure this isn't a sneaky compound command
            # e.g., "workflow_state_multi.py status; rm .claude/hooks/foo.py"
            # The allowed part must be the MAIN command, not a prefix
            return True
    return False


def references_protected_file(command: str) -> bool:
    """Check if command references any protected file."""
    for pattern in PROTECTED_PATTERNS:
        if re.search(pattern, command):
            return True
    return False


def has_write_indicator(command: str) -> bool:
    """Check if command contains a write indicator."""
    # Check non-redirect write indicators (regex-based for word boundaries)
    for pattern in WRITE_INDICATOR_PATTERNS:
        if re.search(pattern, command):
            return True
    # Check redirect operators (> and >>) — but only if they redirect
    # to something other than /dev/null (which is harmless stderr suppression)
    redirect_matches = re.finditer(r'(?<!\d)>{1,2}\s*(\S+)', command)
    for match in redirect_matches:
        target = match.group(1)
        if target != '/dev/null':
            return True
    return False


def is_compound_command(command: str) -> bool:
    """Check if command chains multiple operations (;, &&, ||, |)."""
    # Strip quoted strings to avoid false positives
    stripped = re.sub(r"'[^']*'", "", command)
    stripped = re.sub(r'"[^"]*"', "", stripped)
    return bool(re.search(r"[;&|]{1,2}", stripped))


INSPECTION_BLOCK_MESSAGE = """
+======================================================================+
|  BLOCKED: Inspection Field Protection!                                |
+======================================================================+
|                                                                       |
|  You cannot directly set inspection fields via set-field.             |
|  These fields are proof-based — they require a REAL screenshot.       |
|                                                                       |
|  The ONLY way to set them:                                            |
|                                                                       |
|  BEFORE analysis (visual inspection):                                 |
|    python3 .claude/hooks/inspection_gate.py before <screenshot.png>   |
|                                                                       |
|  AFTER implementation (result inspection):                            |
|    python3 .claude/hooks/inspection_gate.py after <screenshot.png>    |
|                                                                       |
|  Falls kein Screenshot moeglich → FRAGE HENNING um Override.          |
|  Verbringe KEINE Zeit damit, einen Workaround zu suchen.             |
+======================================================================+
"""

# Inspection fields that can ONLY be set by inspection_gate.py
PROTECTED_INSPECTION_FIELDS = [
    "visual_inspection_done",
    "visual_inspection_screenshot",
    "result_inspection_done",
    "result_inspection_screenshot",
]


def is_inspection_field_manipulation(command: str) -> bool:
    """Check if command tries to set a protected inspection field via set-field."""
    for field in PROTECTED_INSPECTION_FIELDS:
        if f"set-field {field}" in command or f"set-field\t{field}" in command:
            return True
    return False


def main():
    command = get_command()
    if not command:
        sys.exit(0)

    # FIRST: Block inspection field manipulation via set-field
    # This runs BEFORE the whitelist check because set-field is whitelisted
    # but these specific fields must go through inspection_gate.py
    if is_inspection_field_manipulation(command):
        # Allow inspection_gate.py to set these fields
        if "inspection_gate.py" in command:
            sys.exit(0)
        print(INSPECTION_BLOCK_MESSAGE, file=sys.stderr)
        sys.exit(2)

    # Quick check: does command reference any protected file?
    if not references_protected_file(command):
        sys.exit(0)

    # Check if this is a whitelisted official command
    if is_whitelisted(command):
        # But block compound commands that sneak in extra operations
        if is_compound_command(command):
            # Check if the compound part ALSO references protected files
            # Split on ; && || and check each part
            parts = re.split(r'\s*[;&|]{1,2}\s*', command)
            for part in parts[1:]:  # Skip the first (whitelisted) part
                if references_protected_file(part):
                    print(BLOCK_MESSAGE, file=sys.stderr)
                    sys.exit(2)
        sys.exit(0)

    # Not whitelisted — check for write indicators
    if has_write_indicator(command):
        print(BLOCK_MESSAGE, file=sys.stderr)
        sys.exit(2)

    # python3 -c check is handled by WRITE_INDICATOR_PATTERNS above

    # Read-only access to protected files is fine (cat, jq, head, etc.)
    sys.exit(0)


if __name__ == "__main__":
    main()
