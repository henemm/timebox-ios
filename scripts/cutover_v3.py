#!/usr/bin/env python3
"""
INFRA_002 Cutover Script — Activates Workflow v3

Run this OUTSIDE of Claude Code (in a normal terminal).
After running, restart Claude Code.

Steps:
1. Migrate state (workflow_state.json → .claude/workflows/*.json)
2. Update settings.json (41 hooks → 4)
3. Update slash commands (workflow_state_multi.py → workflow.py)
4. Delete old hook files (50 files)
5. Clean up old state files

Usage:
    python3 scripts/cutover_v3.py          # Dry run
    python3 scripts/cutover_v3.py --apply  # Actually do it
"""

import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
HOOKS_DIR = ROOT / ".claude" / "hooks"
COMMANDS_DIR = ROOT / ".claude" / "commands"

# Old hooks to delete (keep: workflow.py, edit_gate.py, bash_gate.py,
# post_bash.py, phase_listener.py, migrate_state.py, override_token.py)
OLD_HOOKS = [
    "adversary_gate.py", "adversary_verdict_guard.py", "artifact_existence_guard.py",
    "build_lock_guard.py", "build_lock_release.py", "claude_md_protection.py",
    "config_loader.py", "docs_location_guard.py", "domain_pattern_guard.py",
    "feature_understanding_gate.py", "inspection_gate.py", "new_ui_listener.py",
    "no_workaround_guard.py", "notify_sound.py", "on_ui_test_failure.py",
    "override_token_bash_guard.py", "override_token_guard.py", "override_token_listener.py",
    "parallel_test_guard.py", "plan_validator.py", "post_implementation_gate.py",
    "pre_commit_gate.py", "preflight_gate.py", "red_test_gate.py",
    "result_inspection_gate.py", "scope_guard.py", "secrets_guard.py",
    "session_env.py", "sim_enforcer.py", "spec_enforcement.py",
    "state_integrity_guard.py", "stop_lock_guard.py", "stop_lock_listener.py",
    "strict_code_gate.py", "tdd_enforcement.py", "tdd_green_gate.py",
    "tdd_green_listener.py", "test_lock_guard.py", "test_regression_guard.py",
    "track_changes.py", "ui_screenshot_gate.py", "ui_test_debugger_hint.py",
    "ui_test_gate.py", "ui_test_preflight.py", "validate_completeness_gate.py",
    "visual_inspection_gate.py", "workflow_cleanup.py", "workflow_gate.py",
    "workflow_state_multi.py", "workflow_state_updater.py",
]

# Old state files to clean up
OLD_STATE_FILES = [
    ".claude/workflow_state.lock",
    ".claude/test_execution_lock.json",
    ".claude/validation_state.json",
    ".claude/ui_test_preflight_state.json",
    ".claude/ui_screenshot_lock.json",
    ".claude/workflow_last_cleanup.json",
    ".claude/build_lock.json",
    ".claude/framework_version.json",
]

NEW_SETTINGS = {
    "permissions": {
        "allow": ["Bash", "WebSearch", "WebFetch"],
        "deny": [],
        "ask": []
    },
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Edit|Write",
                "hooks": [{"type": "command", "command": "python3 .claude/hooks/edit_gate.py", "timeout": 5}]
            },
            {
                "matcher": "Bash",
                "hooks": [{"type": "command", "command": "python3 .claude/hooks/bash_gate.py", "timeout": 300}]
            }
        ],
        "PostToolUse": [
            {
                "matcher": "Bash",
                "hooks": [{"type": "command", "command": "python3 .claude/hooks/post_bash.py", "timeout": 5}]
            }
        ],
        "UserPromptSubmit": [
            {
                "hooks": [{"type": "command", "command": "python3 .claude/hooks/phase_listener.py", "timeout": 5}]
            }
        ]
    }
}


def step_migrate_state(dry_run: bool) -> None:
    print("\n=== Step 1: Migrate State ===")
    migrate_py = HOOKS_DIR / "migrate_state.py"
    if not migrate_py.exists():
        print("  ERROR: migrate_state.py not found!")
        sys.exit(1)

    old_state = ROOT / ".claude" / "workflow_state.json"
    if not old_state.exists():
        print("  No workflow_state.json — already migrated or fresh project.")
        return

    if dry_run:
        print(f"  Would migrate {old_state}")
        # Show what would happen
        data = json.loads(old_state.read_text())
        for name in data.get("workflows", {}):
            print(f"    → .claude/workflows/{name}.json")
    else:
        import subprocess
        result = subprocess.run(
            [sys.executable, str(migrate_py), "--apply"],
            cwd=str(ROOT), capture_output=True, text=True
        )
        print(result.stdout)
        if result.returncode != 0:
            print(f"  ERROR: {result.stderr}")
            sys.exit(1)


