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


def _get_user_message() -> str:
    """Extract user message from hook input."""
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if tool_input:
        try:
            data = json.loads(tool_input)
            return data.get("content", data.get("message", ""))
        except json.JSONDecodeError:
            return tool_input

    try:
        data = json.load(sys.stdin)
        return data.get("content", data.get("message", ""))
    except (json.JSONDecodeError, Exception):
        return ""


def _read_active_workflow() -> tuple[dict | None, Path | None]:
    """Read active workflow. Returns (data, file_path)."""
    link = _project_root() / ".claude" / "workflows" / ".active"
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


def _set_stop_lock(enabled: bool) -> None:
    lock_file = _project_root() / ".claude" / "stop_lock.json"
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    lock_file.write_text(json.dumps({"enabled": enabled}))


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
    message = _get_user_message()
    if not message:
        sys.exit(0)

    wf_data, wf_path = _read_active_workflow()

    # Override token (works even without workflow)
    if _matches(message, OVERRIDE_PHRASES):
        wf_name = wf_data["name"] if wf_data else "__global__"
        _create_override_token(wf_name)
        print(f"Override token created for workflow: {wf_name}", file=sys.stderr)

    # Stop-lock
    if _matches(message, STOP_PHRASES) and not _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(True)
        print("Stop-lock enabled.", file=sys.stderr)
        sys.exit(0)

    if _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(False)

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
