#!/usr/bin/env python3
"""
Workflow v5 — 3-Checkpoint System

Simplified from v4 (17+ gates) to 3 human checkpoints + deterministic hard gates.
Self-policing removed. Only Henning can unlock checkpoints via phase_listener.py.

Phases (6 instead of 9):
  phase0_idle → phase1_context → phase2_analyse → phase3_spec
  → phase4_tdd_red → phase5_implement → phase6_done

Checkpoints (set ONLY by phase_listener.py, never by Claude):
  checkpoint1_approved — "stimmt" (after analysis, before spec)
  checkpoint2_approved — "go" (after TDD RED, before implementation)
  checkpoint3_approved — "commit" (after implementation, before git commit)

Usage:
    python3 workflow.py start <name>
    python3 workflow.py switch <name>
    python3 workflow.py status
    python3 workflow.py phase <phase>
    python3 workflow.py set-field <key> <value>
    python3 workflow.py set-affected-files [--replace] <f1> <f2> ...
    python3 workflow.py add-artifact <type> <path> <desc> <phase>
    python3 workflow.py mark-red <result>
    python3 workflow.py mark-ui-red <result>
    python3 workflow.py mark-green <result>
    python3 workflow.py mark-ui-green <result>
    python3 workflow.py mark-context <file>
    python3 workflow.py mark-checkpoint1 <notes>
    python3 workflow.py mark-checkpoint2 <notes>
    python3 workflow.py mark-checkpoint3 <notes>
    python3 workflow.py complete
    python3 workflow.py list
    python3 workflow.py snapshot-tests
"""

import fcntl
import json
import os
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path

PHASES = [
    "phase0_idle",
    "phase1_context",
    "phase2_analyse",
    "phase3_spec",
    "phase4_tdd_red",
    "phase5_implement",
    "phase6_done",
]

PHASE_NAMES = {
    "phase0_idle": "Idle",
    "phase1_context": "Context Generation",
    "phase2_analyse": "Analysis",
    "phase3_spec": "Specification & Approval",
    "phase4_tdd_red": "TDD RED - Write Failing Tests",
    "phase5_implement": "Implementation (TDD GREEN)",
    "phase6_done": "Done - Ready to Commit",
}


def _project_root() -> Path:
    """Find project root (dir with .git), or use CLAUDE_PROJECT_DIR env."""
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _workflows_dir() -> Path:
    return _project_root() / ".claude" / "workflows"


def _active_link() -> Path:
    return _workflows_dir() / ".active"


def _workflow_file(name: str) -> Path:
    return _workflows_dir() / f"{name}.json"


def _archive_dir() -> Path:
    return _workflows_dir() / "_archive"


