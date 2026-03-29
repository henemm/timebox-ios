#!/usr/bin/env python3
"""
SessionStart hook: Publishes session_id for workflow→session mapping.

Reads session_id from Claude Code's stdin JSON and writes it to a
temp file so that subsequent Bash commands (workflow_state_multi.py CLI)
can identify which session they belong to.

Also creates the session→workflow mapping if an active_workflow exists.

Exit Codes:
- 0: Always (never blocks)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    session_id = data.get("session_id", "")
    if not session_id:
        sys.exit(0)

    # Publish session_id to per-TTY temp file for Bash commands
    try:
        from workflow_state_multi import publish_session_id, load_state, _state_lock, _save_state_unlocked
        publish_session_id(session_id)

        # Only create session→workflow mapping if this session doesn't
        # already have one. Don't blindly map to active_workflow — that
        # could be owned by a different session.
        with _state_lock():
            state = load_state()
            sessions = state.get("session_workflows", {})
            if session_id not in sessions:
                # New session: only map if there's exactly one non-idle
                # workflow (unambiguous) or a global active_workflow with
                # no other session claiming it.
                active = state.get("active_workflow")
                if active and active in state.get("workflows", {}):
                    # Check if another session already owns this workflow
                    already_owned = any(
                        entry.get("workflow") == active
                        for sid, entry in sessions.items()
                        if sid != session_id
                    )
                    if not already_owned:
                        if "session_workflows" not in state:
                            state["session_workflows"] = {}
                        state["session_workflows"][session_id] = {
                            "workflow": active,
                        }
                        _save_state_unlocked(state)
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
