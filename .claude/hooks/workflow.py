#!/usr/bin/env python3
"""
Workflow v4 — Session-Aware State Manager

Each workflow gets its own JSON file in .claude/workflows/.
Active workflow tracked per-session via .sessions.json mapping.
Fallback to .active symlink for backward compatibility.

Session identification:
  - $CLAUDE_SESSION_ID env var (set by session_start.py hook via CLAUDE_ENV_FILE)
  - Hooks receive session_id in stdin JSON

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
    "phase4_approved",
    "phase5_tdd_red",
    "phase6_implement",
    "phase6b_adversary",
    "phase7_validate",
    "phase8_complete",
]

PHASE_NAMES = {
    "phase0_idle": "Idle",
    "phase1_context": "Context Generation",
    "phase2_analyse": "Analysis",
    "phase3_spec": "Specification Writing",
    "phase4_approved": "Spec Approved",
    "phase5_tdd_red": "TDD RED - Write Failing Tests",
    "phase6_implement": "Implementation (TDD GREEN)",
    "phase6b_adversary": "Adversary Verification",
    "phase7_validate": "Validation",
    "phase8_complete": "Complete",
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
    """Context manager for atomic Read-Modify-Write on .sessions.json.

    Usage:
        with _locked_sessions() as sessions:
            sessions["my_id"] = "my_workflow"
            # File is written and lock released on exit

    Yields a mutable dict. Changes are written back atomically on __exit__.
    """
    sf = _sessions_file()
    sf.parent.mkdir(parents=True, exist_ok=True)
    # Create file if missing so we can flock it
    if not sf.exists():
        sf.write_text("{}")
    lock_fd = os.open(str(sf), os.O_RDWR)
    try:
        # Blocking lock with timeout via alarm (POSIX)
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

        # Read current state
        try:
            content = sf.read_text()
            sessions = json.loads(content) if content.strip() else {}
        except (json.JSONDecodeError, OSError):
            sessions = {}

        yield sessions

        # Write back atomically
        _atomic_write(sf, sessions)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def _prune_orphaned_sessions() -> None:
    """Remove session entries whose workflow JSON no longer exists.

    A session is orphaned when its workflow was archived/deleted but
    the session mapping remained (e.g. due to a crash).
    """
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
    """Read the active workflow for the current session. Returns (data, name).

    Priority:
    1. Session mapping (.sessions.json) if CLAUDE_SESSION_ID is set
    2. Fallback to .active symlink
    """
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
    """Set active workflow for current session.

    Updates .sessions.json if CLAUDE_SESSION_ID is set.
    Always updates .active symlink for backward compatibility.
    """
    # Update session mapping (locked to prevent lost updates)
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions[session_id] = name

    # Always update .active symlink (backward compat + debugging)
    # .sessions.json remains source of truth for session-aware tools
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
        "is_new_ui": False,
        "red_test_done": False,
        "ui_test_red_done": False,
        "green_approved": False,
        "adversary_verdict": None,
        # Analysis quality gates (bugs)
        "visual_inspection_done": False,
        "analysis_file": None,
        "analysis_findings": None,
        "challenge_verdict": None,
        # Fix proposal gate (bugs)
        "fix_proposal_approved": False,
        "existence_check_done": False,
        "dead_code_check_done": False,
        # Feature gates
        "user_expectation_done": False,
        "result_inspection_done": False,
        # Inspect-UI preflight gate (INFRA_014)
        "inspect_ui_done": False,
        # Workflow type: "bug" or "feature" (set by /10-bug or /11-feature)
        "workflow_type": None,
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

    # Forward transitions: validate prerequisites for each step

    # --- Gate: Context must exist before analysis ---
    if tgt_idx >= PHASES.index("phase2_analyse"):
        if not data.get("context_file"):
            return "context_file not set — run /01-context first"

    # --- Gate: Analysis Quality (before spec writing) ---
    if tgt_idx >= PHASES.index("phase3_spec"):
        wf_type = data.get("workflow_type")

        if wf_type == "feature":
            # Feature path: user expectation must be captured first
            if not data.get("user_expectation_done"):
                return ("user_expectation_done not set — run User-Advocate Agent "
                        "(Schritt 0 in /11-feature) and get user confirmation")
        else:
            # Bug path (default): full analysis quality gates
            if not data.get("visual_inspection_done"):
                return ("visual_inspection_done not set — run Fresh-Eyes-Inspector "
                        "(Schritt 0.2 in /10-bug) or get user override")
            if not data.get("existence_check_done"):
                return ("existence_check_done not set — run Existenz-Check "
                        "(Schritt 0.5 in /10-bug): git log grep, GitHub Issues search")
            if not data.get("analysis_file"):
                return ("analysis_file not set — create docs/artifacts/[name]/analysis.md "
                        "(Schritt 5 in /10-bug)")
            if not data.get("analysis_findings"):
                return ("analysis_findings not set — document findings from "
                        "5 parallel investigate tasks (Schritt 2-4 in /10-bug)")
            challenge = data.get("challenge_verdict")
            if not challenge or not str(challenge).upper().startswith("SOLIDE"):
                return (f"challenge_verdict is '{challenge}' — must be 'SOLIDE'. "
                        "Run analysis-challenger agent (Schritt 5.5 in /10-bug)")

    # --- Gate: Spec approval ---
    if tgt_idx >= PHASES.index("phase4_approved"):
        if not data.get("spec_file"):
            return "spec_file not set — run /03-write-spec first"
        if not data.get("spec_approved"):
            return "Spec not approved — user must say 'approved'"
        if not data.get("spec_validated"):
            return ("spec_validated not set — run spec-validator agent and "
                    "mark-spec-validated with validation result")

    # --- Gate: Fix proposal must be approved before TDD RED ---
    if tgt_idx >= PHASES.index("phase5_tdd_red"):
        if not data.get("fix_proposal_approved"):
            return ("fix_proposal_approved not set — present fix proposal to user "
                    "and wait for approval (Schritt 7 in /10-bug)")

    # --- Gate: RED test artifacts before implementation ---
    if tgt_idx >= PHASES.index("phase6_implement"):
        red_artifacts = [a for a in data.get("test_artifacts", [])
                        if a.get("phase") == "phase5_tdd_red"]
        if not red_artifacts:
            return "No RED test artifacts — run /04-tdd-red first"

    # --- Gate: UI tests are MANDATORY (CLAUDE.md rule) ---
    if tgt_idx >= PHASES.index("phase6_implement"):
        if not data.get("ui_test_red_done"):
            return ("ui_test_red_done not set — UI tests are MANDATORY for every "
                    "feature/bug. Run UI tests in /04-tdd-red and mark-ui-red")

    # --- Gate: Inspect-UI preflight before implementation (INFRA_014) ---
    if tgt_idx >= PHASES.index("phase6_implement"):
        if data.get("ui_test_red_done") and not data.get("inspect_ui_done"):
            return ("inspect_ui_done not set — run /inspect-ui before writing UI tests. "
                    "Then mark with: mark-inspect-ui-done <screen-name + observations>")

    # --- Gate: Result inspection before adversary (features) ---
    if tgt_idx >= PHASES.index("phase6b_adversary"):
        if data.get("workflow_type") == "feature":
            if not data.get("result_inspection_done"):
                return ("result_inspection_done not set — run Fresh-Eyes-Inspector "
                        "on implementation result (Nach Implementation in /11-feature)")

    # --- Gate: Must pass through phase6b_adversary ---
    if tgt_idx >= PHASES.index("phase7_validate"):
        if not data.get("adversary_phase_visited"):
            return ("Must pass through phase6b_adversary before validation — "
                    "run adversary check first")

    # --- Gate: Dead-code check before validation ---
    if tgt_idx >= PHASES.index("phase7_validate"):
        if not data.get("dead_code_check_done"):
            return ("dead_code_check_done not set — grep for callers of new/changed "
                    "functions to prove they are not dead code (Schritt 8.3 in /10-bug)")

    # --- Gate: GREEN test artifacts before validation ---
    if tgt_idx >= PHASES.index("phase7_validate"):
        green_artifacts = [a for a in data.get("test_artifacts", [])
                          if a.get("phase") == "phase6_implement"]
        if not green_artifacts and not data.get("green_approved"):
            return ("No GREEN test artifacts — tests must pass after implementation. "
                    "Run tests and add artifacts, or get green_approved from user")

    # --- Gate: Adversary verdict before completion ---
    if tgt_idx >= PHASES.index("phase8_complete"):
        verdict = data.get("adversary_verdict", "")
        if not verdict or not str(verdict).startswith("VERIFIED"):
            return "Adversary verdict missing or not VERIFIED"

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
    green_ok = "Yes" if data.get("green_approved") else "No"
    artifacts = len(data.get("test_artifacts", []))
    green_test = "Yes" if data.get("green_test_done") else "No"
    regression = "Yes" if data.get("regression_check_done") else "No"
    docs = "Yes" if data.get("docs_updated") else "No"
    validation = "Yes" if data.get("validation_done") else "No"
    print(f"Workflow: {name}")
    print(f"Phase: {phase_name}")
    print(f"Spec: {spec}")
    print(f"Approved: {approved}")
    print(f"GREEN Approved: {green_ok}")
    print(f"Test Artifacts: {artifacts}")
    print(f"green_test_done: {green_test}")
    print(f"ui_test_green_done: {'Yes' if data.get('ui_test_green_done') else 'No'}")
    print(f"spec_validated: {'Yes' if data.get('spec_validated') else 'No'}")
    print(f"regression_check_done: {regression}")
    print(f"spec_compliance_done: {'Yes' if data.get('spec_compliance_done') else 'No'}")
    print(f"coverage_check_done: {'Yes' if data.get('coverage_check_done') else 'No'}")
    print(f"docs_updated: {docs}")
    print(f"validation_done: {validation}")


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
    # Track phase6b visit for enforcement
    if target == "phase6b_adversary":
        data["adversary_phase_visited"] = True
    _save_active(data)
    print(f"Set phase to: {target}")


# --- Protected Fields ---

PROTECTED_FIELDS = {
    "adversary_verdict",
    "green_test_done",
    "ui_test_green_done",
    "regression_check_done",
    "docs_updated",
    "validation_done",
    # Gate flags — must use dedicated mark-* commands
    "spec_approved",
    "visual_inspection_done",
    "fix_proposal_approved",
    "user_expectation_done",
    "result_inspection_done",
    "red_test_done",
    "analysis_findings",
    "challenge_verdict",
    "context_file",
    "existence_check_done",
    "dead_code_check_done",
    "github_issue_updated",
    "spec_validated",
    "spec_compliance_done",
    "coverage_check_done",
}


def cmd_set_field(args: list[str]) -> None:
    if len(args) < 2:
        print("Usage: workflow.py set-field <key> <value>", file=sys.stderr)
        sys.exit(1)
    key, value = args[0], " ".join(args[1:])
    # Protected fields can only be set by dedicated commands (or qa_gate.py)
    caller = os.environ.get("WORKFLOW_CALLER", "")
    if key in PROTECTED_FIELDS and caller != "qa_gate":
        print(f"BLOCKED: '{key}' is a protected field. "
              f"Use the dedicated command instead.", file=sys.stderr)
        sys.exit(1)
    # Parse booleans
    if value.lower() in ("true", "yes"):
        value = True
    elif value.lower() in ("false", "no"):
        value = False
    else:
        # Try parsing as JSON (for lists, dicts, numbers)
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

    # Phase-Guard: affected_files nur in frühen Phasen änderbar (#186)
    ALLOWED_PHASES_FOR_SCOPE = {
        "phase0_idle",
        "phase1_context",
        "phase2_analyse",
        "phase3_spec",
        "phase4_approved",  # /10-bug Schritt 7.5 braucht das
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


REQUIRED_REGRESSION_SUITES = [
    "FocusBloxTests",
    "BacklogViewUITests",
    "DayViewUITests",
    "CoachTabLayoutUITests",
]


def cmd_mark_regression_done(args: list[str]) -> None:
    result = " ".join(args) if args else "no regressions"
    data, name = _read_active()
    # Keyword validation: all 4 required suites must be mentioned
    wf_name = data.get("name", "")
    if not _has_override_token(wf_name):
        missing_suites = [s for s in REQUIRED_REGRESSION_SUITES if s not in result]
        if missing_suites:
            print(f"BLOCKED: Regression evidence must mention all required suites. "
                  f"Missing: {', '.join(missing_suites)}. "
                  f"Run: ./scripts/sim.sh unit FocusBloxTests && "
                  f"./scripts/sim.sh test BacklogViewUITests && "
                  f"./scripts/sim.sh test DayViewUITests && "
                  f"./scripts/sim.sh test CoachTabLayoutUITests",
                  file=sys.stderr)
            sys.exit(1)
    data["regression_check_done"] = True
    data["regression_check_result"] = result
    _save_active(data)
    print(f"Regression check marked done: {result}")


def cmd_mark_spec_validated(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide spec-validator result (VALID/INVALID + details).",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["spec_validated"] = True
    data["spec_validated_notes"] = notes
    _save_active(data)
    print(f"Spec validation marked done.")


def cmd_mark_spec_compliance(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide spec compliance result (N/N AC fulfilled).",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["spec_compliance_done"] = True
    data["spec_compliance_notes"] = notes
    _save_active(data)
    print(f"Spec compliance marked done.")


def cmd_mark_coverage_check(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide coverage check result from adversary_dialog.py coverage.",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["coverage_check_done"] = True
    data["coverage_check_notes"] = notes
    _save_active(data)
    print(f"Coverage check marked done.")


def cmd_mark_docs_updated(args: list[str]) -> None:
    result = " ".join(args) if args else "docs updated"
    data, name = _read_active()
    data["docs_updated"] = True
    data["docs_updated_result"] = result
    _save_active(data)
    print(f"Docs update marked done: {result}")


def cmd_mark_validation_done(args: list[str]) -> None:
    result = " ".join(args) if args else "all checks passed"
    data, name = _read_active()
    # Prerequisite check: green + regression + docs + compliance + coverage must be done
    missing = []
    if not data.get("green_test_done"):
        missing.append("green_test_done (run mark-green first)")
    if not data.get("regression_check_done"):
        missing.append("regression_check_done (run mark-regression-done first)")
    if not data.get("docs_updated"):
        missing.append("docs_updated (run mark-docs-updated first)")
    if not data.get("spec_compliance_done"):
        missing.append("spec_compliance_done (run mark-spec-compliance first)")
    if not data.get("coverage_check_done"):
        missing.append("coverage_check_done (run mark-coverage-check first)")
    if missing:
        print(f"BLOCKED: Prerequisites missing: {', '.join(missing)}",
              file=sys.stderr)
        sys.exit(1)
    data["validation_done"] = True
    data["validation_done_result"] = result
    _save_active(data)
    print(f"Validation marked done: {result}")


MIN_NOTES_LEN = 30  # Minimum chars for evidence notes


def cmd_mark_visual_inspection(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide real observations from the inspection.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["visual_inspection_notes"] = notes
    data["visual_inspection_done"] = True
    _save_active(data)
    print(f"Visual inspection marked done.")


def cmd_mark_inspect_ui_done(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide screen name and observed accessibility identifiers.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["inspect_ui_done"] = True
    data["inspect_ui_notes"] = notes
    _save_active(data)
    print(f"Inspect-UI preflight marked done.")


def cmd_mark_user_expectation(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide real user-advocate findings.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["user_expectation_notes"] = notes
    data["user_expectation_done"] = True
    _save_active(data)
    print(f"User expectation marked done.")


def cmd_mark_result_inspection(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide real fresh-eyes findings.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["result_inspection_notes"] = notes
    data["result_inspection_done"] = True
    _save_active(data)
    print(f"Result inspection marked done.")


def cmd_mark_fix_proposal(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide the approved fix proposal summary.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["fix_proposal_approved"] = True
    data["fix_proposal_notes"] = notes
    _save_active(data)
    print(f"Fix proposal marked approved.")


def cmd_mark_analysis(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Notes too short ({len(notes)}/{MIN_NOTES_LEN} chars). "
              f"Provide real analysis findings.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["analysis_findings"] = notes
    _save_active(data)
    print(f"Analysis findings recorded.")


def cmd_mark_challenge(args: list[str]) -> None:
    verdict = " ".join(args) if args else ""
    if len(verdict) < MIN_NOTES_LEN:
        print(f"BLOCKED: Verdict too short ({len(verdict)}/{MIN_NOTES_LEN} chars). "
              f"Provide the devil's advocate verdict.", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["challenge_verdict"] = verdict
    _save_active(data)
    print(f"Challenge verdict recorded.")


def cmd_mark_context(args: list[str]) -> None:
    context_file = " ".join(args) if args else ""
    if not context_file:
        print("BLOCKED: Provide the context file path.", file=sys.stderr)
        sys.exit(1)
    # Verify file exists
    ctx_path = _project_root() / context_file
    if not ctx_path.exists():
        print(f"BLOCKED: Context file not found: {context_file}", file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["context_file"] = context_file
    _save_active(data)
    print(f"Context file recorded: {context_file}")


def cmd_mark_existence_check(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Existence check notes must be >= {MIN_NOTES_LEN} chars. "
              f"Describe: git log result, GitHub Issues search result, code grep result.",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["existence_check_done"] = True
    data["existence_check_notes"] = notes
    _save_active(data)
    print(f"Existence check marked done: {notes}")


def cmd_mark_dead_code_check(args: list[str]) -> None:
    notes = " ".join(args) if args else ""
    if len(notes) < MIN_NOTES_LEN:
        print(f"BLOCKED: Dead-code check notes must be >= {MIN_NOTES_LEN} chars. "
              f"Describe: grep for callers, which functions are called from where.",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["dead_code_check_done"] = True
    data["dead_code_check_notes"] = notes
    _save_active(data)
    print(f"Dead-code check marked done: {notes}")


def cmd_mark_github_issue_updated(args: list[str]) -> None:
    details = " ".join(args) if args else ""
    if len(details) < 10:
        print("BLOCKED: Beschreibe was mit dem GitHub Issue passiert ist "
              "(z.B. 'closed #42' oder 'commented on #42 with fix summary'). "
              f"Mindestens 10 Zeichen, aktuell: {len(details)}.",
              file=sys.stderr)
        sys.exit(1)
    data, name = _read_active()
    data["github_issue_updated"] = True
    data["github_issue_update_details"] = details
    _save_active(data)
    print(f"GitHub Issue Update markiert: {details}")


def cmd_complete(args: list[str]) -> None:
    data, name = _read_active()
    data["current_phase"] = "phase8_complete"
    archive = _archive_dir()
    archive.mkdir(parents=True, exist_ok=True)
    _atomic_write(archive / f"{name}.json", data)
    # Remove from active workflows
    wf_file = _workflow_file(name)
    if wf_file.exists():
        wf_file.unlink()
    # Remove own session from mapping (locked to prevent lost updates)
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions.pop(session_id, None)
    # Remove .active symlink only if it points to this workflow
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
    # Prune orphaned sessions before listing
    _prune_orphaned_sessions()
    # Get session-based active workflow
    session_id = _get_session_id()
    sessions = _read_sessions()
    my_active = sessions.get(session_id) if session_id else None
    # Fallback to .active symlink
    if not my_active:
        link = _active_link()
        if link.is_symlink():
            target = os.readlink(str(link))
            my_active = Path(target).stem
    # Build reverse map: workflow -> list of short session IDs
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
    import glob
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
    "mark-regression-done": cmd_mark_regression_done,
    "mark-spec-validated": cmd_mark_spec_validated,
    "mark-spec-compliance": cmd_mark_spec_compliance,
    "mark-coverage-check": cmd_mark_coverage_check,
    "mark-docs-updated": cmd_mark_docs_updated,
    "mark-validation-done": cmd_mark_validation_done,
    "mark-inspect-ui-done": cmd_mark_inspect_ui_done,
    "mark-visual-inspection": cmd_mark_visual_inspection,
    "mark-user-expectation": cmd_mark_user_expectation,
    "mark-result-inspection": cmd_mark_result_inspection,
    "mark-fix-proposal": cmd_mark_fix_proposal,
    "mark-analysis": cmd_mark_analysis,
    "mark-challenge": cmd_mark_challenge,
    "mark-context": cmd_mark_context,
    "mark-existence-check": cmd_mark_existence_check,
    "mark-dead-code-check": cmd_mark_dead_code_check,
    "mark-github-issue-updated": cmd_mark_github_issue_updated,
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