def _atomic_write(path: Path, data: dict) -> None:
    """Write JSON atomically via tempfile + rename."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.rename(tmp, str(path))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read_workflow(path: Path) -> dict:
    """Read workflow JSON file."""
    return json.loads(path.read_text())


def _sessions_file() -> Path:
    return _workflows_dir() / ".sessions.json"


def _get_session_id() -> str:
    """Get current session ID from environment."""
    return os.environ.get("CLAUDE_SESSION_ID", "")


def _read_sessions() -> dict:
    """Read session -> workflow mapping (unlocked, for read-only use)."""
    sf = _sessions_file()
    if sf.exists():
        try:
            return json.loads(sf.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {}


@contextmanager
def _locked_sessions(timeout: float = 5.0):
    """Context manager for atomic Read-Modify-Write on .sessions.json."""
    sf = _sessions_file()
    sf.parent.mkdir(parents=True, exist_ok=True)
    if not sf.exists():
        sf.write_text("{}")
    lock_fd = os.open(str(sf), os.O_RDWR)
    try:
        import signal

        def _timeout_handler(signum, frame):
            raise TimeoutError(f"Could not acquire lock on {sf} within {timeout}s")

        old_handler = signal.signal(signal.SIGALRM, _timeout_handler)
        signal.setitimer(signal.ITIMER_REAL, timeout)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, old_handler)

        try:
            content = sf.read_text()
            sessions = json.loads(content) if content.strip() else {}
        except (json.JSONDecodeError, OSError):
            sessions = {}

        yield sessions

        _atomic_write(sf, sessions)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def _prune_orphaned_sessions() -> None:
    """Remove session entries whose workflow JSON no longer exists."""
    sf = _sessions_file()
    if not sf.exists():
        return
    sessions = _read_sessions()
    if not sessions:
        return
    orphaned = [sid for sid, wname in sessions.items()
                if not _workflow_file(wname).exists()]
    if not orphaned:
        return
    with _locked_sessions() as live:
        for sid in orphaned:
            live.pop(sid, None)


def _read_active() -> tuple[dict, str]:
    """Read the active workflow for the current session. Returns (data, name)."""
    session_id = _get_session_id()
    if session_id:
        sessions = _read_sessions()
        wf_name = sessions.get(session_id)
        if wf_name:
            wf_file = _workflow_file(wf_name)
            if wf_file.exists():
                data = _read_workflow(wf_file)
                return data, data.get("name", wf_name)

    # Fallback: .active symlink
    link = _active_link()
    if not link.exists():
        print("No active workflow.", file=sys.stderr)
        sys.exit(1)
    target = Path(os.readlink(str(link)))
    if not target.is_absolute():
        target = link.parent / target
    if not target.exists():
        print(f"Active workflow file missing: {target}", file=sys.stderr)
        sys.exit(1)
    data = _read_workflow(target)
    return data, data.get("name", target.stem)


def _set_active(name: str) -> None:
    """Set active workflow for current session."""
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions[session_id] = name

    link = _active_link()
    target = f"{name}.json"
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.is_symlink() or link.exists():
        link.unlink()
    os.symlink(target, str(link))


def _save_active(data: dict) -> None:
    """Save the active workflow back to its file."""
    name = data["name"]
    data["last_updated"] = datetime.now().isoformat()
    _atomic_write(_workflow_file(name), data)


def _new_workflow(name: str) -> dict:
    """Create a new workflow data structure."""
    return {
        "name": name,
        "current_phase": "phase1_context",
        "created": datetime.now().isoformat(),
        "last_updated": datetime.now().isoformat(),
        "spec_file": None,
        "spec_approved": False,
        "context_file": None,
        "affected_files": [],
        "test_artifacts": [],
        "red_test_done": False,
        "ui_test_red_done": False,
        # 3 Human Checkpoints — ONLY settable by phase_listener.py
        "checkpoint1_approved": False,  # "stimmt" — diagnosis correct
        "checkpoint2_approved": False,  # "go" — tests check the right thing
        "checkpoint3_approved": False,  # "commit" — result works
        # Workflow type: "bug" or "feature"
        "workflow_type": None,
        # Pflichtschritte Gates (INFRA_015b)
        "inspect_ui_done": False,
        "localize_checked": False,
        "no_user_strings": False,
    }


# --- Phase Transition Validation ---

def _has_override_token(workflow_name: str) -> bool:
    """Check if user has granted an override token for this workflow."""
    token_file = _project_root() / ".claude" / "user_override_token.json"
    if not token_file.exists():
        return False
    try:
        raw = json.loads(token_file.read_text())
        tokens = raw.get("tokens", {}) if raw.get("version") == 2 else {}
        return workflow_name in tokens or "__global__" in tokens
    except (json.JSONDecodeError, OSError):
        return False


def _validate_transition(data: dict, target: str) -> str | None:
    """Validate phase transition prerequisites. Returns error message or None."""
    current = data.get("current_phase", "phase0_idle")
    cur_idx = PHASES.index(current) if current in PHASES else 0
    tgt_idx = PHASES.index(target) if target in PHASES else -1

    if tgt_idx < 0:
        return f"Unknown phase: {target}"

    # Allow backward transitions (reset) and same-phase
    if tgt_idx <= cur_idx:
        return None

    # User override token bypasses ALL gates
    wf_name = data.get("name", "")
    if wf_name and _has_override_token(wf_name):
        return None

    # --- Gate: Context must exist before analysis ---
    if tgt_idx >= PHASES.index("phase2_analyse"):
        if not data.get("context_file"):
            return "context_file not set — run /01-context first"

    # --- Gate: Checkpoint 1 — Henning approved diagnosis ---
    if tgt_idx >= PHASES.index("phase3_spec"):
        if not data.get("checkpoint1_approved"):
            return ("Checkpoint 1 nicht bestanden — präsentiere Henning die Analyse "
                    "(Root Cause + betroffene Stellen + Ansatz). "
                    "Henning muss 'stimmt' sagen.")

    # --- Gate: Spec approved ---
    if tgt_idx >= PHASES.index("phase4_tdd_red"):
        if not data.get("spec_file"):
            return "spec_file not set — run /03-write-spec first"
        if not data.get("spec_approved"):
            return "Spec not approved — Henning muss 'approved' sagen"

    # --- Gate: RED test artifacts before implementation ---
    if tgt_idx >= PHASES.index("phase5_implement"):
        red_artifacts = [a for a in data.get("test_artifacts", [])
                        if a.get("phase") == "phase4_tdd_red"]
        if not red_artifacts:
            return "No RED test artifacts — run /04-tdd-red first"
        if not data.get("ui_test_red_done"):
            return ("ui_test_red_done not set — UI tests are MANDATORY. "
                    "Run UI tests in /04-tdd-red and mark-ui-red")

    # --- Gate: Checkpoint 2 — Henning approved tests ---
    if tgt_idx >= PHASES.index("phase5_implement"):
        if not data.get("checkpoint2_approved"):
            return ("Checkpoint 2 nicht bestanden — präsentiere Henning die Tests "
                    "(Testname + was er prüft + FAILED Output). "
                    "Henning muss 'go' sagen.")

    # --- Gate: Checkpoint 3 — Henning approved result ---
    if tgt_idx >= PHASES.index("phase6_done"):
        if not data.get("checkpoint3_approved"):
            return ("Checkpoint 3 nicht bestanden — präsentiere Henning das Ergebnis "
                    "(ALL GREEN Output + vorher/nachher Screenshot). "
                    "Henning muss 'commit' sagen.")

    # --- Gate: Adversary Findings müssen alle resolved sein ---
    if tgt_idx >= PHASES.index("phase6_done"):
        findings = data.get("adversary_findings", [])
        unresolved = [f for f in findings if f.get("status") is None]
        if unresolved:
            titles = ", ".join(f["title"] for f in unresolved[:3])
            return (f"BLOCKED: {len(unresolved)} Adversary-Finding(s) noch offen: {titles}. "
                    "Jedes Finding muss von Henning beantwortet werden.")

    return None


# --- Commands ---

def cmd_start(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py start <name>", file=sys.stderr)
        sys.exit(1)
    name = args[0]
    wf_file = _workflow_file(name)
    if wf_file.exists():
        print(f"Workflow {name} already exists. Use 'switch' to activate.", file=sys.stderr)
        sys.exit(1)
    data = _new_workflow(name)
    _atomic_write(wf_file, data)
    _set_active(name)
    print(f"Started workflow: {name}")


def cmd_switch(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py switch <name>", file=sys.stderr)
        sys.exit(1)
    name = args[0]
    wf_file = _workflow_file(name)
    if not wf_file.exists():
        print(f"Workflow {name} not found.", file=sys.stderr)
        sys.exit(1)
    _set_active(name)
    print(f"Switched to workflow: {name}")


def cmd_status(args: list[str]) -> None:
    data, name = _read_active()
    phase = data.get("current_phase", "phase0_idle")
    phase_name = PHASE_NAMES.get(phase, phase)
    spec = data.get("spec_file") or "Not created"
    approved = "Yes" if data.get("spec_approved") else "No"
    cp1 = "Yes" if data.get("checkpoint1_approved") else "No"
    cp2 = "Yes" if data.get("checkpoint2_approved") else "No"
    cp3 = "Yes" if data.get("checkpoint3_approved") else "No"
    artifacts = len(data.get("test_artifacts", []))
    print(f"Workflow: {name}")
    print(f"Phase: {phase_name} ({phase})")
    print(f"Spec: {spec}")
    print(f"Spec Approved: {approved}")
    print(f"Checkpoint 1 (Diagnose): {cp1}")
    print(f"Checkpoint 2 (Tests): {cp2}")
    print(f"Checkpoint 3 (Ergebnis): {cp3}")
    print(f"Test Artifacts: {artifacts}")
    print(f"RED done: {'Yes' if data.get('red_test_done') else 'No'}")
    print(f"UI RED done: {'Yes' if data.get('ui_test_red_done') else 'No'}")
    findings = data.get("adversary_findings", [])
    if findings:
        unresolved = sum(1 for f in findings if f.get("status") is None)
        print(f"Adversary Findings: {len(findings)} total, {unresolved} open")


def cmd_phase(args: list[str]) -> None:
    if not args:
        print("Usage: workflow.py phase <phase>", file=sys.stderr)
        sys.exit(1)
    target = args[0]
    data, name = _read_active()
    error = _validate_transition(data, target)
    if error:
        print(f"BLOCKED: {error}", file=sys.stderr)
        sys.exit(1)
    data["current_phase"] = target
    # Reset inspect_ui_done when re-entering TDD RED
    if target == "phase4_tdd_red":
        data["inspect_ui_done"] = False
    _save_active(data)
    print(f"Set phase to: {target}")


# --- Protected Fields ---

# These fields can ONLY be set by phase_listener.py (via WORKFLOW_CALLER env check)
CHECKPOINT_FIELDS = {
    "checkpoint1_approved",
    "checkpoint2_approved",
    "checkpoint3_approved",
}

PROTECTED_FIELDS = {
    *CHECKPOINT_FIELDS,
    "spec_approved",
    "red_test_done",
    "ui_test_red_done",
    "context_file",
    "inspect_ui_done",
    "localize_checked",
    # no_user_strings bewusst NICHT protected — Claude darf es setzen
}


def cmd_set_field(args: list[str]) -> None:
    if len(args) < 2:
        print("Usage: workflow.py set-field <key> <value>", file=sys.stderr)
        sys.exit(1)
    key, value = args[0], " ".join(args[1:])
    caller = os.environ.get("WORKFLOW_CALLER", "")

    # Checkpoint fields: ONLY phase_listener can set these
    if key in CHECKPOINT_FIELDS:
        if caller != "phase_listener":
            print(f"BLOCKED: '{key}' can only be set by phase_listener.py "
                  f"(triggered by Henning's input). Claude cannot set checkpoints.",
                  file=sys.stderr)
            sys.exit(1)

    # Other protected fields: use dedicated mark-* commands
    if key in PROTECTED_FIELDS and caller not in ("phase_listener", "qa_gate"):
        print(f"BLOCKED: '{key}' is a protected field. "
              f"Use the dedicated command instead.", file=sys.stderr)
        sys.exit(1)

    # Parse booleans
    if value.lower() in ("true", "yes"):
        value = True
    elif value.lower() in ("false", "no"):
        value = False
    else:
        import json as _json
        try:
            parsed = _json.loads(value)
            if isinstance(parsed, (list, dict, int, float)):
                value = parsed
        except (ValueError, TypeError):
            pass
    data, name = _read_active()
    data[key] = value
    _save_active(data)
    print(f"Set {key} = {value} on workflow {name}")


def cmd_set_affected_files(args: list[str]) -> None:
    replace = "--replace" in args
    files = [a for a in args if a != "--replace"]
    data, name = _read_active()

    ALLOWED_PHASES_FOR_SCOPE = {
        "phase0_idle", "phase1_context", "phase2_analyse", "phase3_spec",
    }
    phase = data.get("current_phase", "phase0_idle")
    if phase not in ALLOWED_PHASES_FOR_SCOPE:
        if not _has_override_token(name):
            print(f"BLOCKED: set-affected-files nicht erlaubt in Phase {phase}. "
                  f"Scope wird vor TDD RED definiert.", file=sys.stderr)
            sys.exit(1)

    if replace:
        data["affected_files"] = files
    else:
        existing = set(data.get("affected_files", []))
        existing.update(files)
        data["affected_files"] = sorted(existing)
    _save_active(data)
    print(f"Set affected_files on workflow {name}: {len(data['affected_files'])} files")


def cmd_add_artifact(args: list[str]) -> None:
    if len(args) < 4:
        print("Usage: workflow.py add-artifact <type> <path> <desc> <phase>", file=sys.stderr)
        sys.exit(1)
    art_type, art_path, desc, phase = args[0], args[1], args[2], args[3]
    data, _ = _read_active()
    data.setdefault("test_artifacts", []).append({
        "type": art_type,
        "path": art_path,
        "description": desc,
        "phase": phase,
        "created": datetime.now().isoformat(),
    })
    _save_active(data)
    name = data["name"]
    print(f"Artifact added to {name}: {art_type} ({desc})")


def cmd_mark_red(args: list[str]) -> None:
    result = " ".join(args) if args else "failed"
    data, name = _read_active()
    data["red_test_done"] = True
    data["red_test_result"] = result
    _save_active(data)
    print(f"RED unit test marked done: {result}")


def cmd_mark_ui_red(args: list[str]) -> None:
    result = " ".join(args) if args else "failed"
    data, name = _read_active()
    data["ui_test_red_done"] = True
    data["ui_test_red_result"] = result
    _save_active(data)
    print(f"RED UI test marked done: {result}")


def cmd_mark_green(args: list[str]) -> None:
    result = " ".join(args) if args else "passed"
    data, name = _read_active()
    data["green_test_done"] = True
    data["green_test_result"] = result
    _save_active(data)
    print(f"GREEN unit test marked done: {result}")


def cmd_mark_ui_green(args: list[str]) -> None:
    result = " ".join(args) if args else "passed"
    data, name = _read_active()
    data["ui_test_green_done"] = True
    data["ui_test_green_result"] = result
    _save_active(data)
    print(f"GREEN UI test marked done: {result}")


def cmd_mark_context(args: list[str]) -> None:
    context_file = " ".join(args) if args else ""
    if not context_file:
        print("BLOCKED: Provide the context file path.", file=sys.stderr)
        sys.exit(1)
    ctx_path = _project_root() / context_file
    if not ctx_path.exists():
        print(f"BLOCKED: Context file not found: {context_file}", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["context_file"] = context_file
    _save_active(data)
    print(f"Context file recorded: {context_file}")


def cmd_mark_checkpoint1(args: list[str]) -> None:
    """Checkpoint 1: Henning approved diagnosis. ONLY callable from phase_listener."""
    caller = os.environ.get("WORKFLOW_CALLER", "")
    if caller != "phase_listener":
        print("BLOCKED: mark-checkpoint1 can only be called by phase_listener.py "
              "(triggered by Henning typing 'stimmt').", file=sys.stderr)
        sys.exit(1)
    notes = " ".join(args) if args else "approved"
    data, name = _read_active()
    data["checkpoint1_approved"] = True
    data["checkpoint1_notes"] = notes
    _save_active(data)
    print(f"Checkpoint 1 approved: {notes}")


def cmd_mark_checkpoint2(args: list[str]) -> None:
    """Checkpoint 2: Henning approved tests. ONLY callable from phase_listener."""
    caller = os.environ.get("WORKFLOW_CALLER", "")
    if caller != "phase_listener":
        print("BLOCKED: mark-checkpoint2 can only be called by phase_listener.py "
              "(triggered by Henning typing 'go').", file=sys.stderr)
        sys.exit(1)
    notes = " ".join(args) if args else "approved"
    data, name = _read_active()
    data["checkpoint2_approved"] = True
    data["checkpoint2_notes"] = notes
    _save_active(data)
    print(f"Checkpoint 2 approved: {notes}")


def cmd_mark_checkpoint3(args: list[str]) -> None:
    """Checkpoint 3: Henning approved result. ONLY callable from phase_listener."""
    caller = os.environ.get("WORKFLOW_CALLER", "")
    if caller != "phase_listener":
        print("BLOCKED: mark-checkpoint3 can only be called by phase_listener.py "
              "(triggered by Henning typing 'commit').", file=sys.stderr)
        sys.exit(1)
    notes = " ".join(args) if args else "approved"
    data, name = _read_active()
    data["checkpoint3_approved"] = True
    data["checkpoint3_notes"] = notes
    _save_active(data)
    print(f"Checkpoint 3 approved: {notes}")


def cmd_mark_inspect_ui(args: list[str]) -> None:
    """Mark inspect-ui as done for current workflow."""
    data, name = _read_active()
    data["inspect_ui_done"] = True
    _save_active(data)
    print(f"inspect-ui marked done for {name}")


def cmd_mark_localize(args: list[str]) -> None:
    """Mark localization check as done for current workflow."""
    data, name = _read_active()
    data["localize_checked"] = True
    _save_active(data)
    print(f"Localization check marked done for {name}")


def cmd_add_finding(args: list[str]) -> None:
    """Add an adversary finding. Usage: add-finding <title> <impact> <proof>"""
    if len(args) < 3:
        print("Usage: workflow.py add-finding <title> <impact> <proof>", file=sys.stderr)
        sys.exit(1)
    title, impact, proof = args[0], args[1], args[2]
    data, name = _read_active()
    findings = data.setdefault("adversary_findings", [])
    next_id = max((f.get("id", 0) for f in findings), default=0) + 1
    findings.append({
        "id": next_id,
        "title": title,
        "impact": impact,
        "proof": proof,
        "status": None,
        "resolved_at": None,
    })
    _save_active(data)
    print(f"Finding #{next_id} added: {title}")


def cmd_resolve_finding(args: list[str]) -> None:
    """Resolve an adversary finding. ONLY callable from phase_listener.
    Usage: resolve-finding <id> <status>
    Status: fix, accept, defer
    """
    caller = os.environ.get("WORKFLOW_CALLER", "")
    if caller != "phase_listener":
        print("BLOCKED: resolve-finding can only be called by phase_listener.py "
              "(triggered by Henning's input). Claude cannot resolve findings.",
              file=sys.stderr)
        sys.exit(1)
    if len(args) < 2:
        print("Usage: workflow.py resolve-finding <id> <status>", file=sys.stderr)
        sys.exit(1)
    try:
        finding_id = int(args[0])
    except ValueError:
        print(f"Invalid finding ID: {args[0]}. Must be a number.", file=sys.stderr)
        sys.exit(1)
    status = args[1]
    if status not in ("fix", "accept", "defer"):
        print(f"Invalid status: {status}. Must be fix, accept, or defer.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    findings = data.get("adversary_findings", [])
    for f in findings:
        if f.get("id") == finding_id:
            f["status"] = status
            f["resolved_at"] = datetime.now().isoformat()
            _save_active(data)
            print(f"Finding #{finding_id} resolved: {status}")
            if status == "fix":
                import subprocess as _sp
                title_text = f"[Adversary-Finding] {f['title']}"
                body_text = (f"**Impact:** {f['impact']}\n\n"
                             f"**Proof:** {f['proof']}\n\n"
                             f"Aus Workflow: {name}")
                try:
                    _sp.run(
                        ["gh", "issue", "create", "--title", title_text,
                         "--body", body_text],
                        capture_output=True, text=True, check=True
                    )
                    print(f"GitHub Issue created for Finding #{finding_id}")
                except (FileNotFoundError, _sp.CalledProcessError) as e:
                    print(f"Warning: Could not create GitHub Issue: {e}",
                          file=sys.stderr)
            return
    print(f"Finding #{finding_id} not found.", file=sys.stderr)
    sys.exit(1)


def cmd_import_findings(args: list[str]) -> None:
    """Import findings from JSON string. Usage: import-findings '<json_array>'"""
    import json as json_mod
    if not args:
        print("Usage: workflow.py import-findings '<json_array>'", file=sys.stderr)
        sys.exit(1)
    raw = " ".join(args)
    try:
        items = json_mod.loads(raw)
    except json_mod.JSONDecodeError as e:
        print(f"Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(items, list):
        print("JSON must be an array of findings.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    findings = data.setdefault("adversary_findings", [])
    next_id = max((f.get("id", 0) for f in findings), default=0) + 1
    added = 0
    for item in items:
        if not all(k in item for k in ("title", "impact", "proof")):
            print(f"Skipping invalid finding (missing title/impact/proof): {item}", file=sys.stderr)
            continue
        findings.append({
            "id": next_id,
            "title": item["title"],
            "impact": item["impact"],
            "proof": item["proof"],
            "status": None,
            "resolved_at": None,
        })
        next_id += 1
        added += 1
    _save_active(data)
    print(f"Imported {added} findings.")


def cmd_list_findings(args: list[str]) -> None:
    """List all adversary findings with status."""
    data, name = _read_active()
    findings = data.get("adversary_findings", [])
    if not findings:
        print("No adversary findings.")
        return
    for f in findings:
        status = f.get("status") or "OPEN"
        print(f"  #{f['id']}: [{status.upper()}] {f['title']}")
    unresolved = sum(1 for f in findings if f.get("status") is None)
    print(f"\n{len(findings)} findings total, {unresolved} open")


def cmd_complete(args: list[str]) -> None:
    data, name = _read_active()
    data["current_phase"] = "phase6_done"
    archive = _archive_dir()
    archive.mkdir(parents=True, exist_ok=True)
    _atomic_write(archive / f"{name}.json", data)
    wf_file = _workflow_file(name)
    if wf_file.exists():
        wf_file.unlink()
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions.pop(session_id, None)
    link = _active_link()
    if link.is_symlink():
        target = os.readlink(str(link))
        if Path(target).stem == name:
            link.unlink()
    print(f"Workflow {name} completed and archived.")


def cmd_list(args: list[str]) -> None:
    wf_dir = _workflows_dir()
    if not wf_dir.exists():
        print("No workflows.")
        return
    _prune_orphaned_sessions()
    session_id = _get_session_id()
    sessions = _read_sessions()
    my_active = sessions.get(session_id) if session_id else None
    if not my_active:
        link = _active_link()
        if link.is_symlink():
            target = os.readlink(str(link))
            my_active = Path(target).stem
    wf_sessions = {}
    for sid, wname in sessions.items():
        wf_sessions.setdefault(wname, []).append(sid[:8])
    for f in sorted(wf_dir.glob("*.json")):
        if f.name == ".sessions.json":
            continue
        data = _read_workflow(f)
        name = data.get("name", f.stem)
        phase = data.get("current_phase", "?")
        marker = " *" if name == my_active else ""
        session_info = f" [{', '.join(wf_sessions[name])}]" if name in wf_sessions else ""
        print(f"  {name}: {PHASE_NAMES.get(phase, phase)}{marker}{session_info}")


def cmd_snapshot_tests(args: list[str]) -> None:
    """Snapshot all test methods for regression guard."""
    import re
    root = _project_root()
    test_dirs = [root / "FocusBloxTests", root / "FocusBloxUITests",
                 root / "FocusBloxMacTests", root / "FocusBloxMacUITests"]
    total_tests = 0
    total_files = 0
    for test_dir in test_dirs:
        if not test_dir.exists():
            continue
        for swift_file in sorted(test_dir.glob("**/*.swift")):
            content = swift_file.read_text()
            test_methods = re.findall(r'func\s+(test\w+)\s*\(', content)
            if test_methods:
                total_files += 1
                total_tests += len(test_methods)
                rel = swift_file.relative_to(root)
                print(f"  {rel}: {len(test_methods)} tests")
    print(f"Snapshot saved: {total_tests} tests in {total_files} files")


COMMANDS = {
    "start": cmd_start,
    "switch": cmd_switch,
    "status": cmd_status,
    "phase": cmd_phase,
    "set-field": cmd_set_field,
    "set-affected-files": cmd_set_affected_files,
    "add-artifact": cmd_add_artifact,
    "mark-red": cmd_mark_red,
    "mark-ui-red": cmd_mark_ui_red,
    "mark-green": cmd_mark_green,
    "mark-ui-green": cmd_mark_ui_green,
    "mark-context": cmd_mark_context,
    "mark-inspect-ui": cmd_mark_inspect_ui,
    "mark-localize": cmd_mark_localize,
    "mark-checkpoint1": cmd_mark_checkpoint1,
    "mark-checkpoint2": cmd_mark_checkpoint2,
    "mark-checkpoint3": cmd_mark_checkpoint3,
    "add-finding": cmd_add_finding,
    "import-findings": cmd_import_findings,
    "resolve-finding": cmd_resolve_finding,
    "list-findings": cmd_list_findings,
    "complete": cmd_complete,
    "list": cmd_list,
    "snapshot-tests": cmd_snapshot_tests,
}


def main():
    if len(sys.argv) < 2:
        print("Usage: workflow.py <command> [args...]", file=sys.stderr)
        print(f"Commands: {', '.join(COMMANDS.keys())}", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

    COMMANDS[cmd](sys.argv[2:])


if __name__ == "__main__":
    main()
