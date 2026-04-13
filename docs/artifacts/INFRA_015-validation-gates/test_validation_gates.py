#!/usr/bin/env python3
"""
TDD RED Tests fuer INFRA_015 — Validation Gate Hardening

Tests fuer 3 Massnahmen:
A) spec_validated Gate vor phase4_approved
B) spec_compliance_done + coverage_check_done in mark-validation-done
C) mark-regression-done Keyword-Validierung

Bricht wenn:
- workflow.py: mark-spec-validated Command fehlt
- workflow.py: _validate_transition spec_validated Check fehlt
- workflow.py: mark-spec-compliance / mark-coverage-check Commands fehlen
- workflow.py: mark-validation-done Prerequisites nicht erweitert
- workflow.py: mark-regression-done keine Keyword-Pruefung hat
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add hooks dir to path
PROJECT_ROOT = Path(__file__).resolve().parents[3]
HOOKS_DIR = PROJECT_ROOT / ".claude" / "hooks"
sys.path.insert(0, str(HOOKS_DIR))


class TestSpecValidatedGate(unittest.TestCase):
    """Massnahme A: Phase4 Transition blockiert ohne spec_validated."""

    def test_phase4_blocked_without_spec_validated(self):
        """AC1: _validate_transition blockiert phase4_approved ohne spec_validated.
        Bricht wenn: workflow.py den spec_validated Check nicht implementiert.
        """
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase3_spec",
            "context_file": "docs/context/test.md",
            "visual_inspection_done": True,
            "existence_check_done": True,
            "analysis_file": "docs/artifacts/test/analysis.md",
            "analysis_findings": "test findings for the analysis",
            "challenge_verdict": "SOLIDE — test verdict",
            "spec_file": "docs/specs/test/test.md",
            "spec_approved": True,
            # spec_validated FEHLT
        }

        error = workflow._validate_transition(data, "phase4_approved")
        self.assertIsNotNone(error, "phase4_approved sollte BLOCKED sein ohne spec_validated")
        self.assertIn("spec_validated", error)

    def test_phase4_allowed_with_spec_validated(self):
        """AC1: phase4_approved erlaubt wenn spec_validated = True."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase3_spec",
            "context_file": "docs/context/test.md",
            "visual_inspection_done": True,
            "existence_check_done": True,
            "analysis_file": "docs/artifacts/test/analysis.md",
            "analysis_findings": "test findings for the analysis",
            "challenge_verdict": "SOLIDE — test verdict",
            "spec_file": "docs/specs/test/test.md",
            "spec_approved": True,
            "spec_validated": True,
        }

        error = workflow._validate_transition(data, "phase4_approved")
        # Sollte NICHT wegen spec_validated blockieren
        # (kann wegen anderer Gates blockieren, aber NICHT wegen spec_validated)
        if error:
            self.assertNotIn("spec_validated", error,
                             "phase4_approved sollte NICHT wegen spec_validated blockieren")

    def test_mark_spec_validated_command_exists(self):
        """AC1: mark-spec-validated Command existiert in COMMANDS."""
        import workflow
        self.assertIn("mark-spec-validated", workflow.COMMANDS,
                       "mark-spec-validated Command fehlt in workflow.py COMMANDS")

    def test_mark_spec_validated_rejects_short_evidence(self):
        """AC1: mark-spec-validated blockiert bei zu kurzem Text."""
        import workflow

        # Erstelle temporaeren Workflow
        with tempfile.TemporaryDirectory() as tmpdir:
            wf_file = Path(tmpdir) / "test-wf.json"
            data = {"name": "test-wf", "current_phase": "phase3_spec"}
            wf_file.write_text(json.dumps(data))

            with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
                with self.assertRaises(SystemExit) as ctx:
                    workflow.cmd_mark_spec_validated(["short"])
                self.assertEqual(ctx.exception.code, 1)

    def test_spec_validated_is_protected_field(self):
        """AC1: spec_validated ist ein protected field."""
        import workflow
        self.assertIn("spec_validated", workflow.PROTECTED_FIELDS,
                       "spec_validated fehlt in PROTECTED_FIELDS")


