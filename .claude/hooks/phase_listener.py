#!/usr/bin/env python3
"""
Phase Listener v3 — Consolidated UserPromptSubmit Hook

Replaces 6 separate hooks with 1. Listens for keywords in user messages:

- "approved"/"freigabe"/"lgtm" → spec_approved = true
- "stop"/"stopp" → stop-lock enable
- "weiter"/"continue" → stop-lock disable
- "override"/"ich genehmige" → override token
- "neues ui" → is_new_ui = true
- "go"/"green ok"/"tests ok" → green_approved = true

Exit Codes: 0 always (never blocks, only updates state)
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


def _project_root() -> Path:
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _get_hook_input() -> dict:
    """Read full hook input from stdin. Returns parsed dict."""
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if tool_input:
        try:
            return json.loads(tool_input)
        except json.JSONDecodeError:
            return {"content": tool_input}

    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, Exception):
        return {}


def _get_user_message(hook_input: dict) -> str:
    """Extract user message from hook input."""
    return hook_input.get("prompt", hook_input.get("content", hook_input.get("message", "")))


def _get_session_id(hook_input: dict) -> str:
    """Extract session_id from hook input."""
    return hook_input.get("session_id", "")


def _read_active_workflow(session_id: str = "") -> tuple[dict | None, Path | None]:
    """Read active workflow for session. Returns (data, file_path).

    Priority:
    1. Session mapping (.sessions.json) if session_id is provided
    2. Fallback to .active symlink
    """
    wf_dir = _project_root() / ".claude" / "workflows"

    # Try session mapping first
    if session_id:
        sessions_file = wf_dir / ".sessions.json"
        if sessions_file.exists():
            try:
                sessions = json.loads(sessions_file.read_text())
                wf_name = sessions.get(session_id)
                if wf_name:
                    wf_path = wf_dir / f"{wf_name}.json"
                    if wf_path.exists():
                        return json.loads(wf_path.read_text()), wf_path
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
            return json.loads(target.read_text()), target
    except (OSError, json.JSONDecodeError):
        pass
    return None, None


def _save_workflow(data: dict, path: Path) -> None:
    data["last_updated"] = datetime.now().isoformat()
    path.write_text(json.dumps(data, indent=2))


def _create_override_token(workflow_name: str) -> None:
    token_file = _project_root() / ".claude" / "user_override_token.json"
    tokens = {}
    if token_file.exists():
        try:
            raw = json.loads(token_file.read_text())
            tokens = raw.get("tokens", {}) if raw.get("version") == 2 else {}
        except (json.JSONDecodeError, OSError):
            pass
    tokens[workflow_name] = {
        "created": datetime.now().isoformat(),
        "granted_by": "user_prompt",
    }
    token_file.parent.mkdir(parents=True, exist_ok=True)
    token_file.write_text(json.dumps({"version": 2, "tokens": tokens}, indent=2))


def _set_stop_lock(enabled: bool, session_id: str = "") -> None:
    lock_file = _project_root() / ".claude" / "stop_lock.json"
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    if enabled:
        # Read existing locks, add this session
        existing = {}
        if lock_file.exists():
            try:
                existing = json.loads(lock_file.read_text())
            except (json.JSONDecodeError, OSError):
                pass
        sessions = existing.get("sessions", {})
        key = session_id or "__global__"
        sessions[key] = {"created": datetime.now().isoformat()}
        lock_file.write_text(json.dumps({"version": 2, "sessions": sessions}, indent=2))
    else:
        # Remove this session's lock (or clear all if no session)
        if lock_file.exists():
            try:
                existing = json.loads(lock_file.read_text())
            except (json.JSONDecodeError, OSError):
                existing = {}
            if existing.get("version") == 2:
                sessions = existing.get("sessions", {})
                key = session_id or "__global__"
                sessions.pop(key, None)
                if sessions:
                    lock_file.write_text(json.dumps({"version": 2, "sessions": sessions}, indent=2))
                else:
                    lock_file.unlink(missing_ok=True)
            else:
                lock_file.unlink(missing_ok=True)


APPROVAL_PHRASES = [
    "approved", "freigabe", "lgtm", "spec ok", "genehmigt",
    "abgenommen", "passt", "sieht gut aus",
]

STOP_PHRASES = ["stop", "stopp", "halt", "anhalten"]
CONTINUE_PHRASES = ["weiter", "continue", "weitermachen", "fortfahren"]
OVERRIDE_PHRASES = ["override", "ich genehmige", "ich genehmige das", "genehmige"]
GREEN_PHRASES = ["go", "green ok", "tests ok", "weiter", "gruen ok"]


def _matches(message: str, phrases: list[str]) -> bool:
    msg = message.lower().strip()
    for phrase in phrases:
        if re.search(r"\b" + re.escape(phrase.lower()) + r"\b", msg):
            return True
    return False


def main():
    hook_input = _get_hook_input()
    message = _get_user_message(hook_input)
    if not message:
        sys.exit(0)

    session_id = _get_session_id(hook_input)
    wf_data, wf_path = _read_active_workflow(session_id)

    # Override token (works even without workflow)
    if _matches(message, OVERRIDE_PHRASES):
        wf_name = wf_data["name"] if wf_data else "__global__"
        _create_override_token(wf_name)
        print(f"Override token created for workflow: {wf_name}", file=sys.stderr)

    # Stop-lock (per-session)
    if _matches(message, STOP_PHRASES) and not _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(True, session_id)
        print("Stop-lock enabled for this session.", file=sys.stderr)
        sys.exit(0)

    if _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(False, session_id)

    if not wf_data or not wf_path:
        sys.exit(0)

    changed = False

    # Approval
    if _matches(message, APPROVAL_PHRASES):
        phase = wf_data.get("current_phase", "")
        if phase in ("phase3_spec",) and not wf_data.get("spec_approved"):
            wf_data["spec_approved"] = True
            wf_data["current_phase"] = "phase4_approved"
            changed = True
            print(f"Spec approved for '{wf_data['name']}'! You may now run /04-tdd-red", file=sys.stderr)

    # New UI flag
    if "neues ui" in message.lower():
        wf_data["is_new_ui"] = True
        changed = True

    # GREEN approval
    if _matches(message, GREEN_PHRASES):
        phase = wf_data.get("current_phase", "")
        if phase in ("phase6_implement", "phase6b_adversary"):
            wf_data["green_approved"] = True
            changed = True
            print("GREEN approved.", file=sys.stderr)

    if changed:
        _save_workflow(wf_data, wf_path)

    sys.exit(0)


if __name__ == "__main__":
    main()
