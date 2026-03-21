#!/usr/bin/env python3
"""
Inspection Gate — Proof-Based Screenshot Validator

Sets visual/result inspection fields ONLY when a real screenshot file is provided,
OR when an override with justification is given.

Usage:
    python3 .claude/hooks/inspection_gate.py before <screenshot-path>
    python3 .claude/hooks/inspection_gate.py after <screenshot-path>
    python3 .claude/hooks/inspection_gate.py override before "<reason>"
    python3 .claude/hooks/inspection_gate.py override after "<reason>"

Screenshot Validation:
- Screenshot file must exist
- Must be < 15 minutes old (not recycled from earlier)
- Must be > 10KB (real image, not placeholder)
- Must have image extension (.png/.jpg/.jpeg/.tiff)

Override Mode:
- Requires a non-empty justification (min 10 chars)
- Sets inspection fields with override_reason instead of screenshot

On success:
- 'before' sets visual_inspection_done + visual_inspection_screenshot (or override_reason)
- 'after' sets result_inspection_done + result_inspection_screenshot (or override_reason)
"""

import json
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    from workflow_state_multi import session_active_name as _session_active_name
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import session_active_name as _session_active_name
    except ImportError:
        def _session_active_name(state):
            return state.get("active_workflow")


MAX_AGE_MINUTES = 15
MIN_SIZE_BYTES = 10_000
VALID_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.tiff'}
MIN_OVERRIDE_REASON_LENGTH = 10


def get_state_file() -> Path:
    """Find workflow state file."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        candidate = parent / ".claude" / "workflow_state.json"
        if candidate.exists():
            return candidate
    return cwd / ".claude" / "workflow_state.json"


def load_state() -> dict:
    state_file = get_state_file()
    if not state_file.exists():
        return {}
    with open(state_file, 'r') as f:
        return json.load(f)


def save_state(state: dict):
    state_file = get_state_file()
    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2)


def validate_screenshot(filepath: str) -> tuple[bool, str]:
    """Validate that a screenshot file is real, recent, and substantial."""
    path = Path(filepath)

    if not path.exists():
        return False, f"File not found: {filepath}"

    # Check extension
    suffix = path.suffix.lower()
    if suffix not in VALID_EXTENSIONS:
        return False, f"Not an image file (got {suffix}). Must be .png/.jpg/.jpeg/.tiff"

    # Check age
    mtime = path.stat().st_mtime
    age_minutes = (time.time() - mtime) / 60
    if age_minutes > MAX_AGE_MINUTES:
        return False, f"Screenshot is {age_minutes:.0f} min old (max {MAX_AGE_MINUTES} min). Take a fresh one."

    # Check size
    size = path.stat().st_size
    if size < MIN_SIZE_BYTES:
        return False, f"Screenshot too small ({size} bytes). Looks like a placeholder, not a real screenshot."

    return True, f"Valid screenshot: {filepath} ({size:,} bytes, {age_minutes:.1f} min old)"


def set_inspection_fields(gate_type: str, state: dict, active: str, *,
                          screenshot_path: str = None, override_reason: str = None):
    """Set inspection fields on the active workflow."""
    workflow = state["workflows"][active]

    if gate_type == "before":
        workflow["visual_inspection_done"] = True
        if screenshot_path:
            workflow["visual_inspection_screenshot"] = screenshot_path
        if override_reason:
            workflow["visual_inspection_override_reason"] = override_reason
        field_label = "Visual Inspection"
    else:
        workflow["result_inspection_done"] = True
        if screenshot_path:
            workflow["result_inspection_screenshot"] = screenshot_path
        if override_reason:
            workflow["result_inspection_override_reason"] = override_reason
        field_label = "Result Inspection"

    workflow["last_updated"] = datetime.now().isoformat()
    save_state(state)
    return field_label


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 inspection_gate.py <before|after> <screenshot-path>")
        print("       python3 inspection_gate.py override <before|after> <reason>")
        print()
        print("  before   — validates pre-analysis screenshot (visual inspection)")
        print("  after    — validates post-implementation screenshot (result inspection)")
        print("  override — skips screenshot, requires justification (min 10 chars)")
        sys.exit(1)

    # Override mode: inspection_gate.py override <before|after> <reason>
    if sys.argv[1] == "override":
        if len(sys.argv) < 4:
            print("Usage: python3 inspection_gate.py override <before|after> <reason>")
            sys.exit(1)

        gate_type = sys.argv[2]
        override_reason = " ".join(sys.argv[3:])

        if gate_type not in ("before", "after"):
            print(f"ERROR: Second argument must be 'before' or 'after', got '{gate_type}'")
            sys.exit(1)

        if len(override_reason.strip()) < MIN_OVERRIDE_REASON_LENGTH:
            print(f"ERROR: Override-Begruendung zu kurz (min {MIN_OVERRIDE_REASON_LENGTH} Zeichen).")
            print(f"Gegeben: '{override_reason.strip()}' ({len(override_reason.strip())} Zeichen)")
            sys.exit(1)

        state = load_state()
        active = _session_active_name(state)

        if not active or active not in state.get("workflows", {}):
            print("ERROR: No active workflow found.")
            sys.exit(1)

        field_label = set_inspection_fields(gate_type, state, active,
                                            override_reason=override_reason.strip())

        print(f"{field_label} OVERRIDE — Begruendung akzeptiert.")
        print(f"Workflow: {active}")
        print(f"Reason: {override_reason.strip()}")
        print(f"Fields updated. Gate is now open.")
        sys.exit(0)

    # Normal mode: inspection_gate.py <before|after> <screenshot-path>
    gate_type = sys.argv[1]
    screenshot_path = sys.argv[2]

    if gate_type not in ("before", "after"):
        print(f"ERROR: First argument must be 'before' or 'after', got '{gate_type}'")
        sys.exit(1)

    is_valid, reason = validate_screenshot(screenshot_path)

    if not is_valid:
        print(f"FAILED — {reason}")
        print()
        print("Take a real screenshot and try again.")
        print("Falls kein Screenshot moeglich → nutze Override-Modus:")
        print("  python3 .claude/hooks/inspection_gate.py override <before|after> <begruendung>")
        sys.exit(1)

    state = load_state()
    active = _session_active_name(state)

    if not active or active not in state.get("workflows", {}):
        print("ERROR: No active workflow found.")
        sys.exit(1)

    field_label = set_inspection_fields(gate_type, state, active,
                                        screenshot_path=screenshot_path)

    print(f"{field_label} PASSED — {reason}")
    print(f"Workflow: {active}")
    print(f"Fields updated. Gate is now open.")


if __name__ == "__main__":
    main()
