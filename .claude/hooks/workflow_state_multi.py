#!/usr/bin/env python3
"""
OpenSpec Framework - Multi-Workflow State Manager

Supports multiple parallel workflows in a single project.
Each workflow tracks its own phase independently.

State File Format (.claude/workflow_state.json):
{
  "version": "2.1",
  "workflows": {
    "feature-login-oauth": {
      "current_phase": "phase2_spec",
      "created": "2025-01-12T10:00:00Z",
      "last_updated": "2025-01-12T11:30:00Z",
      "spec_file": "docs/specs/auth/login-oauth.md",
      "spec_approved": false,
      "context_file": "docs/context/feature-login-oauth.md",
      "test_artifacts": [],
      "affected_files": []
    },
    "bugfix-crash-on-start": {
      "current_phase": "phase4_implement",
      ...
    }
  },
  "active_workflow": "feature-login-oauth",
  "session_workflows": {
    "a1b2c3d4": { "workflow": "feature-login-oauth", "tty": "/dev/ttys003" },
    "e5f6g7h8": { "workflow": "bugfix-crash-on-start", "tty": "/dev/ttys005" }
  }
}

Phases (in order):
- phase0_idle        : No workflow started
- phase1_context     : Gathering relevant context (NEW!)
- phase2_analyse     : Analysing requirements and codebase
- phase3_spec        : Writing specification
- phase4_approved    : Spec approved by user (gate)
- phase5_tdd_red     : Writing failing tests (TDD RED)
- phase6_implement   : Implementation (TDD GREEN)
- phase7_validate    : Validation and manual testing
- phase8_complete    : Workflow complete, ready for commit
"""

import fcntl
import hashlib
import json
import os
import sys
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Optional

# Phase definitions with order
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

