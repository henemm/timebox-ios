#!/usr/bin/env python3
from __future__ import annotations
"""
Workflow State Cleanup

Runs on UserPromptSubmit. Removes stale entries from workflow_state_multi.json:
- Completed workflows (phase8_complete) → sofort entfernen
- Workflows ohne Aktivitaet seit 7+ Tagen → entfernen

Runs at most once per hour (checks file mtime to avoid unnecessary writes).

Exit Codes:
- 0: Always (never blocks)
"""

import json
import sys
import os
from datetime import datetime, timedelta
from pathlib import Path

# Import session helpers
try:
    from workflow_state_multi import session_active_name, _tty_id
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import session_active_name, _tty_id
    except ImportError:
        def session_active_name(state):
            return state.get("active_workflow")
        def _tty_id():
            return "unknown"

STALE_DAYS = 7
CLEANUP_INTERVAL_HOURS = 1
CLEANUP_MARKER = ".claude/workflow_last_cleanup.json"


def get_project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def should_run_cleanup() -> bool:
    """Only run cleanup once per hour."""
    marker = get_project_root() / CLEANUP_MARKER
    if not marker.exists():
        return True
    try:
        mtime = datetime.fromtimestamp(marker.stat().st_mtime)
        return datetime.now() - mtime > timedelta(hours=CLEANUP_INTERVAL_HOURS)
    except OSError:
        return True


def mark_cleanup_done():
    marker = get_project_root() / CLEANUP_MARKER
    marker.parent.mkdir(parents=True, exist_ok=True)
    with open(marker, "w") as f:
        json.dump({"last_cleanup": datetime.now().isoformat()}, f)


def get_workflow_age(wf: dict) -> timedelta | None:
    """Get age of workflow based on last_updated or created."""
    ts = wf.get("last_updated") or wf.get("created")
    if not ts:
        return None
    try:
        return datetime.now() - datetime.fromisoformat(str(ts))
    except (ValueError, TypeError):
        return None


def main():
    if not should_run_cleanup():
        sys.exit(0)

    state_file = get_project_root() / ".claude" / "workflow_state_multi.json"
    if not state_file.exists():
        sys.exit(0)

    try:
        with open(state_file, "r") as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError):
        sys.exit(0)

    workflows = state.get("workflows", {})
    active = state.get("active_workflow", "")

    # Collect all session-active workflow names (protect from cleanup)
    session_active = set()
    if active:
        session_active.add(active)
    for sid, entry in state.get("session_workflows", {}).items():
        wf_name = entry.get("workflow")
        if wf_name:
            session_active.add(wf_name)

    # Clean stale session entries (TTY no longer exists)
    sessions = state.get("session_workflows", {})
    stale_sessions = [
        sid for sid, entry in sessions.items()
        if not Path(entry.get("tty", "")).exists()
        and entry.get("tty", "") != "unknown"
    ]
    for sid in stale_sessions:
        del sessions[sid]

    removed = []
    kept = {}

    for name, wf in workflows.items():
        # Never remove session-active workflows
        if name in session_active:
            kept[name] = wf
            continue

        phase = wf.get("current_phase", wf.get("phase", ""))

        # Remove completed workflows
        if phase == "phase8_complete":
            removed.append(f"{name} (completed)")
            continue

        # Remove stale workflows (no activity in 7+ days)
        age = get_workflow_age(wf)
        if age and age > timedelta(days=STALE_DAYS):
            removed.append(f"{name} (stale: {age.days}d)")
            continue

        # Workflows without any timestamp and not active → stale
        if age is None and name != active:
            removed.append(f"{name} (no timestamp)")
            continue

        kept[name] = wf

    if removed:
        state["workflows"] = kept
        with open(state_file, "w") as f:
            json.dump(state, f, indent=2)
        print(f"Workflow cleanup: {len(removed)} stale entries entfernt: {', '.join(removed[:5])}")
        if len(removed) > 5:
            print(f"  ... und {len(removed) - 5} weitere")

    mark_cleanup_done()
    sys.exit(0)


if __name__ == "__main__":
    main()
