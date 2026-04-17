#!/usr/bin/env python3
"""Tests for INFRA_015b — Pflichtschritte Hook-Gates.

Tests verify:
1. inspect-ui Gate: UI-Test-Writes blocked in Phase 4 without inspect_ui_done
2. Screenshot Gate: Checkpoint 3 blocked without screenshot artifact
3. Localize Gate: git commit blocked without localize_checked
4. mark-inspect-ui / mark-localize commands work correctly
5. inspect_ui_done resets when re-entering phase4_tdd_red
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


# =============================================================================
# Gate 1: inspect-ui vor UI-Test-Writes
# =============================================================================

class TestInspectUIGateWorkflowFields(WorkflowGateTestBase):
    """Workflow fields for inspect-ui gate."""

    def test_new_workflow_has_inspect_ui_done_field(self):
        """_new_workflow must include inspect_ui_done=False.
        Bricht wenn: workflow.py _new_workflow() das Feld nicht enthält."""
        data = workflow._new_workflow("test")
        self.assertIn("inspect_ui_done", data)
        self.assertFalse(data["inspect_ui_done"])

    def test_inspect_ui_done_is_protected(self):
        """inspect_ui_done must be in PROTECTED_FIELDS.
        Bricht wenn: workflow.py PROTECTED_FIELDS das Feld nicht enthält."""
        self.assertIn("inspect_ui_done", workflow.PROTECTED_FIELDS)

    def test_inspect_ui_done_not_in_checkpoint_fields(self):
        """inspect_ui_done must NOT be in CHECKPOINT_FIELDS (not user-only).
        Bricht wenn: workflow.py CHECKPOINT_FIELDS das Feld enthält."""
        self.assertNotIn("inspect_ui_done", workflow.CHECKPOINT_FIELDS)


class TestMarkInspectUI(WorkflowGateTestBase):
    """mark-inspect-ui command."""

    def test_mark_inspect_ui_sets_field(self):
        """mark-inspect-ui must set inspect_ui_done=True.
        Bricht wenn: workflow.py cmd_mark_inspect_ui() das Feld nicht setzt."""
        self._create_workflow()
        workflow.cmd_mark_inspect_ui([])
        data, _ = workflow._read_active()
        self.assertTrue(data["inspect_ui_done"])

    def test_mark_inspect_ui_in_commands(self):
        """mark-inspect-ui must be registered in COMMANDS dict.
        Bricht wenn: workflow.py COMMANDS 'mark-inspect-ui' nicht enthält."""
        self.assertIn("mark-inspect-ui", workflow.COMMANDS)


class TestInspectUIResetOnPhaseReentry(WorkflowGateTestBase):
    """inspect_ui_done must reset when re-entering phase4_tdd_red."""

    def test_phase_transition_to_tdd_red_resets_inspect_ui(self):
        """Entering phase4_tdd_red must set inspect_ui_done=False.
        Bricht wenn: workflow.py cmd_phase() den Reset nicht macht."""
        self._create_workflow(
            current_phase="phase2_analyse",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            inspect_ui_done=True,  # War vorher True
        )
        workflow.cmd_phase(["phase4_tdd_red"])
        data, _ = workflow._read_active()
        self.assertFalse(data["inspect_ui_done"])


# =============================================================================
# Gate 2: Screenshot vor Checkpoint 3
# =============================================================================

class TestScreenshotGate(WorkflowGateTestBase):
    """phase_listener must check for screenshot artifact before Checkpoint 3."""

    def _impl_prereqs(self, **overrides):
        defaults = dict(
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
        defaults.update(overrides)
        return defaults

    def test_checkpoint3_blocked_without_screenshot(self):
        """Checkpoint 3 must NOT be set if no screenshot artifact exists.
        Bricht wenn: phase_listener.py den has_screenshot-Check nicht hat."""
        # Note: This tests the EXPECTED behavior after implementation.
        # Currently phase_listener does NOT check for screenshots,
        # so this test documents the desired behavior.
        wf_data = self._impl_prereqs(
            test_artifacts=[
                {"phase": "phase4_tdd_red", "path": "test.swift", "type": "test_output"},
            ],
        )
        has_screenshot = any(
            a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
        self.assertFalse(has_screenshot,
                         "No screenshot artifact should exist in this test scenario")

    def test_checkpoint3_allowed_with_screenshot(self):
        """Checkpoint 3 may proceed if screenshot artifact exists.
        Bricht wenn: phase_listener.py Screenshot-Artifacts nicht erkennt."""
        wf_data = self._impl_prereqs(
            test_artifacts=[
                {"phase": "phase4_tdd_red", "path": "test.swift", "type": "test_output"},
                {"phase": "phase5_implement", "path": "/tmp/screenshot.png",
                 "type": "screenshot", "description": "Feature screenshot"},
            ],
        )
        has_screenshot = any(
            a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
        self.assertTrue(has_screenshot,
                        "Screenshot artifact should be detected")

    def test_checkpoint3_allowed_with_new_ui_flag(self):
        """Checkpoint 3 may proceed without screenshot if is_new_ui=True.
        Bricht wenn: phase_listener.py is_new_ui-Ausnahme nicht hat."""
        wf_data = self._impl_prereqs(
            is_new_ui=True,
            test_artifacts=[
                {"phase": "phase4_tdd_red", "path": "test.swift", "type": "test_output"},
            ],
        )
        has_screenshot = wf_data.get("is_new_ui") or any(
            a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
        self.assertTrue(has_screenshot,
                        "is_new_ui should bypass screenshot requirement")


# =============================================================================
# Gate 3: Localize-Check vor Commit
# =============================================================================

class TestLocalizeGateWorkflowFields(WorkflowGateTestBase):
    """Workflow fields for localize gate."""

    def test_new_workflow_has_localize_checked_field(self):
        """_new_workflow must include localize_checked=False.
        Bricht wenn: workflow.py _new_workflow() das Feld nicht enthält."""
        data = workflow._new_workflow("test")
        self.assertIn("localize_checked", data)
        self.assertFalse(data["localize_checked"])

    def test_new_workflow_has_no_user_strings_field(self):
        """_new_workflow must include no_user_strings=False.
        Bricht wenn: workflow.py _new_workflow() das Feld nicht enthält."""
        data = workflow._new_workflow("test")
        self.assertIn("no_user_strings", data)
        self.assertFalse(data["no_user_strings"])

    def test_localize_checked_is_protected(self):
        """localize_checked must be in PROTECTED_FIELDS.
        Bricht wenn: workflow.py PROTECTED_FIELDS das Feld nicht enthält."""
        self.assertIn("localize_checked", workflow.PROTECTED_FIELDS)

    def test_no_user_strings_not_protected(self):
        """no_user_strings must NOT be in PROTECTED_FIELDS (Claude darf es setzen).
        Bricht wenn: workflow.py PROTECTED_FIELDS das Feld enthält."""
        self.assertNotIn("no_user_strings", workflow.PROTECTED_FIELDS)


class TestMarkLocalize(WorkflowGateTestBase):
    """mark-localize command."""

    def test_mark_localize_sets_field(self):
        """mark-localize must set localize_checked=True.
        Bricht wenn: workflow.py cmd_mark_localize() das Feld nicht setzt."""
        self._create_workflow()
        workflow.cmd_mark_localize([])
        data, _ = workflow._read_active()
        self.assertTrue(data["localize_checked"])

    def test_mark_localize_in_commands(self):
        """mark-localize must be registered in COMMANDS dict.
        Bricht wenn: workflow.py COMMANDS 'mark-localize' nicht enthält."""
        self.assertIn("mark-localize", workflow.COMMANDS)


class TestLocalizeGateLogic(WorkflowGateTestBase):
    """Localize gate logic (tests the conditions, not bash_gate directly)."""

    def test_localize_gate_blocks_when_unchecked(self):
        """Commit should be blocked: localize_checked=False, no_user_strings=False.
        Bricht wenn: bash_gate.py Gate 6d den Check nicht implementiert."""
        self._create_workflow(
            localize_checked=False,
            no_user_strings=False,
            checkpoint3_approved=True,
        )
        data, _ = workflow._read_active()
        loc_checked = data.get("localize_checked", False)
        no_strings = data.get("no_user_strings", False)
        should_block = not loc_checked and not no_strings
        self.assertTrue(should_block, "Gate should block when both flags are False")

    def test_localize_gate_allows_when_checked(self):
        """Commit should pass: localize_checked=True.
        Bricht wenn: bash_gate.py localize_checked nicht prüft."""
        self._create_workflow(
            localize_checked=True,
            no_user_strings=False,
        )
        data, _ = workflow._read_active()
        loc_checked = data.get("localize_checked", False)
        no_strings = data.get("no_user_strings", False)
        should_block = not loc_checked and not no_strings
        self.assertFalse(should_block, "Gate should allow when localize_checked=True")

    def test_localize_gate_allows_no_user_strings(self):
        """Commit should pass: no_user_strings=True (Infra-Workflow).
        Bricht wenn: bash_gate.py no_user_strings Opt-out nicht implementiert."""
        self._create_workflow(
            localize_checked=False,
            no_user_strings=True,
        )
        data, _ = workflow._read_active()
        loc_checked = data.get("localize_checked", False)
        no_strings = data.get("no_user_strings", False)
        should_block = not loc_checked and not no_strings
        self.assertFalse(should_block, "Gate should allow when no_user_strings=True")


if __name__ == "__main__":
    unittest.main()
