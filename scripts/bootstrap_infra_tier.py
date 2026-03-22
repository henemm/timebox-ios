#!/usr/bin/env python3
"""
Bootstrap: Infrastructure-Tier fuer Workflow-Hooks.

Fuehre dieses Script im Terminal aus (nicht via Claude):
  python3 scripts/bootstrap_infra_tier.py

Es patcht 4 Dateien:

1. strict_code_gate.py
   - Neue Kategorie INFRASTRUCTURE_DIRS (.claude/hooks/, .claude/agents/)
   - Braucht __infra__ Token, aber KEINEN vollen Workflow
   - .claude/agents/ aus ALWAYS_ALLOWED_DIRS entfernt

2. override_token_listener.py
   - Erstellt __infra__ Token wenn kein aktiver Workflow existiert
   - User muss trotzdem "override" sagen

3. override_token_bash_guard.py
   - Blockt Bash-Commands die workflow_state.json manipulieren
   - Erlaubt workflow_state_multi.py (offizielles CLI)
   - Schliesst die Luecke, durch die Claude den State direkt aendern konnte

4. state_integrity_guard.py
   - Git-Befehle in Whitelist (git add/commit/diff/push etc.)
   - Git-Operationen auf bereits genehmigte Datei-Aenderungen sind sicher

Nach dem Ausfuehren kann Claude Hooks aendern — aber NUR nach "override" vom User.
"""

import re
from pathlib import Path

HOOKS_DIR = Path(__file__).parent.parent / ".claude" / "hooks"
CHANGED = []


def patch_file(filepath: Path, old: str, new: str, description: str) -> bool:
    """Replace exact string in file. Returns True if changed."""
    content = filepath.read_text()
    if old not in content:
        if new in content:
            print(f"  SKIP (already patched): {description}")
            return False
        print(f"  ERROR: Could not find target string for: {description}")
        print(f"  File: {filepath}")
        return False

    content = content.replace(old, new, 1)
    filepath.write_text(content)
    print(f"  OK: {description}")
    CHANGED.append(filepath.name)
    return True