class TestSpecComplianceAndCoverageGates(unittest.TestCase):
    """Massnahme B: mark-validation-done blockiert ohne compliance + coverage."""

    def test_validation_blocked_without_spec_compliance(self):
        """AC2: mark-validation-done blockiert ohne spec_compliance_done."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
            "green_test_done": True,
            "regression_check_done": True,
            "docs_updated": True,
            # spec_compliance_done FEHLT
            "coverage_check_done": True,
        }

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_mark_validation_done(["all checks passed"])
            self.assertEqual(ctx.exception.code, 1)

    def test_validation_blocked_without_coverage_check(self):
        """AC2: mark-validation-done blockiert ohne coverage_check_done."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
            "green_test_done": True,
            "regression_check_done": True,
            "docs_updated": True,
            "spec_compliance_done": True,
            # coverage_check_done FEHLT
        }

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_mark_validation_done(["all checks passed"])
            self.assertEqual(ctx.exception.code, 1)

    def test_validation_passes_with_all_flags(self):
        """AC2: mark-validation-done geht durch mit allen Flags."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
            "green_test_done": True,
            "regression_check_done": True,
            "docs_updated": True,
            "spec_compliance_done": True,
            "coverage_check_done": True,
        }

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with patch.object(workflow, '_save_active'):
                # Sollte NICHT blockieren
                workflow.cmd_mark_validation_done(["all checks passed"])
                self.assertTrue(data.get("validation_done"))

    def test_mark_spec_compliance_command_exists(self):
        """AC2: mark-spec-compliance Command existiert."""
        import workflow
        self.assertIn("mark-spec-compliance", workflow.COMMANDS)

    def test_mark_coverage_check_command_exists(self):
        """AC2: mark-coverage-check Command existiert."""
        import workflow
        self.assertIn("mark-coverage-check", workflow.COMMANDS)

    def test_spec_compliance_is_protected_field(self):
        """AC2: spec_compliance_done ist protected."""
        import workflow
        self.assertIn("spec_compliance_done", workflow.PROTECTED_FIELDS)

    def test_coverage_check_is_protected_field(self):
        """AC2: coverage_check_done ist protected."""
        import workflow
        self.assertIn("coverage_check_done", workflow.PROTECTED_FIELDS)


class TestRegressionKeywordValidation(unittest.TestCase):
    """Massnahme C: mark-regression-done erfordert 4 Suite-Namen."""

    REQUIRED_SUITES = [
        "FocusBloxTests",
        "BacklogViewUITests",
        "DayViewUITests",
        "CoachTabLayoutUITests",
    ]

    def test_regression_blocked_without_keywords(self):
        """AC3: mark-regression-done blockiert ohne Pflicht-Keywords."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
        }

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_mark_regression_done(["some random text without suite names"])
            self.assertEqual(ctx.exception.code, 1)

    def test_regression_blocked_with_partial_keywords(self):
        """AC3: mark-regression-done blockiert bei unvollstaendigen Keywords."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
        }

        # Nur 2 von 4 Keywords
        partial = "FocusBloxTests BacklogViewUITests passed"

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with self.assertRaises(SystemExit) as ctx:
                workflow.cmd_mark_regression_done([partial])
            self.assertEqual(ctx.exception.code, 1)

    def test_regression_passes_with_all_keywords(self):
        """AC3: mark-regression-done geht durch mit allen 4 Keywords."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
        }

        full = "Full suite: FocusBloxTests 45 passed, BacklogViewUITests 12 passed, DayViewUITests 8 passed, CoachTabLayoutUITests 5 passed, 0 regressions"

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with patch.object(workflow, '_save_active'):
                workflow.cmd_mark_regression_done([full])
                self.assertTrue(data.get("regression_check_done"))

    def test_regression_with_override_token_bypasses_keywords(self):
        """AC3: Override-Token umgeht Keyword-Pruefung."""
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase7_validate",
        }

        with patch.object(workflow, '_read_active', return_value=(data, "test-wf")):
            with patch.object(workflow, '_save_active'):
                with patch.object(workflow, '_has_override_token', return_value=True):
                    # Sollte NICHT blockieren trotz fehlender Keywords
                    workflow.cmd_mark_regression_done(["override: minimal test"])
                    self.assertTrue(data.get("regression_check_done"))


if __name__ == "__main__":
    unittest.main()
