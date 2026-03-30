#!/usr/bin/env python3
"""
State Migration v2 → v3

Splits workflow_state.json into per-workflow files in .claude/workflows/.
Creates .active symlink for the active workflow.
Backs up old file to workflow_state.json.bak.

Usage:
    python3 migrate_state.py          # Dry run
    python3 migrate_state.py --apply  # Actually migrate
"""

import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path


def _project_root() -> Path:
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def migrate(dry_run: bool = True) -> None:
    root = _project_root()
    old_state = root / ".claude" / "workflow_state.json"

    if not old_state.exists():
        print("No workflow_state.json found. Nothing to migrate.")
        return

    data = json.loads(old_state.read_text())
    workflows = data.get("workflows", {})
    active_name = data.get("active_workflow")

    if not workflows:
        print("No workflows in state file.")
        return

    wf_dir = root / ".claude" / "workflows"
    archive_dir = wf_dir / "_archive"

    print(f"Found {len(workflows)} workflow(s) to migrate:")
    for name, wf in workflows.items():
        phase = wf.get("current_phase", "?")
        is_active = " (ACTIVE)" if name == active_name else ""
        print(f"  {name}: {phase}{is_active}")

        if dry_run:
            continue

        # Create workflow file with v3 format
        v3_data = {
            "name": name,
            "current_phase": wf.get("current_phase", "phase0_idle"),
            "created": wf.get("created", datetime.now().isoformat()),
            "last_updated": wf.get("last_updated", datetime.now().isoformat()),
            "spec_file": wf.get("spec_file"),
            "spec_approved": wf.get("spec_approved", False),
            "context_file": wf.get("context_file"),
            "affected_files": wf.get("affected_files", []),
            "test_artifacts": wf.get("test_artifacts", []),
            "is_new_ui": wf.get("is_new_ui", False),
            "red_test_done": wf.get("red_test_done", False),
            "ui_test_red_done": wf.get("ui_test_red_done", False),
            "green_approved": wf.get("green_approved", False),
            "adversary_verdict": wf.get("adversary_verdict"),
        }

        # Also preserve analysis_findings if present
        if wf.get("analysis_findings"):
            v3_data["analysis_findings"] = wf["analysis_findings"]

        # Completed workflows go to archive
        if phase == "phase8_complete":
            target_dir = archive_dir
        else:
            target_dir = wf_dir

        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / f"{name}.json"
        target.write_text(json.dumps(v3_data, indent=2))
        print(f"    → {target.relative_to(root)}")

    if dry_run:
        print("\nDry run. Use --apply to actually migrate.")
        return

    # Set active workflow symlink
    if active_name and (wf_dir / f"{active_name}.json").exists():
        active_link = wf_dir / ".active"
        if active_link.is_symlink() or active_link.exists():
            active_link.unlink()
        os.symlink(f"{active_name}.json", str(active_link))
        print(f"\n.active → {active_name}.json")

    # Backup old state
    backup = old_state.with_suffix(".json.bak")
    shutil.copy2(str(old_state), str(backup))
    print(f"\nBackup: {backup.relative_to(root)}")

    # Remove old state file
    old_state.unlink()
    print(f"Removed: {old_state.relative_to(root)}")

    # Remove old lock file
    lock_file = root / ".claude" / "workflow_state.lock"
    if lock_file.exists():
        lock_file.unlink()
        print(f"Removed: {lock_file.relative_to(root)}")

    print(f"\nMigration complete. {len(workflows)} workflow(s) migrated.")


def main():
    apply = "--apply" in sys.argv
    migrate(dry_run=not apply)


if __name__ == "__main__":
    main()
