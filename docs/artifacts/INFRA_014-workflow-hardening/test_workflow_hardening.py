#!/usr/bin/env python3
"""
TDD RED Tests für INFRA_014 — Workflow Hardening

Tests für 3 Maßnahmen:
A) Inspect-UI Gate in Phase 5
B) Spec-Testplan-Compliance im Adversary
C) Affected-Files Cross-Check (nur Prompt — kein Code-Test nötig)

Bricht wenn:
- edit_gate.py: inspect_ui_done Check in Phase 5 fehlt
- workflow.py: mark-inspect-ui-done Command fehlt
- adversary_dialog.py: parse_spec_test_plan() oder check_test_coverage() fehlt
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


class TestInspectUIGate(unittest.TestCase):
    """Maßnahme A: edit_gate.py muss UI-Test-Edits ohne /inspect-ui blockieren."""

    def _make_workflow(self, phase="phase5_tdd_red", inspect_ui_done=False,
                       ui_test_red_done=False, affected_files=None):
        """Helper: Workflow-JSON mit konfigurierbaren Feldern."""
        return {
            "name": "test-workflow",
            "current_phase": phase,
            "inspect_ui_done": inspect_ui_done,
            "ui_test_red_done": ui_test_red_done,
            "affected_files": affected_files or [],
            "red_test_done": False,
            "test_artifacts": [],
        }

    def test_inspect_ui_gate_blocks_ui_test_without_preflight(self):
        """AC-A1: UI-Test-Edit in Phase 5 OHNE inspect_ui_done → BLOCK.
        Bricht wenn: edit_gate.py den inspect_ui_done Check nicht implementiert.
        """
        import edit_gate

        # Workflow ohne inspect_ui_done
        workflow = self._make_workflow(
            phase="phase5_tdd_red",
            inspect_ui_done=False,
        )

        file_path = "FocusBloxUITests/SomeFeatureUITests.swift"

        # Patch: Workflow finden, der inspect_ui_done=False hat
        with patch.object(edit_gate, '_find_workflow_for_file', return_value=workflow), \
             patch.object(edit_gate, '_read_active_workflow', return_value=workflow), \
             patch.object(edit_gate, '_is_stop_locked', return_value=False), \
             patch.object(edit_gate, '_has_override_token', return_value=False):

            # edit_gate sollte exit(2) = BLOCK auslösen
            with self.assertRaises(SystemExit) as ctx:
                # Simuliere stdin-Input wie der Hook ihn bekommt
                os.environ["CLAUDE_TOOL_INPUT"] = json.dumps({"file_path": file_path})
                edit_gate.main()

            self.assertEqual(ctx.exception.code, 2,
                             "UI-Test-Edit ohne inspect_ui_done sollte BLOCKED sein (exit 2)")

    def test_inspect_ui_gate_allows_ui_test_with_preflight(self):
        """AC-A2: UI-Test-Edit in Phase 5 MIT inspect_ui_done → ALLOW.
        Bricht wenn: edit_gate.py den inspect_ui_done Check falsch implementiert.
        """
        import edit_gate

        workflow = self._make_workflow(
            phase="phase5_tdd_red",
            inspect_ui_done=True,
        )

        file_path = "FocusBloxUITests/SomeFeatureUITests.swift"

        with patch.object(edit_gate, '_find_workflow_for_file', return_value=workflow), \
             patch.object(edit_gate, '_read_active_workflow', return_value=workflow), \
             patch.object(edit_gate, '_is_stop_locked', return_value=False), \
             patch.object(edit_gate, '_has_override_token', return_value=False):

            with self.assertRaises(SystemExit) as ctx:
                os.environ["CLAUDE_TOOL_INPUT"] = json.dumps({"file_path": file_path})
                edit_gate.main()

            self.assertEqual(ctx.exception.code, 0,
                             "UI-Test-Edit MIT inspect_ui_done sollte ALLOWED sein (exit 0)")

    def test_inspect_ui_gate_ignores_unit_tests(self):
        """AC-A3: Unit-Test-Edit OHNE inspect_ui_done → ALLOW (kein Gate).
        Bricht wenn: edit_gate.py auch Unit-Tests blockiert.
        """
        import edit_gate

        workflow = self._make_workflow(
            phase="phase5_tdd_red",
            inspect_ui_done=False,  # Absichtlich false
        )

        file_path = "FocusBloxTests/SomeFeatureTests.swift"

        with patch.object(edit_gate, '_find_workflow_for_file', return_value=workflow), \
             patch.object(edit_gate, '_read_active_workflow', return_value=workflow), \
             patch.object(edit_gate, '_is_stop_locked', return_value=False), \
             patch.object(edit_gate, '_has_override_token', return_value=False):

            with self.assertRaises(SystemExit) as ctx:
                os.environ["CLAUDE_TOOL_INPUT"] = json.dumps({"file_path": file_path})
                edit_gate.main()

            self.assertEqual(ctx.exception.code, 0,
                             "Unit-Test-Edit sollte NICHT durch Inspect-UI Gate blockiert werden")


class TestSpecTestPlanParsing(unittest.TestCase):
    """Maßnahme B: adversary_dialog.py muss Testplan aus Spec extrahieren können."""

    def _create_spec_with_test_plan(self, test_items: list[str]) -> str:
        """Helper: Spec-Datei mit Test Plan Section erstellen."""
        lines = [
            "# Test Spec",
            "",
            "## Expected Behavior",
            "- Feature works correctly",
            "",
            "## Test Plan",
            "",
        ]
        for item in test_items:
            lines.append(f"- {item}")
        lines.extend(["", "## Known Limitations", "- None"])

        tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False)
        tmp.write("\n".join(lines))
        tmp.close()
        return tmp.name

    def test_parse_spec_test_plan_extracts_items(self):
        """AC-B1: Spec mit Test Plan → korrekte Liste.
        Bricht wenn: adversary_dialog.py parse_spec_test_plan() nicht existiert.
        """
        import adversary_dialog

        spec_path = self._create_spec_with_test_plan([
            "test_button_exists — Button ist sichtbar",
            "test_save_persists — Daten werden gespeichert",
            "test_cancel_discards — Abbrechen verwirft Änderungen",
        ])
        try:
            # Diese Funktion existiert noch NICHT → Test MUSS fehlschlagen
            result = adversary_dialog.parse_spec_test_plan(spec_path)
            self.assertEqual(len(result), 3)
            self.assertIn("test_button_exists", result[0])
        finally:
            os.unlink(spec_path)

    def test_check_test_coverage_finds_missing(self):
        """AC-B2: 3 geplante Tests, nur 2 vorhanden → 1 MISSING.
        Bricht wenn: adversary_dialog.py check_test_coverage() nicht existiert.
        """
        import adversary_dialog

        # Spec mit 3 geplanten Tests
        spec_path = self._create_spec_with_test_plan([
            "test_create_task — Task erstellen",
            "test_delete_task — Task löschen",
            "test_edit_task — Task bearbeiten",
        ])

        # Test-Datei mit nur 2 Tests
        test_file = tempfile.NamedTemporaryFile(mode="w", suffix=".swift", delete=False)
        test_file.write("""
