#!/usr/bin/env python3
"""
Test Lock Guard - PreToolUse Hook (Bash)

Verhindert parallele xcodebuild test Laeufe.
Wenn bereits ein xcodebuild test/build-for-testing laeuft,
wird der neue Versuch blockiert.

Kein Lock-File noetig — prueft laufende Prozesse via pgrep.

Exit Codes:
- 0: Allowed (kein anderer Test laeuft)
- 2: Blocked (anderer Test laeuft bereits)
"""

import json
import os
import subprocess
import sys


def is_xcodebuild_test_command(command: str) -> bool:
    """Prueft ob der Bash-Befehl ein xcodebuild test ist."""
    cmd = command.strip()
    if "xcodebuild" not in cmd:
        return False
    # Muss "test" oder "build-for-testing" als Argument enthalten
    return " test " in f" {cmd} " or " test\n" in cmd or cmd.endswith(" test") or "build-for-testing" in cmd


def find_running_xcodebuild_tests() -> list[dict]:
    """Findet laufende xcodebuild test Prozesse."""
    try:
        result = subprocess.run(
            ["pgrep", "-fl", "xcodebuild"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode != 0:
            return []

        running = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(" ", 1)
            if len(parts) < 2:
                continue
            pid = parts[0]
            cmdline = parts[1]
            if "test" in cmdline or "build-for-testing" in cmdline:
                running.append({"pid": pid, "command": cmdline[:100]})
        return running
    except (subprocess.TimeoutExpired, Exception):
        return []


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
    if not command:
        sys.exit(0)

    # Nur xcodebuild test Befehle pruefen
    if not is_xcodebuild_test_command(command):
        sys.exit(0)

    # Pruefen ob bereits ein xcodebuild test laeuft
    running = find_running_xcodebuild_tests()
    if running:
        pids = ", ".join(r["pid"] for r in running)
        print(
            f"BLOCKED: Ein anderer xcodebuild test laeuft bereits (PID: {pids}).\n"
            f"Parallele Test-Laeufe blockieren sich gegenseitig (Simulator-Lock).\n"
            f"Warte bis der laufende Test fertig ist, dann erneut versuchen.",
            file=sys.stderr,
        )
        sys.exit(2)

    # Kein anderer Test laeuft — erlauben
    sys.exit(0)


if __name__ == "__main__":
    main()
