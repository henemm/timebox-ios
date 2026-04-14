#!/usr/bin/env python3
"""Tests for 3-Checkpoint workflow system (v5).

Tests verify:
1. Checkpoint gates: phase transitions blocked without checkpoint approval
2. UI-Test-Pflicht: phase5_implement blocked without ui_test_red_done
3. Checkpoint fields are protected: Claude cannot set them directly
4. Phase listener integration: checkpoints only settable via WORKFLOW_CALLER
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
        self._patcher = patch.object(workflow, "_project_root",
                                     return_value=Path(self.tmpdir))
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def _create_workflow(self, name="test-wf", **overrides):
        data = workflow._new_workflow(name)
        data.update(overrides)
        workflow._atomic_write(self.wf_dir / f"{name}.json", data)
        link = self.wf_dir / ".active"
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to(f"{name}.json")
        return data


class TestCheckpoint1Gate(WorkflowGateTestBase):
    """Gate: checkpoint1_approved required for phase3_spec."""

    def test_blocks_without_checkpoint1(self):
        """phase3_spec must be blocked without checkpoint1_approved."""
        self._create_workflow(
            current_phase="phase2_analyse",
            context_file="ctx.md",
            checkpoint1_approved=False,
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase3_spec")
        self.assertIsNotNone(err)
        self.assertIn("Checkpoint 1", err)

    def test_allows_with_checkpoint1(self):
        """phase3_spec should pass with checkpoint1_approved."""
        self._create_workflow(
            current_phase="phase2_analyse",
            context_file="ctx.md",
            checkpoint1_approved=True,
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase3_spec")
        self.assertIsNone(err)


class TestCheckpoint2Gate(WorkflowGateTestBase):
    """Gate: checkpoint2_approved required for phase5_implement."""

    def _tdd_prereqs(self, **overrides):
        defaults = dict(
            current_phase="phase4_tdd_red",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.swift"}],
        )
        defaults.update(overrides)
        return defaults

    def test_blocks_without_checkpoint2(self):
        """phase5_implement must be blocked without checkpoint2_approved."""
        self._create_workflow(**self._tdd_prereqs(checkpoint2_approved=False))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase5_implement")
        self.assertIsNotNone(err)
        self.assertIn("Checkpoint 2", err)

    def test_allows_with_checkpoint2(self):
        """phase5_implement should pass with checkpoint2_approved."""
        self._create_workflow(**self._tdd_prereqs(checkpoint2_approved=True))
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase5_implement")
        self.assertIsNone(err)


class TestCheckpoint3Gate(WorkflowGateTestBase):
    """Gate: checkpoint3_approved required for phase6_done."""

    def test_blocks_without_checkpoint3(self):
        """phase6_done must be blocked without checkpoint3_approved."""
        self._create_workflow(
            current_phase="phase5_implement",
            context_file="ctx.md",
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            checkpoint3_approved=False,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.swift"}],
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase6_done")
        self.assertIsNotNone(err)
        self.assertIn("Checkpoint 3", err)

    def test_allows_with_checkpoint3(self):
        """phase6_done should pass with checkpoint3_approved."""
        self._create_workflow(
            current_phase="phase5_implement",
            context_file="ctx.md",
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            checkpoint3_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.swift"}],
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase6_done")
        self.assertIsNone(err)


class TestUITestGate(WorkflowGateTestBase):
    """Gate: ui_test_red_done required for phase5_implement."""

    def test_blocks_without_ui_test_red(self):
        """phase5_implement must be blocked when ui_test_red_done is False."""
        self._create_workflow(
            current_phase="phase4_tdd_red",
            context_file="ctx.md",
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=False,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.swift"}],
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase5_implement")
        self.assertIsNotNone(err)
        self.assertIn("ui_test_red_done", err)

    def test_allows_with_ui_test_red(self):
        """phase5_implement should pass when ui_test_red_done is True."""
        self._create_workflow(
            current_phase="phase4_tdd_red",
            context_file="ctx.md",
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.swift"}],
        )
        data, _ = workflow._read_active()
        err = workflow._validate_transition(data, "phase5_implement")
        self.assertIsNone(err)


class TestCheckpointProtection(WorkflowGateTestBase):
    """Checkpoint fields must be protected from direct Claude access."""

    def test_checkpoint_fields_are_protected(self):
        """All 3 checkpoint fields must be in PROTECTED_FIELDS."""
        self.assertIn("checkpoint1_approved", workflow.PROTECTED_FIELDS)
        self.assertIn("checkpoint2_approved", workflow.PROTECTED_FIELDS)
        self.assertIn("checkpoint3_approved", workflow.PROTECTED_FIELDS)

    def test_checkpoint_fields_are_in_checkpoint_set(self):
        """All 3 checkpoint fields must be in CHECKPOINT_FIELDS."""
        self.assertIn("checkpoint1_approved", workflow.CHECKPOINT_FIELDS)
        self.assertIn("checkpoint2_approved", workflow.CHECKPOINT_FIELDS)
        self.assertIn("checkpoint3_approved", workflow.CHECKPOINT_FIELDS)

    def test_set_field_blocks_checkpoint_without_caller(self):
        """set-field must block checkpoint fields without WORKFLOW_CALLER."""
        self._create_workflow()
        with patch.dict(os.environ, {"WORKFLOW_CALLER": ""}):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_set_field(["checkpoint1_approved", "true"])
            self.assertEqual(ctx.exception.code, 1)

    def test_set_field_allows_checkpoint_from_phase_listener(self):
        """set-field must allow checkpoint fields from phase_listener."""
        self._create_workflow()
        with patch.dict(os.environ, {"WORKFLOW_CALLER": "phase_listener"}):
            workflow.cmd_set_field(["checkpoint1_approved", "true"])
        data, _ = workflow._read_active()
        self.assertTrue(data["checkpoint1_approved"])

    def test_mark_checkpoint_blocks_without_caller(self):
        """mark-checkpoint1 must block without WORKFLOW_CALLER=phase_listener."""
        self._create_workflow()
        with patch.dict(os.environ, {"WORKFLOW_CALLER": ""}):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_mark_checkpoint1(["test"])
            self.assertEqual(ctx.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
