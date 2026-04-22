#!/usr/bin/env python3
"""
Phase Listener v5 — 3-Checkpoint System (Workflow v6)

Listens for keywords in user messages and updates workflow state.
This is the ONLY way to unlock checkpoints — Claude cannot set them.

Keywords:
- "stimmt" → checkpoint1_approved (only in phase2_analyse)
- "go" → checkpoint2_approved (only in phase4_tdd_red)
- "commit" → checkpoint3_approved (only in phase6_adversary)
- "approved"/"freigabe"/"lgtm" → spec_approved (only in phase3_spec)
- "stop"/"stopp" → stop-lock enable
- "weiter"/"continue" → stop-lock disable

Exit Codes: 0 always (never blocks, only updates state)
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from hook_utils import _project_root, read_active_workflow_with_path


def _get_hook_input() -> dict:
    """Read full hook input from stdin."""
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


_METADATA_FIELDS = {"session_id", "cwd", "transcript_path", "permission_mode", "hook_event_name"}


def _get_user_message(hook_input: dict) -> str:
    msg = hook_input.get("prompt", hook_input.get("content", hook_input.get("message", "")))
    if not msg:
        # Fallback: Durchsuche alle String-Werte (z.B. AskUserQuestion-Antworten)
        for key, val in hook_input.items():
            if isinstance(val, str) and len(val) > 1 and key not in _METADATA_FIELDS:
                msg = val
                break
    return msg


def _get_session_id(hook_input: dict) -> str:
    return os.environ.get("CLAUDE_SESSION_ID", "") or hook_input.get("session_id", "")


def _read_active_workflow(session_id: str = "") -> tuple[dict | None, Path | None]:
    """Read active workflow for session. Returns (data, file_path)."""
    return read_active_workflow_with_path(session_id)


def _save_workflow(data: dict, path: Path) -> None:
    data["last_updated"] = datetime.now().isoformat()
    path.write_text(json.dumps(data, indent=2))


def _set_stop_lock(enabled: bool, session_id: str = "") -> None:
    lock_file = _project_root() / ".claude" / "stop_lock.json"
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    if enabled:
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


def _resolve_next_finding(wf_data: dict, wf_path: Path, status: str, session_id: str = "") -> bool:
    """Resolve the first unresolved adversary finding. Returns True if resolved."""
    findings = wf_data.get("adversary_findings", [])
    for f in findings:
        if f.get("status") is None:
            # Call workflow.py resolve-finding with WORKFLOW_CALLER=phase_listener
            env = os.environ.copy()
            env["WORKFLOW_CALLER"] = "phase_listener"
            if session_id:
                env["CLAUDE_SESSION_ID"] = session_id
            try:
                result = subprocess.run(
                    ["python3", str(Path(__file__).parent / "workflow.py"),
                     "resolve-finding", str(f["id"]), status],
                    env=env, capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0:
                    print(result.stdout.strip(), file=sys.stderr)
                else:
                    print(result.stderr.strip(), file=sys.stderr)
                return result.returncode == 0
            except Exception as e:
                print(f"Error resolving finding #{f['id']}: {e}", file=sys.stderr)
                return False
    return False


def _call_workflow_checkpoint(checkpoint_num: int, notes: str, session_id: str = "") -> None:
    """Call workflow.py mark-checkpoint{N} with WORKFLOW_CALLER=phase_listener."""
    env = os.environ.copy()
    env["WORKFLOW_CALLER"] = "phase_listener"
    if session_id:
        env["CLAUDE_SESSION_ID"] = session_id
    try:
        result = subprocess.run(
            ["python3", str(_project_root() / ".claude" / "hooks" / "workflow.py"),
             f"mark-checkpoint{checkpoint_num}", notes],
            env=env, capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            print(result.stdout.strip(), file=sys.stderr)
        else:
            print(result.stderr.strip(), file=sys.stderr)
    except Exception as e:
        print(f"Error calling mark-checkpoint{checkpoint_num}: {e}", file=sys.stderr)


# --- Keyword definitions ---

CHECKPOINT1_PHRASES = [
    "stimmt", "ja", "richtig", "korrekt", "genau", "passt",
    "sehr gut", "sieht gut aus", "einverstanden",
]
CHECKPOINT2_PHRASES = [
    "go", "los", "mach", "anfangen", "start",
    "ja", "passt", "sehr gut", "einverstanden",
]
CHECKPOINT3_PHRASES = [
    "commit", "ja", "passt", "sehr gut",
    "einverstanden", "abschicken", "fertig",
]
APPROVAL_PHRASES = [
    "approved", "freigabe", "lgtm", "spec ok", "genehmigt",
    "abgenommen", "passt", "sieht gut aus", "ja", "einverstanden",
]
FINDING_FIX_PHRASES = ["fixen", "fix", "beheben", "reparieren"]
FINDING_ACCEPT_PHRASES = ["akzeptabel", "akzeptieren", "ok so", "passt so"]
FINDING_DEFER_PHRASES = ["zurückstellen", "später", "defer", "ticket"]
STOP_PHRASES = ["stop", "stopp", "halt", "anhalten"]
CONTINUE_PHRASES = ["weiter", "continue", "weitermachen", "fortfahren"]


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

    # Stop-lock (per-session) — works without workflow
    if _matches(message, STOP_PHRASES) and not _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(True, session_id)
        print("Stop-lock enabled for this session.", file=sys.stderr)
        sys.exit(0)

    if _matches(message, CONTINUE_PHRASES):
        _set_stop_lock(False, session_id)

    wf_data, wf_path = _read_active_workflow(session_id)
    if not wf_data or not wf_path:
        sys.exit(0)

    phase = wf_data.get("current_phase", "")
    changed = False

    # Checkpoint 1: "stimmt" — only in phase2_analyse
    if _matches(message, CHECKPOINT1_PHRASES):
        if phase == "phase2_analyse" and not wf_data.get("checkpoint1_approved"):
            _call_workflow_checkpoint(1, f"User approved at {datetime.now().isoformat()}", session_id=session_id)

    # Checkpoint 2: "go" — only in phase4_tdd_red
    if _matches(message, CHECKPOINT2_PHRASES):
        if phase == "phase4_tdd_red" and not wf_data.get("checkpoint2_approved"):
            _call_workflow_checkpoint(2, f"User approved at {datetime.now().isoformat()}", session_id=session_id)

    # Checkpoint 3: "commit" — only in phase6_adversary, AND only if no unresolved findings AND screenshot exists
    if _matches(message, CHECKPOINT3_PHRASES):
        if phase in ("phase6_adversary", "phase5_implement") and not wf_data.get("checkpoint3_approved"):
            findings = wf_data.get("adversary_findings", [])
            has_unresolved = any(f.get("status") is None for f in findings)
            # Gate: Screenshot-Artifact prüfen (außer bei neuem UI oder Non-UI-Bugs)
            has_screenshot = wf_data.get("is_new_ui") or wf_data.get("no_ui_change") or any(
                a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
            if not has_unresolved and has_screenshot:
                _call_workflow_checkpoint(3, f"User approved at {datetime.now().isoformat()}", session_id=session_id)
            elif has_unresolved:
                unresolved_titles = [f["title"] for f in findings if f.get("status") is None]
                print(f"Checkpoint 3 nicht gesetzt: {len(unresolved_titles)} Adversary-Finding(s) noch offen: "
                      f"{', '.join(unresolved_titles[:3])}. "
                      "Jedes Finding muss von Henning beantwortet werden (fixen/akzeptabel/zurückstellen).")
            elif not has_screenshot:
                print("Checkpoint 3 nicht gesetzt: Screenshot fehlt. "
                      "Führe ./scripts/sim.sh screenshot aus und registriere: "
                      "workflow.py add-artifact screenshot <pfad> <beschreibung> phase5_implement")

    # Finding resolution: "fixen"/"akzeptabel"/"zurückstellen" — in phase5_implement or phase6_adversary
    # Supports multiple keywords per message (e.g. "1 fixen, 2 zurückstellen")
    if phase in ("phase6_adversary", "phase5_implement"):
        findings = wf_data.get("adversary_findings", [])
        has_unresolved = any(f.get("status") is None for f in findings)
        if has_unresolved:
            for phrases, status in [
                (FINDING_FIX_PHRASES, "fix"),
                (FINDING_ACCEPT_PHRASES, "accept"),
                (FINDING_DEFER_PHRASES, "defer"),
            ]:
                if _matches(message, phrases):
                    _resolve_next_finding(wf_data, wf_path, status, session_id=session_id)
                    # Re-read workflow for next iteration
                    wf_data, wf_path = _read_active_workflow(session_id)
                    if not wf_data:
                        break

            # Re-check: If last finding was just resolved, auto-set checkpoint 3
            if wf_data and not wf_data.get("checkpoint3_approved"):
                wf_data, wf_path = _read_active_workflow(session_id)
                if wf_data:
                    findings = wf_data.get("adversary_findings", [])
                    has_unresolved = any(f.get("status") is None for f in findings)
                    has_screenshot = wf_data.get("is_new_ui") or wf_data.get("no_ui_change") or any(
                        a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
                    if not has_unresolved and has_screenshot:
                        _call_workflow_checkpoint(3, "Auto-set after last finding resolved", session_id=session_id)
                        print("Checkpoint 3 auto-gesetzt: Alle Findings aufgelöst + Screenshot vorhanden.", file=sys.stderr)

    # Spec approval: "approved" etc. — only in phase3_spec
    if _matches(message, APPROVAL_PHRASES):
        if phase == "phase3_spec" and not wf_data.get("spec_approved"):
            wf_data["spec_approved"] = True
            changed = True
            print(f"Spec approved for '{wf_data['name']}'!", file=sys.stderr)

    if changed:
        _save_workflow(wf_data, wf_path)

    sys.exit(0)


if __name__ == "__main__":
    main()