# Human-readable phase names
PHASE_NAMES = {
    "phase0_idle": "Idle - No workflow started",
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

# Backlog status options
BACKLOG_STATUSES = ["open", "spec_ready", "in_progress", "done", "blocked"]

# Human-readable backlog status names
BACKLOG_STATUS_NAMES = {
    "open": "Open",
    "spec_ready": "Spec Ready",
    "in_progress": "In Progress",
    "done": "Done",
    "blocked": "Blocked",
}

# Automatic mapping: Phase -> Backlog Status
PHASE_TO_BACKLOG_STATUS = {
    "phase0_idle": "open",
    "phase1_context": "open",
    "phase2_analyse": "open",
    "phase3_spec": "open",
    "phase4_approved": "spec_ready",
    "phase5_tdd_red": "in_progress",
    "phase6_implement": "in_progress",
    "phase6b_adversary": "in_progress",
    "phase7_validate": "in_progress",
    "phase8_complete": "done",
}

# Phrases that indicate user wants to pause (not complete)
PAUSE_PHRASES = [
    "ich höre hier auf",
    "das reicht für heute",
    "implementation später",
    "nur die spec",
    "pause",
    "später weitermachen",
    "für heute fertig",
    "rest später",
    "spec reicht erstmal",
    "stop here",
    "pause workflow",
    "continue later",
]

# Phases that allow code modification
CODE_MODIFY_PHASES = ["phase6_implement", "phase6b_adversary", "phase7_validate", "phase8_complete"]

# Phases that require test artifacts
TEST_REQUIRED_PHASES = ["phase6_implement", "phase7_validate"]

# Phases where only one workflow may be active at a time (simulator/build exclusivity)
TDD_BLOCKING_PHASES = ["phase5_tdd_red", "phase6_implement"]

# Stale threshold: workflows older than this are ignored for conflict checks
TDD_STALE_THRESHOLD_HOURS = 48


def _get_conflicting_tdd_workflows(requesting_workflow: str) -> list[dict]:
    """Find other workflows in TDD-blocking phases within the SAME session.

    Session-aware: workflows owned by OTHER sessions are NOT conflicts.
    Only workflows in the same session (same TTY) or unassigned workflows
    are considered potential conflicts.

    Returns list of dicts with 'name' and 'phase' for each conflicting workflow.
    The requesting workflow itself is never considered a conflict (re-enter allowed).
    """
    state = load_state()
    conflicts = []

    # Build reverse map: workflow_name -> session_tty
    session_map = {}
    for _sid, entry in state.get("session_workflows", {}).items():
        wf_name = entry.get("workflow")
        if wf_name:
            session_map[wf_name] = entry.get("tty", "unknown")

    my_tty = _tty_path()

    for name, wf in state.get("workflows", {}).items():
        if name == requesting_workflow:
            continue

        phase = wf.get("current_phase", "phase0_idle")
        if phase not in TDD_BLOCKING_PHASES:
            continue

        # Session-aware: skip workflows owned by OTHER sessions
        other_tty = session_map.get(name)
        if other_tty and other_tty != my_tty:
            continue  # Different session — not our conflict

        # Check staleness
        ts = wf.get("last_updated") or wf.get("created")
        if not ts:
            continue
        try:
            updated = datetime.fromisoformat(str(ts))
            if (datetime.now() - updated).total_seconds() > TDD_STALE_THRESHOLD_HOURS * 3600:
                continue
        except (ValueError, TypeError):
            continue

        conflicts.append({
            "name": name,
            "phase": phase,
            "phase_name": PHASE_NAMES.get(phase, phase),
        })

    return conflicts


def _is_stop_locked() -> bool:
    """Check if the stop-lock is active."""
    lock_path = Path(__file__).parent.parent / "stop_lock.json"
    if not lock_path.exists():
        return False
    try:
        lock = json.loads(lock_path.read_text())
        return lock.get("enabled", False)
    except (json.JSONDecodeError, Exception):
        return False


def _has_valid_override_token(workflow_name: str = None) -> bool:
    """Check if a valid override token exists for the given workflow."""
    try:
        from override_token import has_valid_token
        return has_valid_token(workflow_name)
    except ImportError:
        return False


@contextmanager
def _state_lock():
    """Exclusive file lock for workflow state read-modify-write operations.

    Uses fcntl.flock(LOCK_EX) on .claude/workflow_state.lock.
    Blocks until lock is acquired. Released automatically on exit.
    """
    lock_path = get_state_file().parent / "workflow_state.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    fd = None
    try:
        fd = open(lock_path, "w")
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        if fd is not None:
            fcntl.flock(fd, fcntl.LOCK_UN)
            fd.close()


# Short phase labels for iTerm2 tab title
PHASE_SHORT = {
    "phase0_idle": "",
    "phase1_context": "Ctx",
    "phase2_analyse": "Ana",
    "phase3_spec": "Spec",
    "phase4_approved": "OK",
    "phase5_tdd_red": "RED",
    "phase6_implement": "Impl",
    "phase6b_adversary": "Adv",
    "phase7_validate": "Val",
    "phase8_complete": "Done",
}


def _tty_path() -> str:
    """Return the TTY device path for the current session."""
    try:
        return os.ttyname(sys.stdout.fileno())
    except Exception:
        try:
            return os.ttyname(sys.stdin.fileno())
        except Exception:
            return os.environ.get("SSH_TTY", "unknown")


def _tty_id() -> str:
    """Eindeutige ID fuer das aktuelle TTY (per-Session)."""
    return hashlib.md5(_tty_path().encode()).hexdigest()[:8]


def session_active_name(state: dict = None) -> Optional[str]:
    """Return the active workflow name for the current session.

    Lookup order:
    1. session_workflows[_tty_id()] → session-specific
    2. active_workflow → global fallback (backward compat)

    Pure lookup — no side effects, no file I/O if state is provided.
    """
    if state is None:
        state = load_state()
    tty = _tty_id()
    entry = state.get("session_workflows", {}).get(tty)
    if entry:
        name = entry.get("workflow")
        if name and name in state.get("workflows", {}):
            return name
    return state.get("active_workflow")


def _set_session_entry(state: dict, name: Optional[str]) -> None:
    """Write or clear the session→workflow mapping.

    Must be called inside _state_lock(). Modifies state in-place.
    """
    if "session_workflows" not in state:
        state["session_workflows"] = {}
    tty = _tty_id()
    if name is None:
        state["session_workflows"].pop(tty, None)
    else:
        state["session_workflows"][tty] = {
            "workflow": name,
            "tty": _tty_path(),
        }


def _cleanup_stale_sessions(state: dict) -> None:
    """Remove session entries whose TTY no longer exists. In-place."""
    sessions = state.get("session_workflows", {})
    stale = [
        sid for sid, entry in sessions.items()
        if not Path(entry.get("tty", "")).exists()
        and entry.get("tty", "") != "unknown"
    ]
    for sid in stale:
        del sessions[sid]


def _update_iterm_title(workflow_name: str = None, phase: str = None):
    """Set iTerm2 tab title. Called only on phase transitions.
    Writes to /dev/tty (per-session) AND a per-TTY temp file
    so the PostToolUse hook can refresh the title."""
    if not workflow_name:
        title = os.path.basename(os.getcwd())
    else:
        short = (
            workflow_name
            .replace("feature-0", "F")
            .replace("feature-", "F:")
            .replace("bug-0", "B")
            .replace("bug-", "B:")
            .replace("sprint-", "S:")
        )
        phase_label = PHASE_SHORT.get(phase or "", "")
        title = f"{short} | {phase_label}" if phase_label else short

    # Per-TTY temp file fuer PostToolUse-Hook refresh
    try:
        Path(f"/tmp/claude_tab_title_{_tty_id()}").write_text(title)
    except Exception:
        pass

    # Direkt auf eigenes TTY schreiben
    try:
        with open("/dev/tty", "w") as tty:
            tty.write(f"\033]1;{title}\007")
            tty.flush()
    except Exception:
        pass


def get_state_file() -> Path:
    """Get the path to the workflow state file."""
    # Try to find project root via .git
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent / ".claude" / "workflow_state.json"
    return cwd / ".claude" / "workflow_state.json"


def load_state() -> dict:
    """Load the multi-workflow state file."""
    state_file = get_state_file()

    if not state_file.exists():
        return {
            "version": "2.0",
            "workflows": {},
            "active_workflow": None
        }

    with open(state_file, 'r') as f:
        state = json.load(f)

    # Migrate from v1 format if needed
    if "version" not in state:
        state = migrate_v1_to_v2(state)

    return state


def _save_state_unlocked(state: dict) -> None:
    """Save the workflow state (caller must hold _state_lock)."""
    state_file = get_state_file()
    state_file.parent.mkdir(parents=True, exist_ok=True)

    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2)


def save_state(state: dict) -> None:
    """Save the workflow state with exclusive file lock."""
    with _state_lock():
        _save_state_unlocked(state)