import XCTest
final class TaskTests: XCTestCase {
    func test_create_task() { }
    func test_delete_task() { }
}
""")
        test_file.close()

        try:
            # Diese Funktion existiert noch NICHT → Test MUSS fehlschlagen
            missing = adversary_dialog.check_test_coverage(spec_path, [test_file.name])
            self.assertEqual(len(missing), 1)
            self.assertIn("edit_task", missing[0].lower())
        finally:
            os.unlink(spec_path)
            os.unlink(test_file.name)

    def test_check_test_coverage_all_present(self):
        """AC-B2 (Gegenprobe): Alle Tests vorhanden → 0 MISSING.
        Bricht wenn: check_test_coverage() false positives liefert.
        """
        import adversary_dialog

        spec_path = self._create_spec_with_test_plan([
            "test_create_task — Task erstellen",
            "test_delete_task — Task löschen",
        ])

        test_file = tempfile.NamedTemporaryFile(mode="w", suffix=".swift", delete=False)
        test_file.write("""
import XCTest
final class TaskTests: XCTestCase {
    func test_create_task() { }
    func test_delete_task() { }
}
""")
        test_file.close()

        try:
            missing = adversary_dialog.check_test_coverage(spec_path, [test_file.name])
            self.assertEqual(len(missing), 0,
                             "Alle Tests vorhanden — es sollten 0 MISSING sein")
        finally:
            os.unlink(spec_path)
            os.unlink(test_file.name)


class TestWorkflowInspectUIField(unittest.TestCase):
    """Maßnahme A (workflow.py): mark-inspect-ui-done Command muss existieren."""

    def test_mark_inspect_ui_done_sets_field(self):
        """AC-A4 Voraussetzung: mark-inspect-ui-done setzt inspect_ui_done=true.
        Bricht wenn: workflow.py den Command nicht implementiert.
        """
        import workflow

        # Prüfe ob der Command in der Command-Map registriert ist
        self.assertIn("mark-inspect-ui-done", workflow.COMMANDS,
                       "mark-inspect-ui-done muss als Command in workflow.py registriert sein")


class TestPhaseTransitionInspectUI(unittest.TestCase):
    """Maßnahme A: Phase5→Phase6 erfordert inspect_ui_done wenn UI-Tests da."""

    def test_transition_blocked_without_inspect_ui(self):
        """AC-A4: Phase5→Phase6 mit ui_test_red_done aber OHNE inspect_ui_done → BLOCK.
        Bricht wenn: _validate_transition den inspect_ui_done Check nicht hat.
        """
        import workflow

        data = {
            "name": "test-wf",
            "current_phase": "phase5_tdd_red",
            "context_file": "docs/context/test.md",
            "spec_file": "docs/specs/test.md",
            "spec_approved": True,
            "fix_proposal_approved": True,
            "ui_test_red_done": True,
            "red_test_done": True,
            "inspect_ui_done": False,  # NICHT gesetzt
            "test_artifacts": [
                {"phase": "phase5_tdd_red", "type": "test_output", "path": "x", "description": "y"}
            ],
            "workflow_type": "feature",
            "user_expectation_done": True,
        }

        error = workflow._validate_transition(data, "phase6_implement")
        self.assertIsNotNone(error,
                             "Transition phase5→phase6 sollte blockiert sein ohne inspect_ui_done")
        self.assertIn("inspect_ui", error.lower(),
                      "Fehlermeldung sollte 'inspect_ui' erwähnen")


if __name__ == "__main__":
    unittest.main()
