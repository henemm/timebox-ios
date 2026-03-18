#!/usr/bin/env python3
"""
Build Lock Guard - PreToolUse Hook (Bash)

Mutual exclusion for ALL xcodebuild commands between Claude Code sessions.
Instead of blocking immediately, waits (polls every 5s) until the lock is free.

Lock File: .claude/build_lock.json
{
  "ppid": 12345,
  "created": "2026-03-18T14:30:00.000000",
  "command": "xcodebuild build -project FocusBlox.xcodeproj ..."
}

Stale lock detection:
- PPID alive AND xcodebuild process running -> real lock, wait
- PPID alive but no xcodebuild running -> stale, clean up
- PPID dead -> stale, clean up

Exit Codes:
- 0: Lock acquired, proceed
- 2: Timeout after 240s waiting
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

LOCK_FILE = Path(__file__).parent.parent / "build_lock.json"
POLL_INTERVAL = 5  # seconds
MAX_WAIT = 240  # seconds


def is_xcodebuild_command(command: str) -> bool:
    """Check if this Bash command invokes xcodebuild."""
    stripped = command.strip()
    if stripped.startswith("git "):
        return False
    return "xcodebuild" in stripped


def is_process_alive(pid: int) -> bool:
    """Check if a process with given PID is still running."""
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def find_running_xcodebuild() -> list[dict]:
    """Find any running xcodebuild processes via pgrep."""
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
            running.append({"pid": parts[0], "command": parts[1][:100]})
        return running
    except (subprocess.TimeoutExpired, Exception):
        return []


def read_lock() -> dict | None:
    """Read and parse the lock file. Returns None if no valid lock."""
    if not LOCK_FILE.exists():
        return None
    try:
        return json.loads(LOCK_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        LOCK_FILE.unlink(missing_ok=True)
        return None


def write_lock(command: str) -> None:
    """Write the lock file for this session."""
    lock_data = {
        "ppid": os.getppid(),
        "created": datetime.now().isoformat(),
        "command": command[:200],
    }
    try:
        LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
        LOCK_FILE.write_text(json.dumps(lock_data, indent=2))
    except OSError:
        pass


def is_lock_stale(lock_data: dict) -> bool:
    """Check if the lock is stale (holder dead or no xcodebuild running)."""
    lock_ppid = lock_data.get("ppid", 0)

    # PPID dead -> stale
    if not is_process_alive(lock_ppid):
        return True

    # PPID alive but no xcodebuild running -> stale
    running = find_running_xcodebuild()
    if not running:
        return True

    return False


def try_acquire(command: str) -> bool:
    """
    Try to acquire the build lock.
    Returns True if acquired, False if blocked by another session.
    """
    my_ppid = os.getppid()
    lock_data = read_lock()

    # No lock -> acquire
    if lock_data is None:
        write_lock(command)
        return True

    # Lock from same session -> allow (re-entrant)
    if lock_data.get("ppid") == my_ppid:
        return True

    # Lock from another session -> check staleness
    if is_lock_stale(lock_data):
        LOCK_FILE.unlink(missing_ok=True)
        write_lock(command)
        return True

    # Lock is active and held by another session
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
    except json.JSONDecodeError:
        sys.exit(0)

    command = data.get("command", "")
    if not command or not is_xcodebuild_command(command):
        sys.exit(0)

    # Try immediate acquire
    if try_acquire(command):
        sys.exit(0)

    # Lock held by another session -> poll until free
    lock_data = read_lock()
    holder_ppid = lock_data.get("ppid", "?") if lock_data else "?"
    holder_cmd = lock_data.get("command", "?")[:80] if lock_data else "?"
    print(
        f"Build-Lock: Andere Session (PID {holder_ppid}) baut gerade.\n"
        f"  Befehl: {holder_cmd}\n"
        f"  Warte bis frei (max {MAX_WAIT}s, Poll alle {POLL_INTERVAL}s)...",
        file=sys.stderr,
    )

    waited = 0
    while waited < MAX_WAIT:
        time.sleep(POLL_INTERVAL)
        waited += POLL_INTERVAL

        if try_acquire(command):
            print(
                f"Build-Lock: Frei nach {waited}s Wartezeit. Fahre fort.",
                file=sys.stderr,
            )
            sys.exit(0)

        if waited % 30 == 0:
            lock_data = read_lock()
            holder_ppid = lock_data.get("ppid", "?") if lock_data else "?"
            print(
                f"Build-Lock: Warte weiter... ({waited}s/{MAX_WAIT}s, Holder PID {holder_ppid})",
                file=sys.stderr,
            )

    # Timeout
    print(
        f"\nBLOCKED: Build-Lock Timeout nach {MAX_WAIT}s.\n"
        f"Andere Session haelt den Lock immer noch.\n"
        f"Bitte pruefen ob die andere Session noch aktiv ist.",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