def migrate_v1_to_v2(v1_state: dict) -> dict:
    """Migrate from single-workflow (v1) to multi-workflow (v2) format."""
    # Map old phase names to new
    phase_mapping = {
        "idle": "phase0_idle",
        "analyse_done": "phase2_analyse",
        "spec_written": "phase3_spec",
        "spec_approved": "phase4_approved",
        "implemented": "phase6_implement",
        "validated": "phase7_validate",
    }

    old_phase = v1_state.get("current_phase", "idle")
    new_phase = phase_mapping.get(old_phase, "phase0_idle")

    feature_name = v1_state.get("feature_name")
    if not feature_name:
        return {
            "version": "2.0",
            "workflows": {},
            "active_workflow": None
        }

    # Create workflow entry from v1 data
    workflow = {
        "current_phase": new_phase,
        "created": v1_state.get("last_updated", datetime.now().isoformat()),
        "last_updated": v1_state.get("last_updated", datetime.now().isoformat()),
        "spec_file": v1_state.get("spec_file"),
        "spec_approved": v1_state.get("spec_approved", False),
        "context_file": None,
        "test_artifacts": [],
        "affected_files": [],
    }

    return {
        "version": "2.0",
        "workflows": {feature_name: workflow},
        "active_workflow": feature_name
    }


def create_workflow(name: str) -> dict:
    """Create a new workflow entry."""
    return {
        "current_phase": "phase1_context",
        "created": datetime.now().isoformat(),
        "last_updated": datetime.now().isoformat(),
        "spec_file": None,
        "spec_approved": False,
        "context_file": None,
        "test_artifacts": [],
        "affected_files": [],
        # Visual inspection (v2.4) - PFLICHT for bug workflows
        "visual_inspection_done": False,
        "visual_inspection_notes": None,  # What was observed
        # User expectation (v2.5) - PFLICHT for feature workflows
        "user_expectation_done": False,
        "user_expectation_notes": None,  # What the user-advocate described
        # Result inspection (v2.5) - PFLICHT for features after implementation
        "result_inspection_done": False,
        "result_inspection_notes": None,  # Fresh-eyes comparison
        # Separate RED/GREEN tracking for UNIT tests (v2.0)
        "red_test_done": False,
        "red_test_result": None,  # Description of the failing test
        "green_test_done": False,
        "green_test_result": None,  # Description of passing tests
        # Separate RED/GREEN tracking for UI tests (v2.2)
        "ui_test_red_done": False,
        "ui_test_red_result": None,  # Description of failing UI test
        "ui_test_green_done": False,
        "ui_test_green_result": None,  # Description of passing UI tests
        # Analysis findings
        "analysis_findings": None,
        # Phases completed history
        "phases_completed": [],
        # Backlog status (v2.1) - separate from phase
        # open | spec_ready | in_progress | done | blocked
        "backlog_status": "open",
        # Adversary verdict (v2.3) - must be "VERIFIED:<reason>" to allow commit
        "adversary_verdict": None,
    }


def start_workflow(name: str, make_active: bool = True) -> dict:
    """Start a new workflow or resume existing one."""
    with _state_lock():
        state = load_state()

        if name not in state["workflows"]:
            state["workflows"][name] = create_workflow(name)

        if make_active:
            state["active_workflow"] = name
            _set_session_entry(state, name)

        _save_state_unlocked(state)

    if make_active:
        phase = state["workflows"][name].get("current_phase", "phase1_context")
        _update_iterm_title(name, phase)

    return state


def get_active_workflow() -> Optional[dict]:
    """Get the currently active workflow (session-aware)."""
    state = load_state()
    active_name = session_active_name(state)

    if not active_name or active_name not in state.get("workflows", {}):
        return None

    workflow = state["workflows"][active_name]
    workflow["name"] = active_name
    return workflow


def set_active_workflow(name: str) -> bool:
    """Switch to a different workflow (session-aware)."""
    with _state_lock():
        state = load_state()

        if name not in state["workflows"]:
            return False

        state["active_workflow"] = name
        _set_session_entry(state, name)
        _save_state_unlocked(state)

    phase = state["workflows"][name].get("current_phase", "phase0_idle")
    _update_iterm_title(name, phase)
    return True


def _validate_phase_prerequisites(workflow: dict, current_phase: str, target_phase: str) -> tuple[bool, str]:
    """
    Validate that the current phase is completed before allowing transition.
    Called by both advance_phase() and set_phase().

    Returns:
        (allowed, reason) - allowed=True if transition is ok, reason explains why not
    """
    # phase0_idle has no prerequisites (reset always allowed)
    if current_phase == "phase0_idle":
        return True, ""

    if current_phase == "phase1_context":
        ctx = workflow.get("context_file")
        if not ctx:
            return False, "phase1_context nicht abgeschlossen: context_file nicht gesetzt"
        if not Path(ctx).exists():
            return False, f"phase1_context nicht abgeschlossen: context_file existiert nicht: {ctx}"

    elif current_phase == "phase2_analyse":
        findings = workflow.get("analysis_findings")
        if not findings:
            return False, "phase2_analyse nicht abgeschlossen: analysis_findings nicht gesetzt"

    elif current_phase == "phase3_spec":
        spec = workflow.get("spec_file")
        if not spec:
            return False, "phase3_spec nicht abgeschlossen: spec_file nicht gesetzt"
        if not Path(spec).exists():
            return False, f"phase3_spec nicht abgeschlossen: spec_file existiert nicht: {spec}"

    elif current_phase == "phase4_approved":
        if not workflow.get("spec_approved"):
            return False, "phase4_approved nicht abgeschlossen: spec_approved ist nicht True"

    elif current_phase == "phase5_tdd_red":
        missing = []
        if not workflow.get("red_test_done"):
            missing.append("red_test_done")
        if not workflow.get("ui_test_red_done"):
            missing.append("ui_test_red_done")
        if missing:
            return False, f"phase5_tdd_red nicht abgeschlossen: {', '.join(missing)} fehlt"

    elif current_phase == "phase6_implement":
        # Validation for leaving phase6 → phase6b_adversary
        missing = []
        if not workflow.get("red_test_done"):
            missing.append("Unit RED")
        if not workflow.get("green_test_done"):
            missing.append("Unit GREEN")
        if not workflow.get("ui_test_red_done"):
            missing.append("UI RED")
        if not workflow.get("ui_test_green_done"):
            missing.append("UI GREEN")
        if missing:
            return False, f"phase6_implement nicht abgeschlossen: {', '.join(missing)} fehlt"

    elif current_phase == "phase6b_adversary":
        verdict = workflow.get("adversary_verdict")
        if not verdict:
            return False, "phase6b_adversary nicht abgeschlossen: adversary_verdict fehlt"
        if not str(verdict).startswith("VERIFIED"):
            return False, f"phase6b_adversary nicht abgeschlossen: adversary_verdict={verdict}"

    elif current_phase == "phase7_validate":
        missing = []
        if not workflow.get("result_inspection_done"):
            missing.append("result_inspection_done")
        if not workflow.get("docs_updated"):
            missing.append("docs_updated (ACTIVE-todos.md + ggf. CLAUDE.md)")
        if missing:
            return False, f"phase7_validate nicht abgeschlossen: {', '.join(missing)} fehlt"

    return True, ""