def step_update_settings(dry_run: bool) -> None:
    print("\n=== Step 2: Update settings.json ===")
    settings_file = ROOT / ".claude" / "settings.json"

    if dry_run:
        old = json.loads(settings_file.read_text())
        old_count = sum(len(entry.get("hooks", [])) for group in old.get("hooks", {}).values() for entry in (group if isinstance(group, list) else [group]))
        new_count = sum(len(entry.get("hooks", [])) for group in NEW_SETTINGS["hooks"].values() for entry in (group if isinstance(group, list) else [group]))
        print(f"  Would replace {old_count} hook entries with {new_count}")
    else:
        # Backup
        backup = settings_file.with_suffix(".json.v2.bak")
        shutil.copy2(str(settings_file), str(backup))
        print(f"  Backup: {backup.name}")
        # Write new
        settings_file.write_text(json.dumps(NEW_SETTINGS, indent=2))
        print(f"  Written new settings.json ({len(NEW_SETTINGS['hooks'])} hook groups)")


def step_update_commands(dry_run: bool) -> None:
    print("\n=== Step 3: Update Slash Commands ===")
    updated = 0
    for cmd_file in sorted(COMMANDS_DIR.glob("*.md")):
        content = cmd_file.read_text()
        if "workflow_state_multi.py" in content:
            new_content = content.replace("workflow_state_multi.py", "workflow.py")
            if dry_run:
                count = content.count("workflow_state_multi.py")
                print(f"  {cmd_file.name}: {count} replacement(s)")
            else:
                cmd_file.write_text(new_content)
                count = content.count("workflow_state_multi.py")
                print(f"  {cmd_file.name}: {count} replacement(s) applied")
            updated += 1
    print(f"  Total: {updated} files")


def step_delete_old_hooks(dry_run: bool) -> None:
    print("\n=== Step 4: Delete Old Hooks ===")
    deleted = 0
    missing = 0
    for hook in OLD_HOOKS:
        path = HOOKS_DIR / hook
        if path.exists():
            if dry_run:
                print(f"  Would delete: {hook}")
            else:
                path.unlink()
            deleted += 1
        else:
            missing += 1
    print(f"  {deleted} to delete, {missing} already gone")


def step_cleanup_state_files(dry_run: bool) -> None:
    print("\n=== Step 5: Clean Up State Files ===")
    cleaned = 0
    for rel_path in OLD_STATE_FILES:
        path = ROOT / rel_path
        if path.exists():
            if dry_run:
                print(f"  Would delete: {rel_path}")
            else:
                path.unlink()
                print(f"  Deleted: {rel_path}")
            cleaned += 1
    # Also clean /tmp session files
    import glob
    tmp_files = glob.glob("/tmp/claude_session_*") + glob.glob("/tmp/claude_last_session_id")
    for f in tmp_files:
        if dry_run:
            print(f"  Would delete: {f}")
        else:
            os.unlink(f)
        cleaned += 1
    print(f"  {cleaned} files cleaned")


def main():
    apply = "--apply" in sys.argv
    mode = "APPLY" if apply else "DRY RUN"
    print(f"{'='*60}")
    print(f"  INFRA_002 Cutover — Workflow v3 Activation ({mode})")
    print(f"{'='*60}")

    # Verify new hooks exist
    new_hooks = ["workflow.py", "edit_gate.py", "bash_gate.py", "post_bash.py", "phase_listener.py", "migrate_state.py"]
    for h in new_hooks:
        if not (HOOKS_DIR / h).exists():
            print(f"\nERROR: New hook {h} not found! Run the commit first.")
            sys.exit(1)
    print(f"\n  All {len(new_hooks)} new hooks present.")

    step_migrate_state(not apply)
    step_update_settings(not apply)
    step_update_commands(not apply)
    step_delete_old_hooks(not apply)
    step_cleanup_state_files(not apply)

    print(f"\n{'='*60}")
    if apply:
        print("  CUTOVER COMPLETE!")
        print("  → Restart Claude Code now: exit + claude")
    else:
        print("  DRY RUN complete. To apply:")
        print("  python3 scripts/cutover_v3.py --apply")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
