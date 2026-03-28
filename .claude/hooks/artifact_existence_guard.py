#!/usr/bin/env python3
"""
Artifact Existence Guard — Blocks phase transitions if registered artifacts don't exist.

Prevents the pattern where Claude "registers" an artifact in workflow state
but never actually creates the file. This happened with unit-test-green-output.txt.

Triggers on: workflow_state_multi.py phase <target_phase>
Checks: All test_artifacts in the workflow state must exist as real files
        with minimum size requirements.

Exit Codes:
- 0: Allowed
- 2: Blocked (missing/invalid artifacts)
"""

import json
import os
import sys
from pathlib import Path

try:
    from workflow_state_multi import session_active_name
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from workflow_state_multi import session_active_name
    except ImportError:
        def session_active_name(state):
            return state.get("active_workflow")

try:
    from override_token import has_valid_token
except ImportError:
    def has_valid_token(name):
        return False

# Minimum file sizes by artifact type
MIN_SIZES = {
    "screenshot": 1000,       # 1KB — real image
    "test_output": 10,        # 10B — real test log
    "ui_test_output": 10,     # 10B — real test log
    "log": 10,                # 10B — real log
    "video": 10000,           # 10KB — real video
    "api_response": 10,       # 10B
}

# Phases where artifact validation is enforced
ENFORCED_TRANSITIONS = {
    "phase7_validate",    # Entering validation — all artifacts must exist
    "phase8_complete",    # Completing — final check
}


def get_tool_input() -> dict:
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass
    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except Exception:
        return {}


def load_workflow_state() -> dict | None:
    state_file = Path(__file__).parent.parent / "workflow_state.json"
    if not state_file.exists():
        return None
    try:
        with open(state_file, 'r') as f:
            return json.load(f)
    except Exception:
        return None


def get_project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def main():
    tool_input = get_tool_input()
    command = tool_input.get("command", "")

    # Only trigger on phase transitions via workflow_state_multi.py
    if "workflow_state_multi.py" not in command or " phase " not in command:
        sys.exit(0)

    # Extract target phase from command
    parts = command.split()
    target_phase = None
    for i, part in enumerate(parts):
        if part == "phase" and i + 1 < len(parts):
            target_phase = parts[i + 1]
            break

    if not target_phase or target_phase not in ENFORCED_TRANSITIONS:
        sys.exit(0)

    state = load_workflow_state()
    if not state:
        sys.exit(0)

    workflows = state.get("workflows", {})
    active_name = session_active_name(state)
    if not active_name or active_name not in workflows:
        sys.exit(0)

    workflow = workflows[active_name]

    # Respect override token
    if workflow.get("user_override", False):
        sys.exit(0)
    if has_valid_token(active_name):
        sys.exit(0)

    # Check all registered artifacts
    artifacts = workflow.get("test_artifacts", [])
    if not artifacts:
        # No artifacts registered — other hooks handle this requirement
        sys.exit(0)

    project_root = get_project_root()
    missing = []
    too_small = []

    for artifact in artifacts:
        art_path = artifact.get("path", "")
        art_type = artifact.get("type", "unknown")

        if not art_path:
            continue

        # Resolve relative paths against project root
        full_path = Path(art_path)
        if not full_path.is_absolute():
            full_path = project_root / art_path

        if not full_path.exists():
            missing.append({
                "path": art_path,
                "type": art_type,
                "description": artifact.get("description", ""),
            })
            continue

        # Check minimum size
        min_size = MIN_SIZES.get(art_type, 10)
        actual_size = full_path.stat().st_size
        if actual_size < min_size:
            too_small.append({
                "path": art_path,
                "type": art_type,
                "actual_size": actual_size,
                "min_size": min_size,
            })

    if missing or too_small:
        print("=" * 70, file=sys.stderr)
        print("BLOCKED — Registrierte Artifacts existieren nicht!", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(file=sys.stderr)
        print(f"  Workflow: {active_name}", file=sys.stderr)
        print(f"  Transition zu: {target_phase}", file=sys.stderr)
        print(file=sys.stderr)

        if missing:
            print(f"  FEHLENDE DATEIEN ({len(missing)}):", file=sys.stderr)
            for m in missing:
                print(f"    - {m['path']} ({m['type']})", file=sys.stderr)
                if m['description']:
                    print(f"      Beschreibung: {m['description']}", file=sys.stderr)
            print(file=sys.stderr)

        if too_small:
            print(f"  ZU KLEINE DATEIEN ({len(too_small)}):", file=sys.stderr)
            for s in too_small:
                print(f"    - {s['path']} ({s['type']}): {s['actual_size']}B < {s['min_size']}B minimum", file=sys.stderr)
            print(file=sys.stderr)

        print("  Artifacts wurden im Workflow-State registriert, aber die", file=sys.stderr)
        print("  tatsaechlichen Dateien wurden nie erstellt.", file=sys.stderr)
        print(file=sys.stderr)
        print("  FIX: Erstelle die fehlenden Dateien mit echtem Inhalt,", file=sys.stderr)
        print("  oder entferne ungueltige Artifacts aus dem State.", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
