#!/usr/bin/env python3
"""
TDD RED Tests for bug-workflow-phase-enforcement

Tests verify 3 fixes:
1. Missing commands: mark-green, mark-ui-green, mark-regression-done,
   mark-docs-updated, mark-validation-done
2. Protected fields: set-field blocks gate-critical fields
3. Phase6b gate: phase7_validate requires phase6b_adversary visited

ALL tests MUST FAIL (RED) before implementation.
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil
import unittest
from pathlib import Path


WORKFLOW_PY = Path(__file__).parent.parent.parent.parent / ".claude" / "hooks" / "workflow.py"
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent


def run_workflow(*args, env_extra=None):
    """Run workflow.py with args, return (stdout, stderr, returncode)."""
    env = os.environ.copy()
    env["WORKFLOW_PROJECT_ROOT"] = str(PROJECT_ROOT)
    if env_extra:
        env.update(env_extra)
    result = subprocess.run(
        [sys.executable, str(WORKFLOW_PY)] + list(args),
        capture_output=True, text=True, env=env,
        cwd=str(PROJECT_ROOT),
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


class WorkflowTestBase(unittest.TestCase):
    """Base class that creates a temporary workflow for testing."""

    def setUp(self):
        """Start a test workflow and advance to phase6_implement."""
        self.wf_name = "test-phase-enforcement"
        # Clean up any leftover test workflow
        run_workflow("complete")  # ignore errors
        # Start fresh
        run_workflow("start", self.wf_name)
        # Set required fields for phase progression
        run_workflow("set-field", "workflow_type", "bug")
        run_workflow("set-field", "context_file", "test-context.md")
        run_workflow("set-field", "visual_inspection_done", "true")
        run_workflow("set-field", "analysis_file", "test-analysis.md")
        run_workflow("set-field", "analysis_findings", "test findings")
        run_workflow("set-field", "challenge_verdict", "SOLIDE test")
        run_workflow("set-field", "spec_file", "test-spec.md")
        run_workflow("set-field", "spec_approved", "true")
        run_workflow("set-field", "fix_proposal_approved", "true")

    def tearDown(self):
        """Clean up test workflow."""
        run_workflow("complete")


# ============================================================
# Fix 1: Missing Commands
# ============================================================

class TestMarkGreenCommand(WorkflowTestBase):
    """mark-green command must exist and set green_test_done."""

    def test_mark_green_exists(self):
        """mark-green must be a recognized command.

        Breaks when: COMMANDS dict doesn't include 'mark-green'.
        Currently returns 'Unknown command: mark-green'.
        """
        stdout, stderr, rc = run_workflow("mark-green", "5 unit tests passed")
        self.assertEqual(rc, 0, f"mark-green should succeed, got: {stderr}")
        self.assertIn("green", stdout.lower())

    def test_mark_green_sets_field(self):
        """mark-green must set green_test_done=True on workflow state.

        Breaks when: cmd_mark_green doesn't write green_test_done field.
        """
        run_workflow("mark-green", "5 unit tests passed")
        stdout, _, _ = run_workflow("status")
        self.assertIn("green_test_done", stdout)


class TestMarkUiGreenCommand(WorkflowTestBase):
    """mark-ui-green command must exist and set ui_test_green_done."""

    def test_mark_ui_green_exists(self):
        """mark-ui-green must be a recognized command.

        Breaks when: COMMANDS dict doesn't include 'mark-ui-green'.
        Currently returns 'Unknown command: mark-ui-green'.
        """
        stdout, stderr, rc = run_workflow("mark-ui-green", "3 UI tests passed")
        self.assertEqual(rc, 0, f"mark-ui-green should succeed, got: {stderr}")
        self.assertIn("green", stdout.lower())

    def test_mark_ui_green_sets_field(self):
        """mark-ui-green must set ui_test_green_done=True.

        Breaks when: cmd_mark_ui_green doesn't write ui_test_green_done field.
        """
        run_workflow("mark-ui-green", "3 UI tests passed")
        stdout, _, _ = run_workflow("status")
        self.assertIn("ui_test_green_done", stdout)


class TestMarkRegressionDoneCommand(WorkflowTestBase):
    """mark-regression-done command must exist."""

    def test_mark_regression_done_exists(self):
        """mark-regression-done must be a recognized command.

        Breaks when: COMMANDS dict doesn't include 'mark-regression-done'.
        """
        stdout, stderr, rc = run_workflow("mark-regression-done", "Full suite: 10 unit + 3 UI, 0 regressions")
        self.assertEqual(rc, 0, f"mark-regression-done should succeed, got: {stderr}")

    def test_mark_regression_done_sets_field(self):
        """mark-regression-done must set regression_check_done=True.

        Breaks when: Field not written.
        """
        run_workflow("mark-regression-done", "0 regressions")
        stdout, _, _ = run_workflow("status")
        self.assertIn("regression_check_done", stdout)


class TestMarkDocsUpdatedCommand(WorkflowTestBase):
    """mark-docs-updated command must exist."""

    def test_mark_docs_updated_exists(self):
        """mark-docs-updated must be a recognized command.

        Breaks when: COMMANDS dict doesn't include 'mark-docs-updated'.
        """
        stdout, stderr, rc = run_workflow("mark-docs-updated", "GitHub Issue #200 closed")
        self.assertEqual(rc, 0, f"mark-docs-updated should succeed, got: {stderr}")

    def test_mark_docs_updated_sets_field(self):
        """mark-docs-updated must set docs_updated=True.

        Breaks when: Field not written.
        """
        run_workflow("mark-docs-updated", "Issue closed")
        stdout, _, _ = run_workflow("status")
        self.assertIn("docs_updated", stdout)


class TestMarkValidationDoneCommand(WorkflowTestBase):
    """mark-validation-done must exist and check prerequisites."""

    def test_mark_validation_done_exists(self):
        """mark-validation-done must be a recognized command.

        Breaks when: COMMANDS dict doesn't include 'mark-validation-done'.
        """
        # First set all prerequisites
        run_workflow("mark-green", "5 tests passed")
        run_workflow("mark-regression-done", "0 regressions")
        run_workflow("mark-docs-updated", "Issue closed")
        stdout, stderr, rc = run_workflow("mark-validation-done", "All 4 checks passed")
        self.assertEqual(rc, 0, f"mark-validation-done should succeed, got: {stderr}")

    def test_mark_validation_done_blocks_without_prerequisites(self):
        """mark-validation-done must FAIL if green/regression/docs not done.

        Breaks when: No prerequisite check in cmd_mark_validation_done.
        This is the key gate — validation_done means ALL sub-checks passed.
        """
        # Don't set any prerequisites
        stdout, stderr, rc = run_workflow("mark-validation-done", "fake")
        self.assertNotEqual(rc, 0, "mark-validation-done should FAIL without prerequisites")
        self.assertIn("BLOCKED", stderr)


# ============================================================
# Fix 2: Protected Fields
# ============================================================

class TestProtectedFields(WorkflowTestBase):
    """set-field must block gate-critical fields."""

    def test_adversary_verdict_blocked_via_set_field(self):
        """set-field must NOT allow setting adversary_verdict directly.

        Breaks when: cmd_set_field has no PROTECTED_FIELDS check.
        This is the most critical bypass — adversary_verdict must only
        be set by qa_gate.py through the legitimate path.
        """
        stdout, stderr, rc = run_workflow("set-field", "adversary_verdict", "VERIFIED:fake")
        self.assertNotEqual(rc, 0, "set-field should BLOCK adversary_verdict")
        self.assertIn("protected", stderr.lower())

    def test_green_test_done_blocked_via_set_field(self):
        """set-field must NOT allow setting green_test_done directly.

        Breaks when: green_test_done not in PROTECTED_FIELDS.
        """
        stdout, stderr, rc = run_workflow("set-field", "green_test_done", "true")
        self.assertNotEqual(rc, 0, "set-field should BLOCK green_test_done")

    def test_validation_done_blocked_via_set_field(self):
        """set-field must NOT allow setting validation_done directly.

        Breaks when: validation_done not in PROTECTED_FIELDS.
        """
        stdout, stderr, rc = run_workflow("set-field", "validation_done", "true")
        self.assertNotEqual(rc, 0, "set-field should BLOCK validation_done")

    def test_regression_check_done_blocked_via_set_field(self):
        """set-field must NOT allow setting regression_check_done directly.

        Breaks when: regression_check_done not in PROTECTED_FIELDS.
        """
        stdout, stderr, rc = run_workflow("set-field", "regression_check_done", "true")
        self.assertNotEqual(rc, 0, "set-field should BLOCK regression_check_done")

    def test_docs_updated_blocked_via_set_field(self):
        """set-field must NOT allow setting docs_updated directly.

        Breaks when: docs_updated not in PROTECTED_FIELDS.
        """
        stdout, stderr, rc = run_workflow("set-field", "docs_updated", "true")
        self.assertNotEqual(rc, 0, "set-field should BLOCK docs_updated")

    def test_normal_fields_still_work(self):
        """set-field must still work for non-protected fields.

        Breaks when: PROTECTED_FIELDS is too broad or breaks all set-field.
        """
        stdout, stderr, rc = run_workflow("set-field", "context_file", "new-context.md")
        self.assertEqual(rc, 0, f"Normal set-field should work, got: {stderr}")

    def test_qa_gate_caller_can_set_adversary_verdict(self):
        """qa_gate.py must still be able to set adversary_verdict.

        Breaks when: Protected fields have no exception for legitimate callers.
        The WORKFLOW_CALLER env var must bypass the protection for qa_gate.
        """
        stdout, stderr, rc = run_workflow(
            "set-field", "adversary_verdict", "VERIFIED:legitimate",
            env_extra={"WORKFLOW_CALLER": "qa_gate"}
        )
        self.assertEqual(rc, 0, f"qa_gate caller should be allowed, got: {stderr}")


# ============================================================
# Fix 3: Phase6b Gate
# ============================================================

class TestPhase6bGate(WorkflowTestBase):
    """phase7_validate must require phase6b_adversary visited."""

    def _advance_to_phase6(self):
        """Helper: advance workflow to phase6_implement."""
        run_workflow("phase", "phase2_analyse")
        run_workflow("phase", "phase3_spec")
        run_workflow("phase", "phase4_approved")
        run_workflow("phase", "phase5_tdd_red")
        # Add RED test artifact
        run_workflow("add-artifact", "test_output", "/tmp/test.txt",
                     "RED tests failed as expected", "phase5_tdd_red")
        run_workflow("phase", "phase6_implement")
        # Add GREEN test artifact
        run_workflow("add-artifact", "test_output", "/tmp/test.txt",
                     "GREEN tests passed", "phase6_implement")

    def test_phase7_blocked_without_phase6b(self):
        """Cannot jump from phase6_implement to phase7_validate without phase6b.

        Breaks when: _validate_transition has no phase6b enforcement.
        This is the structural gap — phase6b_adversary can be skipped entirely.
        """
        self._advance_to_phase6()
        # Try to jump directly to phase7_validate (skipping phase6b)
        stdout, stderr, rc = run_workflow("phase", "phase7_validate")
        self.assertNotEqual(rc, 0, "Should NOT be able to skip phase6b_adversary")
        self.assertIn("phase6b", stderr.lower())

    def test_phase7_allowed_after_phase6b(self):
        """Can reach phase7_validate after visiting phase6b_adversary.

        Breaks when: Phase6b gate is too strict and blocks even legitimate path.
        """
        self._advance_to_phase6()
        # Go through phase6b properly
        run_workflow("phase", "phase6b_adversary")
        # Now phase7 should be allowed
        stdout, stderr, rc = run_workflow("phase", "phase7_validate")
        self.assertEqual(rc, 0, f"phase7 should work after phase6b, got: {stderr}")


# ============================================================
# Fix 1+3 combined: New fields in _new_workflow
# ============================================================

class TestNewWorkflowFields(unittest.TestCase):
    """_new_workflow must include all new fields."""

    def test_new_fields_in_initial_state(self):
        """New workflow must have green_test_done, regression_check_done, etc.

        Breaks when: _new_workflow() doesn't initialize the new fields.
        """
        wf_name = "test-new-fields"
        run_workflow("start", wf_name)
        stdout, _, _ = run_workflow("status")
        run_workflow("complete")

        # Check all new fields exist in status output
        for field in ["green_test_done", "ui_test_green_done",
                       "regression_check_done", "docs_updated",
                       "validation_done"]:
            self.assertIn(field, stdout,
                          f"Field '{field}' missing from new workflow state")


if __name__ == "__main__":
    unittest.main(verbosity=2)
