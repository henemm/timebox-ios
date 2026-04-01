#!/usr/bin/env python3
"""
Applies the session-isolation fix to all hook files.
Run: python3 docs/artifacts/bug-session-isolation/apply_fix.py
"""
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent.parent

def fix_token():
    """Set __infra__ override token."""
    tf = ROOT / ".claude" / "user_override_token.json"
    d = json.loads(tf.read_text()) if tf.exists() else {"version": 2, "tokens": {}}
    d["tokens"]["__infra__"] = {"created": datetime.now().isoformat(), "granted_by": "user_prompt"}
    tf.write_text(json.dumps(d, indent=2))
    print("[1/5] __infra__ Token gesetzt")

def fix_bash_gate():
    """Add _STDIN_SESSION_ID to bash_gate.py."""
    f = ROOT / ".claude" / "hooks" / "bash_gate.py"
    code = f.read_text()

    # Add module variable
    if "_STDIN_SESSION_ID" not in code:
        code = code.replace(
            "from pathlib import Path\n\n# --- Configuration ---",
            "from pathlib import Path\n\n# Session ID extracted from stdin JSON (set during _get_command())\n_STDIN_SESSION_ID = \"\"\n\n# --- Configuration ---"
        )

    # Extract session_id in _get_command()
    if "global _STDIN_SESSION_ID" not in code:
        code = code.replace(
            "def _get_command() -> str:\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    if not tool_input:\n        try:\n            data = json.load(sys.stdin)\n            tool_input = json.dumps(data.get(\"tool_input\", {}))",
            "def _get_command() -> str:\n    global _STDIN_SESSION_ID\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    if not tool_input:\n        try:\n            data = json.load(sys.stdin)\n            tool_input = json.dumps(data.get(\"tool_input\", {}))\n            _STDIN_SESSION_ID = data.get(\"session_id\", \"\")"
        )

    # Update _get_session_id() to use stdin fallback
    code = code.replace(
        '    """Get session identifier. Prefers CLAUDE_SESSION_ID, falls back to PPID."""\n    sid = os.environ.get("CLAUDE_SESSION_ID", "")',
        '    """Get session identifier. Prefers env var, then stdin, falls back to PPID."""\n    sid = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID'
    )

    f.write_text(code)
    print("[2/5] bash_gate.py gepatcht")

def fix_edit_gate():
    """Add _STDIN_SESSION_ID to edit_gate.py."""
    f = ROOT / ".claude" / "hooks" / "edit_gate.py"
    code = f.read_text()

    # Add module variable
    if "_STDIN_SESSION_ID" not in code:
        code = code.replace(
            "from pathlib import Path\n\n# --- Configuration ---",
            "from pathlib import Path\n\n# Session ID extracted from stdin JSON (set during main())\n_STDIN_SESSION_ID = \"\"\n\n# --- Configuration ---"
        )

    # Extract session_id in main()
    if "global _STDIN_SESSION_ID" not in code:
        code = code.replace(
            "def main():\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    if not tool_input:\n        try:\n            data = json.load(sys.stdin)\n            tool_input = json.dumps(data.get(\"tool_input\", {}))",
            "def main():\n    global _STDIN_SESSION_ID\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    if not tool_input:\n        try:\n            data = json.load(sys.stdin)\n            tool_input = json.dumps(data.get(\"tool_input\", {}))\n            _STDIN_SESSION_ID = data.get(\"session_id\", \"\")"
        )

    # Update session_id lookup in _read_active_workflow
    code = code.replace(
        '    session_id = os.environ.get("CLAUDE_SESSION_ID", "")\n    if session_id:\n        sessions_file = wf_dir / ".sessions.json"',
        '    session_id = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID\n    if session_id:\n        sessions_file = wf_dir / ".sessions.json"'
    )

    f.write_text(code)
    print("[3/5] edit_gate.py gepatcht")

def fix_post_bash():
    """Add _STDIN_SESSION_ID to post_bash.py."""
    f = ROOT / ".claude" / "hooks" / "post_bash.py"
    code = f.read_text()

    # Add module variable
    if "_STDIN_SESSION_ID" not in code:
        code = code.replace(
            "from pathlib import Path\n\n",
            "from pathlib import Path\n\n# Session ID extracted from stdin JSON (set during main())\n_STDIN_SESSION_ID = \"\"\n\n",
            1  # only first occurrence
        )

    # Extract session_id in main()
    if "global _STDIN_SESSION_ID" not in code:
        code = code.replace(
            "def main():\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    tool_response = \"\"\n\n    if not tool_input:\n        try:\n            raw_input = json.load(sys.stdin)\n            tool_input = json.dumps(raw_input.get(\"tool_input\", {}))",
            "def main():\n    global _STDIN_SESSION_ID\n    tool_input = os.environ.get(\"CLAUDE_TOOL_INPUT\", \"\")\n    tool_response = \"\"\n\n    if not tool_input:\n        try:\n            raw_input = json.load(sys.stdin)\n            tool_input = json.dumps(raw_input.get(\"tool_input\", {}))\n            _STDIN_SESSION_ID = raw_input.get(\"session_id\", \"\")"
        )

    # Update inline session_id read
    code = code.replace(
        '                session_id = os.environ.get("CLAUDE_SESSION_ID", "")',
        '                session_id = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID'
    )

    f.write_text(code)
    print("[4/5] post_bash.py gepatcht")

def fix_workflow_set_active():
    """Make _set_active() skip .active symlink when session_id is present."""
    f = ROOT / ".claude" / "hooks" / "workflow.py"
    code = f.read_text()

    old = '''    # Update .active symlink (backward compat)
    link = _active_link()
    target = f"{name}.json"
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.is_symlink() or link.exists():
        link.unlink()
    os.symlink(target, str(link))'''

    new = '''    # Update .active symlink only when no session_id (backward compat)
    if not session_id:
        link = _active_link()
        target = f"{name}.json"
        link.parent.mkdir(parents=True, exist_ok=True)
        if link.is_symlink() or link.exists():
            link.unlink()
        os.symlink(target, str(link))'''

    if old in code:
        code = code.replace(old, new)
        f.write_text(code)
        print("[5/5] workflow.py gepatcht")
    else:
        print("[5/5] workflow.py — bereits gepatcht oder Pattern nicht gefunden")

def fix_settings():
    """Register SessionStart hook in settings.json."""
    f = ROOT / ".claude" / "settings.json"
    settings = json.loads(f.read_text())
    hooks = settings.get("hooks", {})

    if "SessionStart" not in hooks:
        hooks["SessionStart"] = [{
            "hooks": [{
                "type": "command",
                "command": "python3 .claude/hooks/session_start.py",
                "timeout": 5
            }]
        }]
        settings["hooks"] = hooks
        f.write_text(json.dumps(settings, indent=2))
        print("[+] SessionStart Hook in settings.json registriert")
    else:
        print("[+] SessionStart Hook bereits registriert")


if __name__ == "__main__":
    print("=== Session-Isolation Fix ===\n")
    fix_token()
    fix_bash_gate()
    fix_edit_gate()
    fix_post_bash()
    fix_workflow_set_active()
    fix_settings()
    print("\nAlle Fixes angewendet!")