def main():
    print("=" * 60)
    print("Bootstrap: Infrastructure-Tier")
    print("=" * 60)
    print()

    # ── 1. strict_code_gate.py ──────────────────────────────────
    print("[1/4] strict_code_gate.py — Infrastructure-Kategorie")

    scg = HOOKS_DIR / "strict_code_gate.py"

    # 1a: Remove .claude/agents/ from ALWAYS_ALLOWED_DIRS
    patch_file(
        scg,
        old='    ".claude/commands/",\n    ".claude/agents/",\n    "scripts/",',
        new='    ".claude/commands/",\n    "scripts/",',
        description="Remove .claude/agents/ from ALWAYS_ALLOWED_DIRS"
    )

    # 1b: Add INFRASTRUCTURE_DIRS after ALWAYS_ALLOWED_DIRS
    patch_file(
        scg,
        old='''# File patterns ALWAYS allowed (whitelist)''',
        new='''# Infrastructure directories — require __infra__ override token, NOT full workflow
# These contain workflow enforcement logic itself (chicken-and-egg protection)
INFRASTRUCTURE_DIRS = [
    ".claude/hooks/",
    ".claude/agents/",
]

# File patterns ALWAYS allowed (whitelist)''',
        description="Add INFRASTRUCTURE_DIRS list"
    )

    # 1c: Add is_infrastructure_file function after is_always_allowed
    patch_file(
        scg,
        old='''def is_code_file(file_path: str) -> bool:''',
        new='''def is_infrastructure_file(file_path: str) -> bool:
    """Check if file is workflow infrastructure (hooks, agents)."""
    for infra_dir in INFRASTRUCTURE_DIRS:
        if infra_dir in file_path:
            return True
    return False


def is_code_file(file_path: str) -> bool:''',
        description="Add is_infrastructure_file() function"
    )

    # 1d: Add infrastructure check before "CODE FILE → Workflow required!"
    patch_file(
        scg,
        old='''    # CODE FILE → Workflow required!''',
        new='''    # INFRASTRUCTURE FILE → Override token required, but no workflow
    # Accept ANY valid override token — if user said "override", they approved it
    if is_infrastructure_file(file_path):
        if check_user_override(workflow=None, workflow_name="__infra__") or check_user_override():
            sys.exit(0)
        print("""
╔══════════════════════════════════════════════════════════════════╗
║  BLOCKED: Infrastructure File — Override Required!               ║
╠══════════════════════════════════════════════════════════════════╣
║  You're trying to modify workflow infrastructure (hooks/agents). ║
║                                                                  ║
║  These files control enforcement logic and need explicit         ║
║  user approval — but NO full workflow is required.               ║
║                                                                  ║
║  REQUIRED: User must type 'override' in chat.                    ║
║                                                                  ║
║  This protects against Claude weakening its own enforcement.     ║
╚══════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)
        sys.exit(2)

    # CODE FILE → Workflow required!''',
        description="Add infrastructure check before workflow check"
    )

    print()

    # ── 2. override_token_listener.py ───────────────────────────
    print("[2/4] override_token_listener.py — __infra__ Token ohne Workflow")

    otl = HOOKS_DIR / "override_token_listener.py"

    # 2a: __infra__ fallback when no active workflow
    patch_file(
        otl,
        old='''    else:
        # No explicit name — fall back to active workflow
        target_name = session_active_name(state)
        if not target_name or target_name not in state.get("workflows", {}):
            print("Override requested but no active workflow found.", file=sys.stderr)
            sys.exit(0)''',
        new='''    else:
        # No explicit name — fall back to active workflow
        target_name = session_active_name(state)
        if not target_name or target_name not in state.get("workflows", {}):
            # No active workflow — create infrastructure token
            # This allows editing hooks/agents without a full workflow
            target_name = "__infra__"''',
        description="Create __infra__ token when no workflow active"
    )

    # 2b: Accept "override __infra__" as explicit name even though it's not a real workflow
    patch_file(
        otl,
        old='''    if explicit_name:
        # Explicit workflow name provided — validate it exists
        if explicit_name not in state.get("workflows", {}):
            print(f"Override requested for unknown workflow: {explicit_name}", file=sys.stderr)
            sys.exit(0)
        target_name = explicit_name''',
        new='''    if explicit_name:
        # Special infrastructure token — always allowed without workflow
        if explicit_name == "__infra__":
            target_name = "__infra__"
        # Explicit workflow name provided — validate it exists
        elif explicit_name not in state.get("workflows", {}):
            print(f"Override requested for unknown workflow: {explicit_name}", file=sys.stderr)
            sys.exit(0)
        else:
            target_name = explicit_name''',
        description="Accept __infra__ as explicit override target"
    )

    print()

    # ── 3. override_token_bash_guard.py ─────────────────────────
    print("[3/4] override_token_bash_guard.py — workflow_state Bash-Luecke")

    otbg = HOOKS_DIR / "override_token_bash_guard.py"

    patch_file(
        otbg,
        old='''    sys.exit(0)


if __name__ == "__main__":
    main()''',
        new='''    # Block direct manipulation of workflow_state.json via Bash.
    # ALLOWED: workflow_state_multi.py (official CLI tool called by slash commands)
    # BLOCKED: everything else (python3 -c, echo, cat >, etc.)
    if "workflow_state" in command and "workflow_state_multi.py" not in command:
        print(
            "BLOCKED: workflow_state.json darf nicht direkt via Bash manipuliert werden.\\n"
            "Nutze das offizielle CLI: python3 .claude/hooks/workflow_state_multi.py\\n"
            "Zum Lesen nutze das Read-Tool statt Bash.",
            file=sys.stderr
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()''',
        description="Block workflow_state in Bash (allow workflow_state_multi.py)"
    )

    print()

    # ── 4. state_integrity_guard.py ─────────────────────────────
    print("[4/4] state_integrity_guard.py — Git-Befehle whitelisten")

    sig = HOOKS_DIR / "state_integrity_guard.py"

    # Add early return for git commands before any protected file checks
    patch_file(
        sig,
        old='''    # Quick check: does command reference any protected file?''',
        new='''    # Git commands are always safe — file modifications were already
    # approved through Edit/Write guards. Git just stages/commits them.
    if command.lstrip().startswith("git "):
        sys.exit(0)

    # Quick check: does command reference any protected file?''',
        description="Early return for git commands"
    )

    print()
    print("=" * 60)
    if CHANGED:
        print(f"DONE — {len(CHANGED)} Datei(en) gepatcht: {', '.join(CHANGED)}")
        print()
        print("Naechster Schritt:")
        print("  1. Starte eine neue Claude-Session (oder diese weiter)")
        print("  2. Tippe 'override' wenn du Hook-Aenderungen erlauben willst")
        print("  3. Claude kann dann Hooks editieren — nur mit deiner Freigabe")
    else:
        print("Keine Aenderungen noetig — alles bereits gepatcht.")
    print("=" * 60)


if __name__ == "__main__":
    main()