def advance_phase(workflow_name: str = None) -> Optional[str]:
    """Advance the workflow to the next phase. No override needed for sequential progression."""
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active. Cannot advance phase.", file=sys.stderr)
        return None

    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return None

        workflow = state["workflows"][name]
        current_phase = workflow["current_phase"]

        try:
            current_index = PHASES.index(current_phase)
            if current_index < len(PHASES) - 1:
                new_phase = PHASES[current_index + 1]

                # Phase prerequisite validation (skip with override token)
                if not _has_valid_override_token(name):
                    allowed, reason = _validate_phase_prerequisites(workflow, current_phase, new_phase)
                    if not allowed:
                        print(f"BLOCKED: {reason}", file=sys.stderr)
                        return None

                # Parallel TDD conflict check before entering TDD phases
                if new_phase in TDD_BLOCKING_PHASES:
                    conflicts = _get_conflicting_tdd_workflows(name)
                    if conflicts:
                        names = ", ".join(f"'{c['name']}' ({c['phase_name']})" for c in conflicts)
                        print(
                            f"BLOCKED: Paralleler TDD-Konflikt! "
                            f"Andere Workflows in TDD-Phasen: {names}. "
                            f"Warte bis diese fertig sind.",
                            file=sys.stderr,
                        )
                        return None

                workflow["current_phase"] = new_phase
                workflow["last_updated"] = datetime.now().isoformat()
                _save_state_unlocked(state)
                _update_iterm_title(name, new_phase)
                return new_phase
        except ValueError:
            pass

        return None


