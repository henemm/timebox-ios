#!/usr/bin/env python3
"""
hook_utils — Shared utilities for Claude Code hooks.

Extracted from edit_gate.py, post_bash.py, phase_listener.py to eliminate
code duplication (Infra #274).

Public API:
- read_active_workflow(session_id) -> dict | None
- read_active_workflow_with_path(session_id) -> tuple[dict | None, Path | None]

Internal helpers:
- _project_root() -> Path
- _read_workflow_locked(path) -> dict | None
"""

import fcntl
import json
import os
from pathlib import Path


def _project_root() -> Path:
    """Find project root by walking up to the nearest .git directory."""
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _read_workflow_locked(path: Path) -> dict | None:
    """Read a workflow JSON file with a shared (read) lock to prevent torn reads."""
    try:
        fd = os.open(str(path), os.O_RDONLY)
        try:
            fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
            content = path.read_text()
            return json.loads(content) if content.strip() else None
        except BlockingIOError:
            # Lock held exclusively — read without lock (best effort)
            return json.loads(path.read_text())
        finally:
            try:
                fcntl.flock(fd, fcntl.LOCK_UN)
            except OSError:
                pass
            os.close(fd)
    except (OSError, json.JSONDecodeError):
        return None


def read_active_workflow_with_path(session_id: str = "") -> tuple[dict | None, Path | None]:
    """Read active workflow for session. Returns (data, file_path).

    Used by phase_listener which needs the path to save updates.

    Args:
        session_id: Claude session ID. Falls back to CLAUDE_SESSION_ID env var.
    """
    wf_dir = _project_root() / ".claude" / "workflows"

    sid = session_id or os.environ.get("CLAUDE_SESSION_ID", "")
    if sid:
        sessions_file = wf_dir / ".sessions.json"
        if sessions_file.exists():
            try:
                sessions = json.loads(sessions_file.read_text())
                wf_name = sessions.get(sid)
                if wf_name:
                    wf_path = wf_dir / f"{wf_name}.json"
                    if wf_path.exists():
                        return _read_workflow_locked(wf_path), wf_path
            except (OSError, json.JSONDecodeError):
                pass

    # Fallback: .active symlink
    link = wf_dir / ".active"
    if not link.exists():
        return None, None
    try:
        target = Path(os.readlink(str(link)))
        if not target.is_absolute():
            target = link.parent / target
        if target.exists():
            return _read_workflow_locked(target), target
    except (OSError, json.JSONDecodeError):
        pass
    return None, None


def read_active_workflow(session_id: str = "") -> dict | None:
    """Read active workflow for session. Returns workflow dict or None.

    Convenience wrapper around read_active_workflow_with_path for hooks
    that don't need the file path (edit_gate, post_bash).

    Args:
        session_id: Claude session ID. Falls back to CLAUDE_SESSION_ID env var.
    """
    data, _ = read_active_workflow_with_path(session_id)
    return data
