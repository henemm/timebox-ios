#!/usr/bin/env python3
"""
No-Workaround Guard - PreToolUse Hook (Bash)

Blocks Claude from working around hook blockades instead of asking the user.

Detects and blocks:
1. kill/kill -9 on processes that don't belong to this session
2. sleep/while loops waiting for external processes to finish
3. Deleting lock files or hook state files

Exit Codes:
- 0: Allowed
- 2: Blocked (workaround detected)
"""

import json
import os
import re
import sys


def get_my_ppid() -> int:
    """Get the PPID of this hook (= Claude Code CLI PID)."""
    return os.getppid()


def is_kill_command(command: str) -> bool:
    """Detect kill commands targeting arbitrary PIDs."""
    # Match: kill, kill -9, kill -TERM, etc.
    # But allow: killall "Simulator" (our own cleanup)
    if re.search(r'\bkillall\s+"?Simulator"?', command):
        return False
    # Block kill with explicit PIDs (not our own cleanup patterns)
    if re.search(r'\bkill\s+(-\d+\s+)?(\d[\d\s]+)', command):
        return True
    return False


def is_wait_loop(command: str) -> bool:
    """Detect while/until loops waiting for external processes."""
    # Pattern: while ... pgrep/ps ... sleep
    if re.search(r'\bwhile\b.*\b(pgrep|ps\b|xcodebuild).*\bsleep\b', command, re.DOTALL):
        return True
    # Pattern: sleep in a loop waiting for something
    if re.search(r'\buntil\b.*\b(pgrep|ps\b).*\bsleep\b', command, re.DOTALL):
        return True
    # Pattern: long sleep (> 10s) — no reason for Claude to sleep that long
    match = re.search(r'\bsleep\s+(\d+)', command)
    if match and int(match.group(1)) > 10:
        return True
    return False


def is_lock_file_deletion(command: str) -> bool:
    """Detect attempts to delete lock files or hook state files."""
    lock_patterns = [
        r'\brm\b.*test_execution_lock',
        r'\brm\b.*workflow_state',
        r'\brm\b.*\.lock',
        r'\bunlink\b.*lock',
        r'\brm\b.*override_token',
    ]
    for pattern in lock_patterns:
        if re.search(pattern, command):
            return True
    return False


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
        command = data.get("command", "")
    except json.JSONDecodeError:
        sys.exit(0)

    if not command:
        sys.exit(0)

    # Check 1: kill on foreign processes
    if is_kill_command(command):
        print(
            "\nBLOCKED: Du versuchst Prozesse zu killen die dir nicht gehoeren.\n"
            "Wenn ein Hook dich blockiert hat: Henning informieren und WARTEN.\n"
            "Nicht die Prozesse anderer Sessions abschiessen.",
            file=sys.stderr
        )
        sys.exit(2)

    # Check 2: wait loops
    if is_wait_loop(command):
        print(
            "\nBLOCKED: Warte-Schleife erkannt.\n"
            "Wenn ein Hook dich blockiert hat: Henning informieren und WARTEN.\n"
            "Nicht in einer Schleife pollen bis die andere Session fertig ist.",
            file=sys.stderr
        )
        sys.exit(2)

    # Check 3: lock file deletion
    if is_lock_file_deletion(command):
        print(
            "\nBLOCKED: Versuch Lock-Files zu loeschen erkannt.\n"
            "Lock-Files gehoeren dem Hook-System. Nicht manuell loeschen.\n"
            "Henning informieren wenn ein Lock-File Probleme macht.",
            file=sys.stderr
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
