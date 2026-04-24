#!/usr/bin/env python3
"""
Edit Gate v3 — Consolidated PreToolUse Hook for Edit|Write

Replaces 17 separate hooks with 1. Sequential short-circuit logic:

1. Protected State Files → BLOCK
1b. Archived Backlog Files (ACTIVE-todos, ARCHIVE-todos, new todo/backlog/roadmap .md) → BLOCK
2. Always-Allowed (docs, tests, scripts, .md, .json) → ALLOW
3. Not code file → ALLOW
4. Infrastructure (.claude/hooks/) → Override token check
5. Stop-Lock → BLOCK
6. Find workflow for file (affected_files)
7. No workflow → BLOCK
8. Phase < phase6_implement → BLOCK
9. Override token → ALLOW (skip TDD check)
10. RED test artifacts → BLOCK if missing
11. ALLOW

Exit Codes: 0 = allowed, 2 = blocked
"""

import json
import os
import re
import sys
from pathlib import Path

from hook_utils import (
    _project_root,
    _read_workflow_locked,
    read_active_workflow,
)

# Session ID extracted from stdin JSON (set during main())
_STDIN_SESSION_ID = ""

# --- Configuration ---

CODE_EXTENSIONS = {
    ".swift", ".kt", ".java", ".py", ".js", ".ts", ".tsx", ".jsx",
    ".go", ".rs", ".cpp", ".c", ".h", ".hpp",
}

ALWAYS_ALLOWED_DIRS = [
    "docs/", ".claude/commands/", "scripts/", "tools/",
]

ALWAYS_ALLOWED_PATTERNS = [
    r"\.md$", r"\.txt$", r"\.json$", r"\.yaml$", r"\.yml$",
    r"\.gitignore$", r"README", r"CHANGELOG", r"LICENSE",
]

PROTECTED_STATE_FILES = [
    ".claude/workflows/", "workflow_state.json", "user_override_token.json",
    "ui_test_preflight_state.json", "ui_screenshot_lock.json",
]

INFRASTRUCTURE_DIRS = [".claude/hooks/", ".claude/agents/"]

IMPL_PHASES = {
    "phase5_implement", "phase6_adversary", "phase7_done",
    # v5 backward compat
    "phase6_done",
    # v4 backward compat (old workflows not yet archived)
    "phase6_implement", "phase6b_adversary", "phase7_validate", "phase8_complete",
}

TEST_DIRS = [
    "Tests/", "UITests/", "Test/", "test/", "__tests__/", "tests/",
    "FocusBloxTests/", "FocusBloxUITests/",
    "FocusBloxMacTests/", "FocusBloxMacUITests/",
]

SOURCE_DIRS = ["Sources/", "FocusBloxMac/"]

# Phase4: nur Test-Dateien editierbar (TDD RED — Tests schreiben)
TEST_ONLY_PHASES = {"phase4_tdd_red"}

# Phase5: nur Source-Dateien editierbar (Tests dürfen NICHT angepasst werden!)
SOURCE_ONLY_PHASES = {"phase5_implement"}


# --- Helpers ---

def _read_active_workflow() -> dict | None:
    """Read the active workflow, passing session ID from stdin if available."""
    session_id = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    return read_active_workflow(session_id)


def _find_workflow_for_file(file_path: str) -> dict | None:
    """Find workflow that owns a file via affected_files match."""
    wf_dir = _project_root() / ".claude" / "workflows"
    if not wf_dir.exists():
        return None
    root = str(_project_root())
    rel = file_path
    if rel.startswith(root):
        rel = rel[len(root):].lstrip("/")
    for f in wf_dir.glob("*.json"):
        data = _read_workflow_locked(f)
        if data is None:
            continue
        phase = data.get("current_phase", "phase0_idle")
        if phase in ("phase6_done", "phase0_idle"):
            continue
        for af in data.get("affected_files", []):
            if rel == af or rel.endswith("/" + af) or af.endswith("/" + rel):
                return data
    return None


def _has_override_token(workflow_name: str = None) -> bool:
    """Check override token for a SPECIFIC workflow. No fallback to 'any token'.

    Args:
        workflow_name: Required. Only returns True if a token exists for THIS workflow.
                       Special values: "__infra__" for infrastructure files.
                       None always returns False (no anonymous overrides).
    """
    if not workflow_name:
        return False
    token_file = _project_root() / ".claude" / "user_override_token.json"
    if not token_file.exists():
        return False
    try:
        data = json.loads(token_file.read_text())
        tokens = data.get("tokens", {}) if data.get("version") == 2 else (
            {data["workflow"]: data} if "workflow" in data else {}
        )
        return workflow_name in tokens
    except (json.JSONDecodeError, OSError):
        return False


def _is_stop_locked() -> bool:
    """Check if stop-lock is active for the current session."""
    lock = _project_root() / ".claude" / "stop_lock.json"
    if not lock.exists():
        return False
    try:
        data = json.loads(lock.read_text())
        # v2: per-session stop locks
        if data.get("version") == 2:
            sessions = data.get("sessions", {})
            if not sessions:
                return False
            sid = os.environ.get("CLAUDE_SESSION_ID", "")
            return sid in sessions or "__global__" in sessions
        # v1 backward compat
        return data.get("enabled", False)
    except (json.JSONDecodeError, OSError):
        return False


def _is_test_file(file_path: str) -> bool:
    """Check if file is in a test directory."""
    return any(d in file_path for d in TEST_DIRS)


def _is_source_file(file_path: str) -> bool:
    """Check if file is in a source directory."""
    return any(d in file_path for d in SOURCE_DIRS)


# --- Main ---

