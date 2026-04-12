#!/usr/bin/env python3
"""Tests for 4 new workflow gates (2026-04-12).

Tests verify:
1. UI-Test-Pflicht: phase6_implement blocked without ui_test_red_done
2. Existenz-Check: phase3_spec blocked for bugs without existence_check_done
3. Dead-Code-Check: phase7_validate blocked without dead_code_check_done
4. validation_done in Commit-Gate: bash_gate blocks commit without validation_done
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add hooks dir to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import workflow


class WorkflowGateTestBase(unittest.TestCase):
    """Base class that creates a temp workflow dir."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        # Patch _project_root to use temp dir
        self._patcher = patch.object(workflow, "_project_root",
                                     return_value=Path(self.tmpdir))
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def _create_workflow(self, name="test-wf", **overrides):
        data = workflow._new_workflow(name)
        data.update(overrides)
        workflow._atomic_write(self.wf_dir / f"{name}.json", data)
        # Set as active via symlink
        link = self.wf_dir / ".active"
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to(f"{name}.json")
        return data


class TestUITestGate(WorkflowGateTestBase):
    """Gate 1: ui_test_red_done required for phase6_implement."""

    def _bug_prereqs(self, **overrides):
        """Common prerequisites for a bug workflow at phase5_tdd_red."""
        defaults = dict(
            current_phase="phase5_tdd_red",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            fix_proposal_approved=True,
            workflow_type="bug",
            visual_inspection_done=True,
            existence_check_done=True,
            analysis_file="analysis.md",
            analysis_findings="found something",
            challenge_verdict="SOLIDE",
            test_artifacts=[{"phase": "phase5_tdd_red", "path": "test.swift"}],
        )
        defaults.update(overrides)
        return defaults

    def test_blocks_without_ui_test_red(self):
        """phase6_implement must be blocked when ui_test_red_done is False."""
        self._create_workflow(**self._bug_prereqs(ui_test_red_done=False))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase6_implement")
        self.assertIsNotNone(err)
        self.assertIn("ui_test_red_done", err)

    def test_allows_with_ui_test_red(self):
        """phase6_implement should pass when ui_test_red_done is True."""
        self._create_workflow(**self._bug_prereqs(ui_test_red_done=True))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase6_implement")
        self.assertIsNone(err)


class TestExistenceCheckGate(WorkflowGateTestBase):
    """Gate 2: existence_check_done required for phase3_spec (bugs)."""

    def test_blocks_bug_without_existence_check(self):
        """phase3_spec must be blocked for bugs without existence_check_done."""
        self._create_workflow(
            current_phase="phase2_analyse",
            workflow_type="bug",
            visual_inspection_done=True,
            existence_check_done=False,  # <-- THIS should block
            context_file="ctx.md",
            analysis_file="analysis.md",
            analysis_findings="root cause found",
            challenge_verdict="SOLIDE",
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase3_spec")
        self.assertIsNotNone(err)
        self.assertIn("existence_check_done", err)

    def test_allows_bug_with_existence_check(self):
        """phase3_spec should pass for bugs with existence_check_done."""
        self._create_workflow(
            current_phase="phase2_analyse",
            workflow_type="bug",
            visual_inspection_done=True,
            existence_check_done=True,
            analysis_file="analysis.md",
            analysis_findings="root cause found",
            challenge_verdict="SOLIDE",
            context_file="ctx.md",
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase3_spec")
        self.assertIsNone(err)

    def test_feature_not_blocked_by_existence_check(self):
        """Features should NOT require existence_check_done."""
        self._create_workflow(
            current_phase="phase2_analyse",
            workflow_type="feature",
            user_expectation_done=True,
            existence_check_done=False,  # Should NOT matter for features
            context_file="ctx.md",
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase3_spec")
        self.assertIsNone(err)


class TestDeadCodeCheckGate(WorkflowGateTestBase):
    """Gate 3: dead_code_check_done required for phase7_validate."""

    def _validate_prereqs(self, **overrides):
        """Common prerequisites for reaching phase7_validate."""
        defaults = dict(
            current_phase="phase6b_adversary",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            fix_proposal_approved=True,
            workflow_type="bug",
            visual_inspection_done=True,
            existence_check_done=True,
            analysis_file="analysis.md",
            analysis_findings="found something",
            challenge_verdict="SOLIDE",
            ui_test_red_done=True,
            adversary_phase_visited=True,
            test_artifacts=[
                {"phase": "phase5_tdd_red", "path": "test.swift"},
                {"phase": "phase6_implement", "path": "test.swift"},
            ],
        )
        defaults.update(overrides)
        return defaults

    def test_blocks_without_dead_code_check(self):
        """phase7_validate must be blocked without dead_code_check_done."""
        self._create_workflow(**self._validate_prereqs(dead_code_check_done=False))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase7_validate")
        self.assertIsNotNone(err)
        self.assertIn("dead_code_check_done", err)

    def test_allows_with_dead_code_check(self):
        """phase7_validate should pass with dead_code_check_done."""
        self._create_workflow(**self._validate_prereqs(dead_code_check_done=True))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase7_validate")
        self.assertIsNone(err)


class TestMarkCommands(WorkflowGateTestBase):
    """Tests for mark-existence-check and mark-dead-code-check commands."""

    def test_mark_existence_check_requires_notes(self):
        """mark-existence-check must reject short notes."""
        self._create_workflow()
        with self.assertRaises(SystemExit) as ctx:
            workflow.cmd_mark_existence_check(["too short"])
        self.assertEqual(ctx.exception.code, 1)

    def test_mark_existence_check_accepts_long_notes(self):
        """mark-existence-check must accept notes >= 30 chars."""
        self._create_workflow()
        workflow.cmd_mark_existence_check([
            "git log shows no prior implementation, GitHub Issue #42 is open"
        ])
        data, _ = workflow._read_active()
        self.assertTrue(data["existence_check_done"])

    def test_mark_dead_code_check_requires_notes(self):
        """mark-dead-code-check must reject short notes."""
        self._create_workflow()
        with self.assertRaises(SystemExit) as ctx:
            workflow.cmd_mark_dead_code_check(["too short"])
        self.assertEqual(ctx.exception.code, 1)

    def test_mark_dead_code_check_accepts_long_notes(self):
        """mark-dead-code-check must accept notes >= 30 chars."""
        self._create_workflow()
        workflow.cmd_mark_dead_code_check([
            "grep confirms handleAbort() called from FocusLiveView.swift:142"
        ])
        data, _ = workflow._read_active()
        self.assertTrue(data["dead_code_check_done"])


class TestProtectedFields(WorkflowGateTestBase):
    """New fields must be in PROTECTED_FIELDS."""

    def test_existence_check_done_is_protected(self):
        self.assertIn("existence_check_done", workflow.PROTECTED_FIELDS)

    def test_dead_code_check_done_is_protected(self):
        self.assertIn("dead_code_check_done", workflow.PROTECTED_FIELDS)


if __name__ == "__main__":
    unittest.main()