def set_phase(workflow_name: str, phase: str, force: bool = False) -> tuple[bool, str]:
    """
    Set a specific phase for a workflow.

    Args:
        workflow_name: Name of the workflow
        phase: Target phase
        force: If True, skip validation checks (CLI only)

    Returns:
        (success, message) tuple
    """
    if _is_stop_locked():
        return False, "Stop-lock active. Cannot set phase."

    if phase not in PHASES:
        return False, f"Invalid phase: {phase}"

    with _state_lock():
        state = load_state()

        if workflow_name not in state["workflows"]:
            return False, f"Workflow not found: {workflow_name}"

        workflow = state["workflows"][workflow_name]

        has_override = _has_valid_override_token(workflow_name)

        if not force:
            current_phase = workflow.get("current_phase", "phase0_idle")
            try:
                current_idx = PHASES.index(current_phase)
                target_idx = PHASES.index(phase)

                # Backwards jumping: only phase0_idle (reset) allowed without override
                if target_idx < current_idx:
                    if phase != "phase0_idle" and not has_override:
                        return False, (
                            f"Rueckwaerts-Sprung von {current_phase} nach {phase} "
                            f"nur zu phase0_idle (Reset) erlaubt. Override noetig fuer andere Ziele."
                        )

                # Forward: require override when skipping phases
                if target_idx > current_idx + 1 and not has_override:
                    skipped = PHASES[current_idx + 1:target_idx]
                    skipped_names = [PHASE_NAMES.get(p, p) for p in skipped]
                    return False, f"Override required: skipping phases ({', '.join(skipped_names)})"

                # Phase prerequisite validation for all intermediate phases
                if target_idx > current_idx and not has_override:
                    for step_idx in range(current_idx, target_idx):
                        step_phase = PHASES[step_idx]
                        allowed, reason = _validate_phase_prerequisites(workflow, step_phase, PHASES[step_idx + 1])
                        if not allowed:
                            return False, reason

            except ValueError:
                pass

        # Parallel TDD conflict check: block entering TDD phases when another workflow is active there
        if phase in TDD_BLOCKING_PHASES and not force:
            conflicts = _get_conflicting_tdd_workflows(workflow_name)
            if conflicts:
                names = ", ".join(f"'{c['name']}' ({c['phase_name']})" for c in conflicts)
                return False, (
                    f"BLOCKED: Paralleler TDD-Konflikt! "
                    f"Andere Workflows in TDD-Phasen: {names}. "
                    f"Warte bis diese fertig sind oder wechsle zum aktiven Workflow."
                )

        state["workflows"][workflow_name]["current_phase"] = phase
        state["workflows"][workflow_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

    _update_iterm_title(workflow_name, phase)
    return True, f"Phase set to {phase}"


def add_test_artifact(workflow_name: str, artifact: dict) -> bool:
    """
    Add a test artifact to a workflow.

    Artifact format:
    {
        "type": "screenshot" | "email" | "api_response" | "log" | "file",
        "path": "/path/to/artifact",
        "description": "What this artifact proves",
        "created": "ISO timestamp",
        "phase": "phase5_tdd_red" | "phase7_validate"
    }
    """
    with _state_lock():
        state = load_state()

        if workflow_name not in state["workflows"]:
            return False

        artifact["created"] = datetime.now().isoformat()
        state["workflows"][workflow_name]["test_artifacts"].append(artifact)
        state["workflows"][workflow_name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)
        return True


def get_workflow_status(name: str = None) -> str:
    """Get a human-readable status for a workflow."""
    state = load_state()

    workflow_name = name or session_active_name(state)
    if not workflow_name or workflow_name not in state["workflows"]:
        return "No active workflow"

    workflow = state["workflows"][workflow_name]
    phase = workflow["current_phase"]
    phase_name = PHASE_NAMES.get(phase, phase)

    # Get backlog status (explicit or derived)
    backlog = workflow.get("backlog_status") or derive_backlog_status(phase)
    backlog_name = BACKLOG_STATUS_NAMES.get(backlog, backlog)

    lines = [
        f"Workflow: {workflow_name}",
        f"Phase: {phase_name}",
        f"Backlog Status: {backlog_name}",
        f"Spec: {workflow.get('spec_file') or 'Not created'}",
        f"Approved: {'Yes' if workflow.get('spec_approved') else 'No'}",
        f"Test Artifacts: {len(workflow.get('test_artifacts', []))}",
    ]

    return "\n".join(lines)


def list_workflows() -> list:
    """List all workflows with their current phase and backlog status."""
    state = load_state()
    active = session_active_name(state)

    result = []
    for name, workflow in state.get("workflows", {}).items():
        # Get backlog status (explicit or derived from phase)
        backlog = workflow.get("backlog_status") or derive_backlog_status(workflow["current_phase"])

        result.append({
            "name": name,
            "phase": workflow["current_phase"],
            "phase_name": PHASE_NAMES.get(workflow["current_phase"], "Unknown"),
            "backlog_status": backlog,
            "backlog_status_name": BACKLOG_STATUS_NAMES.get(backlog, backlog),
            "is_active": name == active,
            "last_updated": workflow.get("last_updated"),
        })

    return sorted(result, key=lambda x: x["last_updated"] or "", reverse=True)


def can_modify_code(workflow_name: str = None) -> tuple[bool, str]:
    """
    Check if code modification is allowed for a workflow.
    Returns (allowed, reason).
    """
    state = load_state()

    name = workflow_name or session_active_name(state)
    if not name:
        return False, "No active workflow. Start with /01-context or /02-analyse."

    if name not in state["workflows"]:
        return False, f"Workflow '{name}' not found."

    workflow = state["workflows"][name]
    phase = workflow["current_phase"]

    if phase not in CODE_MODIFY_PHASES:
        return False, f"Current phase is {PHASE_NAMES.get(phase, phase)}. Code modification requires phase6_implement or later."

    # Check for test artifacts in TDD phases
    if phase in TEST_REQUIRED_PHASES:
        artifacts = workflow.get("test_artifacts", [])
        red_artifacts = [a for a in artifacts if a.get("phase") == "phase5_tdd_red"]

        if not red_artifacts:
            return False, "TDD RED phase incomplete. You must write and run failing tests with REAL test data first."

    return True, "OK"


def find_workflow_for_file(file_path: str) -> list[tuple[str, dict]]:
    """
    Find workflows that claim a file in their affected_files.

    Searches all workflows in CODE_MODIFY_PHASES (phase6+).
    Returns list of (workflow_name, workflow_dict) sorted by last_updated (newest first).
    """
    state = load_state()
    matches = []

    normalized_file = file_path.replace("./", "")

    for name, workflow in state.get("workflows", {}).items():
        phase = workflow.get("current_phase", "phase0_idle")
        if phase not in CODE_MODIFY_PHASES:
            continue

        affected_files = workflow.get("affected_files", [])
        if not affected_files:
            continue

        normalized_affected = [f.replace("./", "") for f in affected_files]

        for affected in normalized_affected:
            # Exact match
            if normalized_file == affected:
                matches.append((name, workflow))
                break
            # Path suffix match (absolute vs relative)
            if normalized_file.endswith("/" + affected) or normalized_file.endswith(affected):
                matches.append((name, workflow))
                break
            # Glob pattern
            if "*" in affected:
                import re as _re
                regex_pattern = affected.replace("*", ".*")
                if _re.match(regex_pattern, normalized_file):
                    matches.append((name, workflow))
                    break

    # Sort by last_updated descending (most recently active first)
    matches.sort(key=lambda x: x[1].get("last_updated", ""), reverse=True)
    return matches


def complete_workflow(name: str) -> bool:
    """Mark a workflow as complete and archive it. Validates prerequisites first."""
    with _state_lock():
        state = load_state()

        if name not in state["workflows"]:
            return False

        workflow = state["workflows"][name]

        # Validate phase7_validate prerequisites before completing
        if not _has_valid_override_token(name):
            current_phase = workflow.get("current_phase", "phase0_idle")
            allowed, reason = _validate_phase_prerequisites(workflow, current_phase, "phase8_complete")
            if not allowed:
                print(f"BLOCKED: {reason}", file=sys.stderr)
                return False

        state["workflows"][name]["current_phase"] = "phase8_complete"
        state["workflows"][name]["backlog_status"] = "done"  # Explicitly set to done
        state["workflows"][name]["user_override"] = False  # Remove override on completion
        state["workflows"][name]["last_updated"] = datetime.now().isoformat()

        # If this was the active workflow, clear it (don't auto-switch to random workflow)
        if state.get("active_workflow") == name:
            state["active_workflow"] = None

        # NOTE: Do NOT clear session_workflows entries here.
        # The session still needs to know its workflow for post-completion
        # actions (e.g. git commit). Stale entries are cleaned up by
        # _cleanup_stale_sessions() when the TTY disappears.

        _save_state_unlocked(state)

    # Show project name when no active workflow
    _update_iterm_title()
    return True


def purge_completed() -> list[str]:
    """Remove all completed workflows from state. Returns list of purged names."""
    with _state_lock():
        state = load_state()
        purged = []
        active = state.get("active_workflow")

        for name in list(state.get("workflows", {}).keys()):
            wf = state["workflows"][name]
            if wf.get("current_phase") == "phase8_complete" and name != active:
                del state["workflows"][name]
                purged.append(name)

        # Clean session_workflows pointing to purged workflows
        for sid in list(state.get("session_workflows", {}).keys()):
            if state["session_workflows"][sid].get("workflow") in purged:
                del state["session_workflows"][sid]

        if purged:
            _save_state_unlocked(state)

    return purged


def mark_red_test_done(workflow_name: str = None, result: str = None) -> bool:
    """
    Mark RED test as done for a workflow.

    Args:
        workflow_name: Name of workflow (uses active if None)
        result: Description of the failing test result
    """
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active. Cannot mark red test done.", file=sys.stderr)
        return False

    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        # Override only required if no test result is provided (prevents marking without evidence)
        if not result and not _has_valid_override_token(name):
            print(f"BLOCKED: Override required for mark_red_test_done without result. Workflow: {name}", file=sys.stderr)
            return False

        workflow = state["workflows"][name]
        workflow["red_test_done"] = True
        workflow["red_test_result"] = result
        workflow["last_updated"] = datetime.now().isoformat()

        # Auto-advance to phase5 if in phase4 (with parallel TDD check)
        if workflow["current_phase"] == "phase4_approved":
            conflicts = _get_conflicting_tdd_workflows(name)
            if conflicts:
                names = ", ".join(f"'{c['name']}' ({c['phase_name']})" for c in conflicts)
                print(
                    f"BLOCKED: Paralleler TDD-Konflikt! "
                    f"Andere Workflows in TDD-Phasen: {names}. "
                    f"Warte bis diese fertig sind.",
                    file=sys.stderr,
                )
                return False
            workflow["current_phase"] = "phase5_tdd_red"
            if "phase5_tdd_red" not in workflow.get("phases_completed", []):
                workflow.setdefault("phases_completed", []).append("phase5_tdd_red")
            _save_state_unlocked(state)
            _update_iterm_title(name, "phase5_tdd_red")
            return True

        _save_state_unlocked(state)
        return True


def mark_green_test_done(workflow_name: str = None, result: str = None) -> bool:
    """
    Mark GREEN test as done for a workflow.

    Args:
        workflow_name: Name of workflow (uses active if None)
        result: Description of passing tests
    """
    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        workflow = state["workflows"][name]
        workflow["green_test_done"] = True
        workflow["green_test_result"] = result
        workflow["last_updated"] = datetime.now().isoformat()

        # Auto-advance to phase6b_adversary if in phase6 (adversary must verify before validate)
        if workflow["current_phase"] == "phase6_implement":
            workflow["current_phase"] = "phase6b_adversary"
            if "phase6b_adversary" not in workflow.get("phases_completed", []):
                workflow.setdefault("phases_completed", []).append("phase6b_adversary")
            _save_state_unlocked(state)
            _update_iterm_title(name, "phase6b_adversary")
            return True

        _save_state_unlocked(state)
        return True


def get_tdd_status(workflow_name: str = None) -> dict:
    """
    Get TDD status for a workflow.

    Returns dict with:
        red_done: bool (unit tests)
        red_result: str or None
        green_done: bool (unit tests)
        green_result: str or None
        ui_test_red_done: bool
        ui_test_red_result: str or None
        ui_test_green_done: bool
        ui_test_green_result: str or None
        artifacts: list of test artifacts
    """
    workflow = get_active_workflow() if not workflow_name else None

    if workflow_name:
        state = load_state()
        workflow = state["workflows"].get(workflow_name)

    if not workflow:
        return {
            "red_done": False,
            "red_result": None,
            "green_done": False,
            "green_result": None,
            "ui_test_red_done": False,
            "ui_test_red_result": None,
            "ui_test_green_done": False,
            "ui_test_green_result": None,
            "artifacts": [],
        }

    return {
        "red_done": workflow.get("red_test_done", False),
        "red_result": workflow.get("red_test_result"),
        "green_done": workflow.get("green_test_done", False),
        "green_result": workflow.get("green_test_result"),
        "ui_test_red_done": workflow.get("ui_test_red_done", False),
        "ui_test_red_result": workflow.get("ui_test_red_result"),
        "ui_test_green_done": workflow.get("ui_test_green_done", False),
        "ui_test_green_result": workflow.get("ui_test_green_result"),
        "artifacts": workflow.get("test_artifacts", []),
    }


def mark_ui_test_red_done(workflow_name: str = None, result: str = None) -> bool:
    """
    Mark UI test RED as done for a workflow.

    Args:
        workflow_name: Name of workflow (uses active if None)
        result: Description of the failing UI test result
    """
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active. Cannot mark UI test red done.", file=sys.stderr)
        return False

    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        # Override only required if no test result is provided (prevents marking without evidence)
        if not result and not _has_valid_override_token(name):
            print(f"BLOCKED: Override required for mark_ui_test_red_done without result. Workflow: {name}", file=sys.stderr)
            return False

        workflow = state["workflows"][name]
        workflow["ui_test_red_done"] = True
        workflow["ui_test_red_result"] = result
        workflow["last_updated"] = datetime.now().isoformat()

        _save_state_unlocked(state)
        return True


def mark_ui_test_green_done(workflow_name: str = None, result: str = None) -> bool:
    """
    Mark UI test GREEN as done for a workflow.

    Args:
        workflow_name: Name of workflow (uses active if None)
        result: Description of passing UI tests
    """
    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        workflow = state["workflows"][name]
        workflow["ui_test_green_done"] = True
        workflow["ui_test_green_result"] = result
        workflow["last_updated"] = datetime.now().isoformat()

        _save_state_unlocked(state)
        return True


def mark_docs_updated(workflow_name: str = None, details: str = None) -> bool:
    """
    Mark documentation as updated for a workflow.

    Args:
        workflow_name: Name of workflow (uses active if None)
        details: Description of what was updated (e.g. "ACTIVE-todos.md: status → done")
    """
    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        workflow = state["workflows"][name]
        workflow["docs_updated"] = True
        workflow["docs_updated_details"] = details
        workflow["last_updated"] = datetime.now().isoformat()

        _save_state_unlocked(state)
        return True


def are_all_tests_complete(workflow_name: str = None) -> tuple[bool, str]:
    """
    Check if all required tests (unit + UI) are complete for validation phase.

    Returns (complete, reason).
    """
    state = load_state()

    name = workflow_name or session_active_name(state)
    if not name or name not in state["workflows"]:
        return False, "No active workflow"

    workflow = state["workflows"][name]

    # Check unit tests
    if not workflow.get("red_test_done", False):
        return False, "Unit test RED phase not complete"
    if not workflow.get("green_test_done", False):
        return False, "Unit test GREEN phase not complete"

    # Check UI tests
    if not workflow.get("ui_test_red_done", False):
        return False, "UI test RED phase not complete"
    if not workflow.get("ui_test_green_done", False):
        return False, "UI test GREEN phase not complete"

    return True, "All tests complete"


def derive_backlog_status(phase: str) -> str:
    """
    Derive the appropriate backlog status from a workflow phase.

    Returns the backlog status that corresponds to the given phase.
    """
    return PHASE_TO_BACKLOG_STATUS.get(phase, "open")


def get_backlog_status(workflow_name: str = None) -> str:
    """
    Get the backlog status for a workflow.

    Returns the explicit backlog_status if set, otherwise derives from phase.
    """
    state = load_state()

    name = workflow_name or session_active_name(state)
    if not name or name not in state["workflows"]:
        return "open"

    workflow = state["workflows"][name]

    # Return explicit status if set
    if workflow.get("backlog_status"):
        return workflow["backlog_status"]

    # Otherwise derive from phase
    return derive_backlog_status(workflow["current_phase"])


def set_backlog_status(status: str, workflow_name: str = None) -> bool:
    """
    Explicitly set the backlog status for a workflow.

    Args:
        status: One of: open, spec_ready, in_progress, done, blocked
        workflow_name: Name of workflow (uses active if None)

    Returns:
        True if successful, False otherwise.
    """
    if status not in BACKLOG_STATUSES:
        return False

    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        state["workflows"][name]["backlog_status"] = status
        state["workflows"][name]["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)
        return True


def is_pause_message(message: str) -> bool:
    """
    Check if a message indicates the user wants to pause the workflow.

    Returns True if pause intent detected.
    """
    message_lower = message.lower().strip()

    for phrase in PAUSE_PHRASES:
        if phrase in message_lower:
            return True

    return False


def pause_workflow(workflow_name: str = None) -> tuple[bool, str]:
    """
    Pause a workflow and set appropriate backlog status.

    If the workflow is in phase4_approved or later (but not complete),
    sets status to 'spec_ready'. Otherwise keeps current status.

    Returns:
        (success, message) tuple
    """
    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False, "No active workflow to pause."

        workflow = state["workflows"][name]
        phase = workflow["current_phase"]
        phase_index = PHASES.index(phase) if phase in PHASES else 0

        # Determine appropriate backlog status based on progress
        if phase == "phase8_complete":
            return False, "Workflow already complete."
        elif phase_index >= PHASES.index("phase4_approved"):
            # Spec is approved but not implemented -> spec_ready
            workflow["backlog_status"] = "spec_ready"
            status_msg = "spec_ready"
        else:
            # Still in early phases -> open
            workflow["backlog_status"] = "open"
            status_msg = "open"

        workflow["last_updated"] = datetime.now().isoformat()
        _save_state_unlocked(state)

        return True, f"Workflow '{name}' paused. Backlog status: {status_msg}"


def sync_backlog_status_from_phase(workflow_name: str = None) -> bool:
    """
    Synchronize backlog status based on current phase.

    Call this when phase changes to keep backlog status in sync
    (unless manually overridden).
    """
    with _state_lock():
        state = load_state()

        name = workflow_name or session_active_name(state)
        if not name or name not in state["workflows"]:
            return False

        workflow = state["workflows"][name]
        phase = workflow["current_phase"]

        # Only auto-sync if not manually set to blocked
        if workflow.get("backlog_status") != "blocked":
            workflow["backlog_status"] = derive_backlog_status(phase)
            workflow["last_updated"] = datetime.now().isoformat()
            _save_state_unlocked(state)

        return True


if __name__ == "__main__":
    # CLI interface for testing
    import sys

    if len(sys.argv) < 2:
        print("Usage: workflow_state_multi.py <command> [args]")
        print("Commands: status, list, start <name>, switch <name>, advance, phase <phase>, backlog <status>, set-field <field> <value>, purge, pause")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "status":
        print(get_workflow_status())
    elif cmd == "list":
        for w in list_workflows():
            marker = "→ " if w["is_active"] else "  "
            print(f"{marker}{w['name']}: {w['phase_name']} [{w['backlog_status_name']}]")
    elif cmd == "start" and len(sys.argv) > 2:
        start_workflow(sys.argv[2])
        print(f"Started workflow: {sys.argv[2]}")
    elif cmd == "switch" and len(sys.argv) > 2:
        if set_active_workflow(sys.argv[2]):
            print(f"Switched to: {sys.argv[2]}")
        else:
            print(f"Workflow not found: {sys.argv[2]}")
    elif cmd == "advance":
        new_phase = advance_phase()
        if new_phase:
            print(f"Advanced to: {PHASE_NAMES.get(new_phase, new_phase)}")
        else:
            print("Cannot advance further")
    elif cmd == "phase" and len(sys.argv) > 2:
        state = load_state()
        active = session_active_name(state)
        if active:
            target_phase = sys.argv[2]
            # Use complete_workflow() for phase8_complete to ensure proper cleanup
            if target_phase == "phase8_complete":
                if complete_workflow(active):
                    print(f"Workflow '{active}' completed and archived.")
                else:
                    print(f"Failed to complete workflow '{active}'")
            else:
                # --force flag removed: phase skipping is no longer allowed via CLI
                success, message = set_phase(active, target_phase, force=False)
                if success:
                    # Sync backlog status when phase changes
                    sync_backlog_status_from_phase(active)
                    print(f"Set phase to: {target_phase}")
                else:
                    print(f"BLOCKED: {message}")
        else:
            print(f"No active workflow")
    elif cmd == "backlog" and len(sys.argv) > 2:
        status = sys.argv[2]
        if set_backlog_status(status):
            print(f"Set backlog status to: {BACKLOG_STATUS_NAMES.get(status, status)}")
        else:
            print(f"Failed to set backlog status: {status}")
            print(f"Valid options: {', '.join(BACKLOG_STATUSES)}")
    elif cmd == "set-field" and len(sys.argv) > 3:
        field_name = sys.argv[2]
        # Security-critical fields that CANNOT be set via set-field
        # These fields are managed by specific workflow phases/gates
        BLOCKED_SET_FIELDS = {
            "current_phase",        # Managed by phase/advance commands
            "red_test_done",        # Managed by TDD RED phase
            "ui_test_red_done",     # Managed by TDD RED phase
            "ui_test_red_result",   # Managed by TDD RED phase
            "green_test_done",      # Managed by TDD GREEN phase
            "ui_test_green_done",   # Managed by TDD GREEN phase
            "ui_test_green_result", # Managed by TDD GREEN phase
            "spec_approved",        # Managed by spec approval gate
            "adversary_verdict",    # Managed by adversary_gate.py
            "adversary_details",    # Managed by adversary_gate.py
            "affected_files",       # Managed by spec/analyse phase
            "test_artifacts",       # Managed by /09-add-artifact
            "user_override",        # Managed by override_token_listener
            "phases_completed",     # Managed by phase transitions
            "visual_inspection_done",       # Managed by fresh-eyes-inspector
            "visual_inspection_notes",      # Managed by fresh-eyes-inspector
            "user_expectation_done",        # Managed by user-advocate
            "user_expectation_notes",       # Managed by user-advocate
            "result_inspection_done",       # Managed by fresh-eyes-inspector
            "result_inspection_notes",      # Managed by fresh-eyes-inspector
            "docs_updated",                 # Managed by mark_docs_updated()
            "docs_updated_details",         # Managed by mark_docs_updated()
        }
        if field_name in BLOCKED_SET_FIELDS:
            print(f"BLOCKED: '{field_name}' cannot be set via set-field.")
            print(f"This field is managed by its respective workflow phase/gate.")
            print(f"Blocked fields: {', '.join(sorted(BLOCKED_SET_FIELDS))}")
            sys.exit(1)
        field_value = sys.argv[3]
        with _state_lock():
            state = load_state()
            active = session_active_name(state)
            if active and active in state.get("workflows", {}):
                state["workflows"][active][field_name] = field_value
                state["workflows"][active]["last_updated"] = datetime.now().isoformat()
                _save_state_unlocked(state)
                print(f"Set {field_name} = {field_value} on workflow {active}")
            else:
                print("No active workflow")
    elif cmd == "mark-docs-updated":
        details = sys.argv[2] if len(sys.argv) > 2 else None
        if mark_docs_updated(details=details):
            print(f"Docs marked as updated: {details or '(no details)'}")
        else:
            print("Failed to mark docs as updated")
    elif cmd == "purge":
        purged = purge_completed()
        if purged:
            print(f"Purged {len(purged)} completed workflows:")
            for name in purged:
                print(f"  - {name}")
        else:
            print("No completed workflows to purge.")
    elif cmd == "pause":
        success, message = pause_workflow()
        print(message)
    else:
        print(f"Unknown command: {cmd}")