def main():
    if os.environ.get("CLAUDE_ADMIN"):
        sys.exit(0)
    global _STDIN_SESSION_ID
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
            _STDIN_SESSION_ID = data.get("session_id", "")
        except (json.JSONDecodeError, Exception):
            sys.exit(0)
    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
        file_path = data.get("file_path", "")
    except json.JSONDecodeError:
        sys.exit(0)

    if not file_path:
        sys.exit(0)

    # 1. Protected state files
    for pf in PROTECTED_STATE_FILES:
        if pf in file_path:
            print(f"BLOCKED: Protected state file: {pf}", file=sys.stderr)
            sys.exit(2)

    # 1b. Backlog-Dateien sind archiviert — GitHub Issues nutzen
    fname = Path(file_path).name.lower()
    if fname == "active-todos.md" or fname == "archive-todos.md":
        print("BLOCKED: Backlog-Dateien sind archiviert. Nutze GitHub Issues: gh issue create / gh issue list", file=sys.stderr)
        sys.exit(2)
    if re.search(r'(todo|backlog|roadmap).*\.md$', fname, re.IGNORECASE) and "docs/" in file_path:
        # Allow reading existing files, block creating new ones
        if not Path(file_path).exists():
            print("BLOCKED: Keine neuen Todo/Backlog/Roadmap-Dateien anlegen. Nutze GitHub Issues: gh issue create", file=sys.stderr)
            sys.exit(2)

    # 2. Always-allowed directories
    for d in ALWAYS_ALLOWED_DIRS:
        if d in file_path:
            sys.exit(0)

    # 2b. Always-allowed patterns
    for p in ALWAYS_ALLOWED_PATTERNS:
        if re.search(p, file_path, re.IGNORECASE):
            sys.exit(0)

    # 3. Not a code file
    ext = Path(file_path).suffix.lower()
    if ext not in CODE_EXTENSIONS:
        sys.exit(0)

    # 4. Infrastructure file
    for infra in INFRASTRUCTURE_DIRS:
        if infra in file_path:
            if _has_override_token("__infra__") or _has_override_token():
                sys.exit(0)
            print("BLOCKED: Infrastructure file — user must type 'override'.", file=sys.stderr)
            sys.exit(2)

    # 5. Stop-lock
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active.", file=sys.stderr)
        sys.exit(2)

    # 6. Find workflow for file (by affected_files match)
    workflow = _find_workflow_for_file(file_path)
    if not workflow:
        # Fallback: active workflow ONLY if it has no affected_files yet
        # (early phase, files not scoped yet). If it HAS affected_files
        # but this file isn't in them → out of scope, don't fallback.
        active = _read_active_workflow()
        if active and not active.get("affected_files"):
            workflow = active

    # 7. No workflow
    if not workflow:
        print(f"BLOCKED: No active workflow for {file_path}. Start with /01-context.", file=sys.stderr)
        sys.exit(2)

    phase = workflow.get("current_phase", "phase0_idle")
    wf_name = workflow.get("name", "unknown")

    # 8. Phase-spezifische Edit-Einschränkungen
    is_test = _is_test_file(file_path)

    if phase in TEST_ONLY_PHASES:
        # phase4_tdd_red: nur Test-Dateien erlaubt
        if is_test:
            # Gate: inspect-ui PFLICHT vor UI-Test-Writes
            if any(d in file_path for d in ["UITests/", "FocusBloxUITests/", "FocusBloxMacUITests/"]):
                if not workflow.get("inspect_ui_done"):
                    print("BLOCKED: /inspect-ui ist PFLICHT vor UI-Test-Writes. "
                          "Führe /inspect-ui aus, um die Accessibility-Hierarchie zu inspizieren.",
                          file=sys.stderr)
                    sys.exit(2)
            sys.exit(0)  # Test-Dateien erlaubt in TDD RED
        if not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt nur Test-Dateien. Sources sind gesperrt.", file=sys.stderr)
            sys.exit(2)

    elif phase in SOURCE_ONLY_PHASES:
        # phase6_implement: keine Test-Änderungen (Tests dürfen nicht angepasst werden!)
        if is_test and not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt keine Test-Änderungen. "
                  f"Tests dürfen nicht an Implementation angepasst werden!", file=sys.stderr)
            sys.exit(2)
        # Source files: fall through to TDD artifact check (Schritt 10)

    elif phase not in IMPL_PHASES:
        # Alle anderen Phasen vor Implementation: keine Code-Edits
        if not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt keine Code-Edits. Starte mit /01-context.", file=sys.stderr)
            sys.exit(2)

    # 9. Scope-Guard: max 5 Code-Dateien pro Workflow
    if phase in IMPL_PHASES:
        affected = workflow.get("affected_files", [])
        code_affected = [f for f in affected if any(f.endswith(ext) for ext in CODE_EXTENSIONS)]
        if len(code_affected) > 5:
            print(f"BLOCKED: Scope-Limit überschritten — {len(code_affected)} Code-Dateien "
                  f"(max 5). Ticket aufteilen oder Scope reduzieren.",
                  file=sys.stderr)
            sys.exit(2)

    # 10. Override token skips TDD check
    if _has_override_token(wf_name):
        sys.exit(0)

    # 11. RED test artifacts
    if phase in IMPL_PHASES:
        red_done = workflow.get("red_test_done", False) or workflow.get("ui_test_red_done", False)
        if not red_done:
            red_arts = [a for a in workflow.get("test_artifacts", [])
                       if a.get("phase") == "phase4_tdd_red"]
            if not red_arts:
                print("BLOCKED: No RED test artifacts. Run /04-tdd-red first.", file=sys.stderr)
                sys.exit(2)

    # 12. Allow
    sys.exit(0)


if __name__ == "__main__":
    main()
