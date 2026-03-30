#!/usr/bin/env python3
"""
TDD RED Tests for INFRA_002 — Workflow v3 Hook System

These tests verify the NEW hook architecture (workflow.py, edit_gate.py,
bash_gate.py, phase_listener.py, phase_transition.py).

ALL tests MUST FAIL because the implementations don't exist yet.
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil
import unittest
from pathlib import Path
from unittest.mock import patch


# ============================================================
# Test 1: workflow.py — State Isolation
# ============================================================

class TestWorkflowStateCLI(unittest.TestCase):
    """Tests for the new workflow.py state manager.

    Replaces workflow_state_multi.py (1733 LoC) with ~300 LoC.
    Key change: 1 JSON file per workflow instead of 1 shared file.
    """

    def setUp(self):
        """Create temp directory simulating .claude/workflows/"""
        self.tmpdir = tempfile.mkdtemp()
        self.workflows_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.hooks_dir = Path(self.tmpdir) / ".claude" / "hooks"
        self.hooks_dir.mkdir(parents=True, exist_ok=True)
        # This is where workflow.py SHOULD be
        self.workflow_py = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "workflow.py"

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_workflow_py_exists(self):
        """workflow.py must exist as the new CLI entry point.

        Breaks when: .claude/hooks/workflow.py is not created yet.
        """
        self.assertTrue(
            self.workflow_py.exists(),
            f"workflow.py does not exist at {self.workflow_py}. "
            "This is the new state manager replacing workflow_state_multi.py."
        )

    def test_start_creates_workflow_file(self):
        """'start' command creates .claude/workflows/<name>.json

        Breaks when: workflow.py start doesn't create isolated workflow file.
        """
        result = subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        workflow_file = self.workflows_dir / "TEST_001.json"
        self.assertTrue(
            workflow_file.exists(),
            f"Expected {workflow_file} to be created by 'start' command. "
            f"stdout: {result.stdout}, stderr: {result.stderr}"
        )

    def test_start_creates_active_symlink(self):
        """'start' command creates .active symlink pointing to new workflow.

        Breaks when: workflow.py doesn't create/update .active symlink.
        """
        subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        active_link = self.workflows_dir / ".active"
        self.assertTrue(
            active_link.is_symlink(),
            f".active symlink not created at {active_link}"
        )

    def test_switch_changes_active_symlink(self):
        """'switch' changes .active symlink to target workflow.

        Breaks when: workflow.py switch doesn't update symlink.
        """
        # Start two workflows
        for name in ["WF_A", "WF_B"]:
            subprocess.run(
                [sys.executable, str(self.workflow_py), "start", name],
                capture_output=True, text=True,
                env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
            )
        # Switch to WF_A
        subprocess.run(
            [sys.executable, str(self.workflow_py), "switch", "WF_A"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        active_link = self.workflows_dir / ".active"
        target = os.readlink(str(active_link))
        self.assertIn("WF_A", target, f".active points to {target}, expected WF_A")

    def test_status_reads_active_workflow(self):
        """'status' outputs current phase of active workflow.

        Breaks when: workflow.py status doesn't read from active symlink.
        """
        subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        result = subprocess.run(
            [sys.executable, str(self.workflow_py), "status"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        self.assertIn("TEST_001", result.stdout, f"Status should show workflow name. Got: {result.stdout}")

    def test_phase_transition_validates_prerequisites(self):
        """Phase transition validates prerequisites before allowing advance.

        Breaks when: workflow.py phase doesn't call phase_transition validation.
        """
        # Start workflow, try to jump directly to phase6_implement (should fail)
        subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        result = subprocess.run(
            [sys.executable, str(self.workflow_py), "phase", "phase6_implement"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        # Should fail — can't skip from phase1 to phase6
        self.assertNotEqual(result.returncode, 0,
            "Jumping from phase1 to phase6 should fail validation")

    def test_complete_moves_to_archive(self):
        """'complete' moves workflow file to _archive/ directory.

        Breaks when: workflow.py complete doesn't move file.
        """
        subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        subprocess.run(
            [sys.executable, str(self.workflow_py), "complete"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        archive_file = self.workflows_dir / "_archive" / "TEST_001.json"
        self.assertTrue(archive_file.exists(), f"Completed workflow should be in {archive_file}")

    def test_workflow_file_format_minimal(self):
        """Workflow JSON has minimal fields (no session_workflows, no phases_completed).

        Breaks when: workflow.py creates files with old bloated format.
        """
        subprocess.run(
            [sys.executable, str(self.workflow_py), "start", "TEST_001"],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.tmpdir}
        )
        wf_file = self.workflows_dir / "TEST_001.json"
        if wf_file.exists():
            data = json.loads(wf_file.read_text())
            self.assertNotIn("session_workflows", data, "No session tracking in v3")
            self.assertNotIn("phases_completed", data, "No redundant phases_completed")
            self.assertIn("name", data)
            self.assertIn("current_phase", data)
            self.assertIn("affected_files", data)


# ============================================================
# Test 2: edit_gate.py — Consolidated Edit Guard
# ============================================================

class TestEditGate(unittest.TestCase):
    """Tests for the consolidated edit_gate.py hook.

    Replaces 17 separate Edit/Write hooks with 1.
    """

    def setUp(self):
        self.edit_gate = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "edit_gate.py"

    def test_edit_gate_exists(self):
        """edit_gate.py must exist as the consolidated Edit/Write guard.

        Breaks when: .claude/hooks/edit_gate.py is not created yet.
        """
        self.assertTrue(
            self.edit_gate.exists(),
            f"edit_gate.py does not exist at {self.edit_gate}"
        )

    def _run_hook(self, tool_input: dict) -> subprocess.CompletedProcess:
        """Helper: run edit_gate.py with simulated CLAUDE_TOOL_INPUT."""
        return subprocess.run(
            [sys.executable, str(self.edit_gate)],
            capture_output=True, text=True,
            env={**os.environ, "CLAUDE_TOOL_INPUT": json.dumps(tool_input)}
        )

    def test_allows_docs_files(self):
        """Docs files are always allowed without workflow.

        Breaks when: edit_gate.py doesn't whitelist docs/ directory.
        """
        result = self._run_hook({"file_path": "docs/specs/test.md"})
        self.assertEqual(result.returncode, 0, f"docs/ should be allowed. stderr: {result.stderr}")

    def test_allows_test_files(self):
        """Test files are always allowed (we want to write tests freely).

        Breaks when: edit_gate.py doesn't whitelist test directories.
        """
        result = self._run_hook({"file_path": "FocusBloxTests/SomeTest.swift"})
        self.assertEqual(result.returncode, 0, f"Test files should be allowed. stderr: {result.stderr}")

    def test_blocks_code_without_workflow(self):
        """Code files are blocked when no active workflow exists.

        Breaks when: edit_gate.py doesn't check for active workflow.
        """
        result = self._run_hook({"file_path": "Sources/Models/Task.swift"})
        self.assertEqual(result.returncode, 2, "Code files without workflow should be blocked")

    def test_blocks_protected_state_files(self):
        """Protected state files (.claude/workflow_state.json etc.) always blocked.

        Breaks when: edit_gate.py doesn't protect state files.
        """
        result = self._run_hook({"file_path": ".claude/workflows/TEST.json"})
        self.assertEqual(result.returncode, 2, "Direct workflow state edits should be blocked")


# ============================================================
# Test 3: bash_gate.py — Consolidated Bash Guard
# ============================================================

class TestBashGate(unittest.TestCase):
    """Tests for the consolidated bash_gate.py hook.

    Replaces 15 separate Bash hooks with 1.
    """

    def setUp(self):
        self.bash_gate = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "bash_gate.py"

    def test_bash_gate_exists(self):
        """bash_gate.py must exist as the consolidated Bash guard.

        Breaks when: .claude/hooks/bash_gate.py is not created yet.
        """
        self.assertTrue(
            self.bash_gate.exists(),
            f"bash_gate.py does not exist at {self.bash_gate}"
        )

    def _run_hook(self, command: str) -> subprocess.CompletedProcess:
        """Helper: run bash_gate.py with simulated CLAUDE_TOOL_INPUT."""
        return subprocess.run(
            [sys.executable, str(self.bash_gate)],
            capture_output=True, text=True,
            env={
                **os.environ,
                "CLAUDE_TOOL_INPUT": json.dumps({"command": command}),
                "CLAUDE_TOOL_NAME": "Bash",
            }
        )

    def test_blocks_secrets_exposure(self):
        """Blocks cat .env and similar sensitive file reads.

        Breaks when: bash_gate.py doesn't include secrets guard logic.
        """
        result = self._run_hook("cat .env")
        self.assertEqual(result.returncode, 2, "Reading .env should be blocked")

    def test_blocks_direct_xcodebuild(self):
        """Blocks direct xcodebuild calls (must use sim.sh).

        Breaks when: bash_gate.py doesn't include sim_enforcer logic.
        """
        result = self._run_hook("xcodebuild build -project FocusBlox.xcodeproj")
        self.assertEqual(result.returncode, 2, "Direct xcodebuild should be blocked")

    def test_allows_sim_sh(self):
        """Allows sim.sh wrapper calls.

        Breaks when: bash_gate.py blocks sim.sh.
        """
        result = self._run_hook("./scripts/sim.sh build")
        self.assertEqual(result.returncode, 0, f"sim.sh should be allowed. stderr: {result.stderr}")

    def test_blocks_state_file_manipulation(self):
        """Blocks direct writes to protected workflow files.

        Breaks when: bash_gate.py doesn't include state_integrity logic.
        """
        result = self._run_hook('python3 -c "open(\'.claude/workflows/X.json\', \'w\')"')
        self.assertEqual(result.returncode, 2, "Direct state file writes should be blocked")

    def test_allows_git_operations(self):
        """Git commands pass through (staging/committing is safe).

        Breaks when: bash_gate.py incorrectly blocks git commands.
        """
        result = self._run_hook("git status")
        self.assertEqual(result.returncode, 0, f"git should be allowed. stderr: {result.stderr}")


# ============================================================
# Test 4: phase_listener.py — UserPromptSubmit Listener
# ============================================================

class TestPhaseListener(unittest.TestCase):
    """Tests for the consolidated phase_listener.py hook.

    Replaces 6 separate UserPromptSubmit hooks with 1.
    """

    def setUp(self):
        self.listener = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "phase_listener.py"

    def test_phase_listener_exists(self):
        """phase_listener.py must exist as the consolidated UserPromptSubmit hook.

        Breaks when: .claude/hooks/phase_listener.py is not created yet.
        """
        self.assertTrue(
            self.listener.exists(),
            f"phase_listener.py does not exist at {self.listener}"
        )


# ============================================================
# Test 5: migrate_state.py — State Migration
# ============================================================

class TestMigrateState(unittest.TestCase):
    """Tests for the one-time state migration script.

    Splits workflow_state.json into per-workflow files.
    """

    def setUp(self):
        self.migrate = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "migrate_state.py"

    def test_migrate_script_exists(self):
        """migrate_state.py must exist for v2→v3 state migration.

        Breaks when: .claude/hooks/migrate_state.py is not created yet.
        """
        self.assertTrue(
            self.migrate.exists(),
            f"migrate_state.py does not exist at {self.migrate}"
        )


# ============================================================
# Test 6: Old hooks must NOT exist after migration
# ============================================================

class TestOldHooksRemoved(unittest.TestCase):
    """Verifies that the old 46 hook files are deleted after migration.

    These tests will PASS in RED phase (files still exist) but provide
    the deletion checklist for implementation.
    """

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

    def test_old_hooks_removed(self):
        """All 50 old hook files must be deleted after migration.

        Breaks when: Old hooks are not cleaned up during implementation.
        NOTE: This test PASSES in RED phase (files still exist = expected).
        It becomes meaningful AFTER implementation when we verify cleanup.
        """
        hooks_dir = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks"
        remaining = [h for h in self.OLD_HOOKS if (hooks_dir / h).exists()]
        self.assertEqual(
            len(remaining), 0,
            f"{len(remaining)} old hooks still exist: {remaining[:5]}..."
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
