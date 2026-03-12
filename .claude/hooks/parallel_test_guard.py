#!/usr/bin/env python3
"""
Parallel Test Guard

Blocks xcodebuild test runs when OTHER recently active workflows have
unfinished TDD RED tests that pollute the build/test results.

"Recently active" = last_updated within the last 48 hours.
Older workflows are considered paused and ignored.

Checks workflow_state_multi.json for conflicts.

Exit Codes:
- 0: Allowed (no parallel conflicts, or not a test command)
- 2: Blocked (parallel workflows with RED tests detected)
"""

import json
import re
import sys
import os
from datetime import datetime, timedelta
from pathlib import Path


STALE_THRESHOLD_HOURS = 48


def get_project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def is_test_command(command: str) -> bool:
    """Check if this is an xcodebuild test command (not just text containing those words)."""
    # Ignore git commands (commit messages may contain "xcodebuild test")
    stripped = command.strip()
    if stripped.startswith("git "):
        return False
    # Match xcodebuild at start of command or after shell operators
    return bool(re.search(r'(?:^|[;&|]\s*)xcodebuild\s+.*\btest\b', command))


def is_recently_active(wf: dict) -> bool:
    """Check if workflow was updated within the last 48 hours."""
    ts = wf.get("last_updated") or wf.get("created")
    if not ts:
        return False
    try:
        # Handle both ISO format and simple date strings
        updated = datetime.fromisoformat(str(ts))
        return datetime.now() - updated < timedelta(hours=STALE_THRESHOLD_HOURS)
    except (ValueError, TypeError):
        return False


def get_conflicting_workflows() -> list[dict]:
    """Find recently active workflows with unfinished TDD RED tests."""
    state_file = get_project_root() / ".claude" / "workflow_state_multi.json"
    if not state_file.exists():
        return []

    try:
        with open(state_file, "r") as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    workflows = state.get("workflows", {})
    active = state.get("active_workflow", "")

    conflicts = []
    for name, wf in workflows.items():
        if name == active:
            continue

        # Skip completed workflows
        phase = wf.get("current_phase", wf.get("phase", ""))
        if phase == "phase8_complete":
            continue

        # Skip stale/paused workflows (not touched in 48h)
        if not is_recently_active(wf):
            continue

        # Has RED tests that haven't been implemented yet?
        has_red = wf.get("red_test_done", False)
        if not has_red:
            continue

        # Check for test artifacts (actual test files exist)
        artifacts = wf.get("test_artifacts", [])
        if not artifacts:
            continue

        conflicts.append({
            "name": name,
            "phase": phase,
            "description": wf.get("description", ""),
            "red_result": wf.get("red_test_result", ""),
        })

    return conflicts


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

    if not command or not is_test_command(command):
        sys.exit(0)

    conflicts = get_conflicting_workflows()
    if not conflicts:
        sys.exit(0)

    # BLOCK
    lines = [
        "",
        "BLOCKED: Parallele Workflows mit unfertigen RED-Tests erkannt!",
        "",
        f"{len(conflicts)} andere Workflow(s) haben TDD-RED-Tests die den Build/Test stoeren:",
        "",
    ]

    for c in conflicts[:5]:  # Max 5 anzeigen
        lines.append(f"  - {c['name']}: {c['description']}")
        lines.append(f"    Phase: {c['phase']}, RED: {c['red_result'][:60]}")
        lines.append("")

    lines.extend([
        "Optionen:",
        "  1. Nur EIGENE Tests isoliert ausfuehren (-only-testing:...)",
        "  2. Henning informieren und auf parallelen Workflow warten",
        "",
    ])

    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
