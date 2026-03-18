#!/usr/bin/env python3
"""
Sim Enforcer — PreToolUse Hook (Bash)

Blocks direct xcrun simctl / xcodebuild calls and redirects to ./scripts/sim.sh.
Claude consistently ignores memory entries and hand-crafts broken commands.
This hook enforces usage of the wrapper script.

ALLOW (exit 0):
  - Command contains neither "xcrun simctl" nor "xcodebuild"
  - Command calls a wrapper script (sim.sh, run_resilient_tests.sh, etc.)
  - Read-only commands: xcrun simctl list, xcodebuild -list, xcodebuild -showBuildSettings

BLOCK (exit 2):
  - Direct xcrun simctl action (boot, shutdown, erase, delete, install, launch, io, create)
  - Direct xcodebuild action (build, test, clean)
"""

import json
import os
import re
import sys


# Wrapper scripts that are allowed to call xcrun/xcodebuild internally
ALLOWED_SCRIPTS = [
    "sim.sh",
    "run_resilient_tests.sh",
    "adversary_screenshot.sh",
    "run-mac-ui-tests.sh",
]

# Read-only xcrun simctl subcommands (safe, no side effects)
READONLY_SIMCTL = {"list", "listapps", "getenv", "get_app_container"}

# Read-only xcodebuild flags (safe, no side effects)
READONLY_XCODEBUILD = {"-list", "-showBuildSettings", "-showdestinations", "-version"}

# Blocked xcrun simctl subcommands (mutating)
BLOCKED_SIMCTL = {
    "boot", "shutdown", "erase", "delete", "install", "uninstall",
    "launch", "terminate", "io", "create", "clone", "rename",
    "bootstatus", "openurl", "addmedia", "spawn", "diagnose",
    "privacy", "keychain", "push",
}

BLOCK_MESSAGE = """BLOCKED: Direkter xcodebuild/xcrun-Aufruf verboten.

Verwende stattdessen:
  ./scripts/sim.sh build              (statt xcodebuild build)
  ./scripts/sim.sh test TestClass     (statt xcodebuild test -only-testing:...UITests/...)
  ./scripts/sim.sh unit TestClass     (statt xcodebuild test -only-testing:...Tests/...)
  ./scripts/sim.sh screenshot [path]  (statt xcrun simctl io ... screenshot)
  ./scripts/sim.sh boot               (statt xcrun simctl boot)
  ./scripts/sim.sh launch [--mock]    (statt xcrun simctl install + launch)
  ./scripts/sim.sh status             (statt xcrun simctl list devices)

Doku: MEMORY.md → Simulator-Toolkit"""


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


def uses_wrapper_script(command: str) -> bool:
    """Check if the command invokes one of the allowed wrapper scripts."""
    for script in ALLOWED_SCRIPTS:
        if script in command:
            return True
    return False


def is_readonly_simctl(command: str) -> bool:
    """Check if this is a read-only xcrun simctl command."""
    # Match: xcrun simctl <subcommand>
    match = re.search(r"xcrun\s+simctl\s+(\w+)", command)
    if not match:
        return False
    subcommand = match.group(1)
    return subcommand in READONLY_SIMCTL


def is_readonly_xcodebuild(command: str) -> bool:
    """Check if this is a read-only xcodebuild command (just querying info)."""
    for flag in READONLY_XCODEBUILD:
        if flag in command:
            return True
    return False


def has_blocked_simctl(command: str) -> bool:
    """Check if command contains a blocked xcrun simctl subcommand."""
    match = re.search(r"xcrun\s+simctl\s+(\w+)", command)
    if not match:
        return False
    subcommand = match.group(1)
    return subcommand in BLOCKED_SIMCTL


def has_blocked_xcodebuild(command: str) -> bool:
    """Check if command contains a direct xcodebuild build/test/clean."""
    # Match xcodebuild followed by build, test, or clean (as action)
    if re.search(r"xcodebuild\s+(build|test|clean|archive|analyze)", command):
        return True
    # Also catch xcodebuild with -project/-scheme but no read-only flag
    if "xcodebuild" in command and not is_readonly_xcodebuild(command):
        # Must have an action keyword or test/build destination
        if any(kw in command for kw in ["-destination", "-project", "-scheme", "-workspace"]):
            # But only if it's not just querying
            if not any(flag in command for flag in READONLY_XCODEBUILD):
                return True
    return False


def main():
    command = get_command()
    if not command:
        sys.exit(0)

    # Not relevant — no xcrun simctl or xcodebuild
    has_simctl = "xcrun simctl" in command or "xcrun  simctl" in command
    has_xcodebuild = "xcodebuild" in command
    if not has_simctl and not has_xcodebuild:
        sys.exit(0)

    # Wrapper scripts are always allowed
    if uses_wrapper_script(command):
        sys.exit(0)

    # Read-only commands are allowed
    if has_simctl and is_readonly_simctl(command) and not has_xcodebuild:
        sys.exit(0)
    if has_xcodebuild and is_readonly_xcodebuild(command) and not has_simctl:
        sys.exit(0)

    # Check for blocked patterns
    blocked = False
    if has_simctl and has_blocked_simctl(command):
        blocked = True
    if has_xcodebuild and has_blocked_xcodebuild(command):
        blocked = True

    # Catch-all: if it has xcodebuild/simctl but wasn't explicitly allowed, block
    if not blocked and (has_simctl or has_xcodebuild):
        blocked = True

    if blocked:
        print(BLOCK_MESSAGE, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
