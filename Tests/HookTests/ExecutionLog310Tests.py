#!/usr/bin/env python3
"""
Tests für Feature #310: Execution Log + Phase Transition Audit Trail

TDD RED: Alle Tests MÜSSEN fehlschlagen — die neuen Felder/Funktionen
existieren noch nicht in workflow.py:
  - `_new_workflow()` kennt `phase_transitions`, `fix_loop_count`,
    `execution_log_written` noch nicht
  - `cmd_phase()` loggt noch keine Transitions und zählt keinen Fix-Loop
  - `cmd_complete()` schreibt noch kein Execution Log
  - `cmd_status()` zeigt `Fix-Loop-Count` noch nicht an
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Add hooks dir to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / ".claude" / "hooks"))

import workflow


# ---------------------------------------------------------------------------
# Gemeinsame Basis — identisches Pattern wie WorkflowEnforcement308ATests.py
# ---------------------------------------------------------------------------

class ExecutionLogTestBase(unittest.TestCase):
    """Base class: erstellt tempdir + patcht _project_root."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self._patcher = patch.object(workflow, "_project_root",
                                     return_value=Path(self.tmpdir))
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def _create_workflow(self, name="test-310", **overrides):
        """Hilfsfunktion: Workflow-State schreiben + .active-Symlink setzen."""
        data = workflow._new_workflow(name)
        data.update(overrides)
        wf_path = self.wf_dir / f"{name}.json"
        workflow._atomic_write(wf_path, data)
        link = self.wf_dir / ".active"
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to(f"{name}.json")
        return data

    def _complete_prereqs(self, **overrides):
        """Minimale Voraussetzungen für cmd_complete — Checkpoint 3 approved."""
        defaults = dict(
            current_phase="phase6_adversary",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            checkpoint3_approved=True,
            adversary_verdict="VERIFIED",
            adversary_run_count=1,
            green_test_done=True,
            workflow_type="feature",
        )
        defaults.update(overrides)
        return defaults


# ---------------------------------------------------------------------------
# AC-1: Phase Transition Audit Trail
# ---------------------------------------------------------------------------

class TestPhaseTransitionAuditTrail(ExecutionLogTestBase):
    """AC-1: phase_transitions[] wird bei jedem Phase-Wechsel befüllt."""

    def test_ac1_new_workflow_has_phase_transitions_field(self):
        # AC-1 — _new_workflow() muss phase_transitions initialisieren
        data = workflow._new_workflow("audit-trail-test")

        self.assertIn("phase_transitions", data,
                      "_new_workflow() muss phase_transitions als leere Liste initialisieren")
        self.assertIsInstance(data["phase_transitions"], list,
                              "phase_transitions muss eine Liste sein")
        self.assertEqual(len(data["phase_transitions"]), 0,
                         "phase_transitions muss bei neuem Workflow leer sein")

    def test_ac1_phase_transitions_contains_entry_after_phase_change(self):
        # AC-1 — Nach cmd_phase() muss ein Eintrag in phase_transitions erscheinen
        self._create_workflow(
            current_phase="phase1_context",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
        )

        # Act: Wechsel zu phase2_analyse (immer erlaubt wenn context_file + checkpoint1)
        workflow.cmd_phase(["phase2_analyse"])

        # Assert: Eintrag muss vorhanden sein
        data, _ = workflow._read_active()
        transitions = data.get("phase_transitions", [])
        self.assertGreater(len(transitions), 0,
                           "phase_transitions muss nach cmd_phase() mindestens einen Eintrag enthalten")

    def test_ac1_transition_entry_has_from_to_at_fields(self):
        # AC-1 — Eintrag muss {from, to, at} enthalten
        self._create_workflow(
            current_phase="phase1_context",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
        )

        workflow.cmd_phase(["phase2_analyse"])

        data, _ = workflow._read_active()
        transitions = data.get("phase_transitions", [])
        entry = transitions[-1] if transitions else {}

        self.assertIn("from", entry, "Transition-Eintrag muss 'from' enthalten")
        self.assertIn("to", entry, "Transition-Eintrag muss 'to' enthalten")
        self.assertIn("at", entry, "Transition-Eintrag muss 'at' (ISO-Timestamp) enthalten")

    def test_ac1_transition_entry_from_reflects_previous_phase(self):
        # AC-1 — 'from' muss die Phase vor dem Wechsel sein
        self._create_workflow(
            current_phase="phase1_context",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
        )

        workflow.cmd_phase(["phase2_analyse"])

        data, _ = workflow._read_active()
        transitions = data.get("phase_transitions", [])
        entry = transitions[-1] if transitions else {}

        self.assertEqual(entry.get("from"), "phase1_context",
                         "'from' muss die Phase vor dem Wechsel widerspiegeln")
        self.assertEqual(entry.get("to"), "phase2_analyse",
                         "'to' muss die Ziel-Phase widerspiegeln")

    def test_ac1_multiple_transitions_accumulate(self):
        # AC-1 — Mehrere Wechsel akkumulieren Einträge (nicht überschreiben)
        self._create_workflow(
            current_phase="phase1_context",
            context_file="ctx.md",
            checkpoint1_approved=True,
            spec_file="spec.md",
            spec_approved=True,
        )

        workflow.cmd_phase(["phase2_analyse"])
        workflow.cmd_phase(["phase3_spec"])

        data, _ = workflow._read_active()
        transitions = data.get("phase_transitions", [])

        self.assertGreaterEqual(len(transitions), 2,
                                "Zwei Phase-Wechsel müssen zwei Einträge in phase_transitions ergeben")


# ---------------------------------------------------------------------------
# AC-2: Fix-Loop-Count steigt bei BROKEN → phase5_implement
# ---------------------------------------------------------------------------

class TestFixLoopCountIncrement(ExecutionLogTestBase):
    """AC-2: fix_loop_count steigt bei BROKEN → phase5_implement."""

    def test_ac2_new_workflow_has_fix_loop_count_field(self):
        # AC-2 — _new_workflow() muss fix_loop_count initialisieren
        data = workflow._new_workflow("fix-loop-test")

        self.assertIn("fix_loop_count", data,
                      "_new_workflow() muss fix_loop_count initialisieren")
        self.assertEqual(data["fix_loop_count"], 0,
                         "fix_loop_count muss bei neuem Workflow 0 sein")

    def test_ac2_fix_loop_count_increments_when_broken_to_phase5(self):
        # AC-2 — BROKEN + phase5_implement → fix_loop_count von 0 auf 1
        self._create_workflow(
            current_phase="phase6_adversary",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            adversary_verdict="BROKEN",
            fix_loop_count=0,
            green_test_done=True,
            workflow_type="feature",
        )

        # Mocked git numstat — 0 LoC damit loc-check nicht blockiert
        mock_result = MagicMock()
        mock_result.stdout = "0\t0\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_phase(["phase5_implement"])

        data, _ = workflow._read_active()
        self.assertEqual(data.get("fix_loop_count"), 1,
                         "fix_loop_count muss nach BROKEN→phase5 von 0 auf 1 steigen")

    def test_ac2_fix_loop_count_increments_twice_on_second_broken_cycle(self):
        # AC-2 — Zweiter BROKEN-Durchlauf → fix_loop_count wird 2
        self._create_workflow(
            current_phase="phase6_adversary",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            adversary_verdict="BROKEN",
            fix_loop_count=1,  # bereits ein Durchlauf
            green_test_done=True,
            workflow_type="feature",
        )

        mock_result = MagicMock()
        mock_result.stdout = "0\t0\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_phase(["phase5_implement"])

        data, _ = workflow._read_active()
        self.assertEqual(data.get("fix_loop_count"), 2,
                         "fix_loop_count muss beim zweiten BROKEN-Durchlauf auf 2 steigen")


# ---------------------------------------------------------------------------
# AC-3: Fix-Loop-Count bleibt gleich bei VERIFIED → phase5_implement
# ---------------------------------------------------------------------------

class TestFixLoopCountNoIncrementOnVerified(ExecutionLogTestBase):
    """AC-3: fix_loop_count bleibt unverändert wenn adversary_verdict VERIFIED ist."""

    def test_ac3_new_workflow_initializes_fix_loop_count_and_verified_does_not_increment(self):
        # AC-3 — Kombinierter Test: Feld muss von _new_workflow() initialisiert sein
        # UND bei VERIFIED nicht inkrementiert werden.
        # Schritt 1: _new_workflow() muss fix_loop_count kennen — sonst FAIL hier.
        data = workflow._new_workflow("ac3-verified-test")
        self.assertIn("fix_loop_count", data,
                      "AC-3 Vorbedingung: _new_workflow() muss fix_loop_count initialisieren")

        # Schritt 2: Workflow mit VERIFIED aufsetzen und phase5 aufrufen
        self._create_workflow(
            name="ac3-verified-test",
            current_phase="phase6_adversary",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            adversary_verdict="VERIFIED",
            fix_loop_count=5,  # expliziter Startwert != 0
            green_test_done=True,
            workflow_type="feature",
        )

        mock_result = MagicMock()
        mock_result.stdout = "0\t0\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_phase(["phase5_implement"])

        data, _ = workflow._read_active()
        # Muss genau 5 sein — weder fehlendes Feld noch fälschliches Inkrement auf 6
        stored = data.get("fix_loop_count")
        self.assertIsNotNone(stored,
                             "fix_loop_count muss nach cmd_phase() im State vorhanden sein")
        self.assertEqual(stored, 5,
                         "fix_loop_count muss bei VERIFIED→phase5 exakt den Ausgangswert behalten")

    def test_ac3_fix_loop_count_not_incremented_without_adversary_verdict(self):
        # AC-3 — Kein Adversary-Lauf: fix_loop_count darf nicht steigen.
        # Kombiniert: Feld muss existieren UND bei None-Verdict nicht inkrementieren.
        data = workflow._new_workflow("ac3-no-verdict-test")
        self.assertIn("fix_loop_count", data,
                      "AC-3 Vorbedingung: _new_workflow() muss fix_loop_count initialisieren")

        self._create_workflow(
            name="ac3-no-verdict-test",
            current_phase="phase4_tdd_red",
            context_file="ctx.md",
            spec_file="spec.md",
            spec_approved=True,
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            adversary_verdict=None,
            fix_loop_count=7,  # expliziter Startwert != 0
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.py"}],
            workflow_type="feature",
        )

        mock_result = MagicMock()
        mock_result.stdout = "0\t0\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_phase(["phase5_implement"])

        data, _ = workflow._read_active()
        stored = data.get("fix_loop_count")
        self.assertIsNotNone(stored,
                             "fix_loop_count muss nach cmd_phase() im State vorhanden sein")
        self.assertEqual(stored, 7,
                         "fix_loop_count darf beim ersten Durchlauf (kein Adversary-Verdict) nicht steigen")


# ---------------------------------------------------------------------------
# AC-4: complete schreibt Execution Log automatisch
# ---------------------------------------------------------------------------

class TestExecutionLogWrittenOnComplete(ExecutionLogTestBase):
    """AC-4: workflow.py complete schreibt automatisch eine .json-Datei nach _logs/."""

    def test_ac4_complete_creates_log_file_in_logs_dir(self):
        # AC-4 — Nach cmd_complete() existiert eine JSON-Datei in _logs/
        self._create_workflow(name="my-workflow-310", **self._complete_prereqs())

        # Mocked git numstat für scope_loc_delta
        mock_result = MagicMock()
        mock_result.stdout = "10\t5\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_complete([])

        logs_dir = Path(self.tmpdir) / ".claude" / "workflows" / "_logs"
        log_files = list(logs_dir.glob("my-workflow-310-*.json"))

        self.assertGreater(len(log_files), 0,
                           "cmd_complete() muss eine .json-Datei in _logs/ schreiben")


# ---------------------------------------------------------------------------
# AC-5: Log-Inhalt enthält alle Pflichtfelder
# ---------------------------------------------------------------------------

class TestExecutionLogContent(ExecutionLogTestBase):
    """AC-5: Das geschriebene Log enthält alle Pflichtfelder."""

    REQUIRED_FIELDS = [
        "workflow",
        "workflow_type",
        "outcome",
        "phases_completed",
        "tdd_red_confirmed",
        "adversary_verdict",
        "adversary_run_count",
        "fix_loop_count",
        "scope_loc_delta",
        "completed_at",
    ]

    def _run_complete_and_get_log(self, wf_name="test-log-content", **overrides) -> dict:
        """Führt cmd_complete aus und liest die geschriebene Log-Datei."""
        self._create_workflow(name=wf_name, **self._complete_prereqs(**overrides))

        mock_result = MagicMock()
        mock_result.stdout = "20\t8\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_complete([])

        logs_dir = Path(self.tmpdir) / ".claude" / "workflows" / "_logs"
        log_files = list(logs_dir.glob(f"{wf_name}-*.json"))
        self.assertEqual(len(log_files), 1,
                         f"Genau eine Log-Datei erwartet, gefunden: {len(log_files)}")
        return json.loads(log_files[0].read_text())

    def test_ac5_log_contains_workflow_name(self):
        # AC-5
        log = self._run_complete_and_get_log(wf_name="test-log-content")
        self.assertIn("workflow", log)
        self.assertEqual(log["workflow"], "test-log-content")

    def test_ac5_log_contains_workflow_type(self):
        # AC-5
        log = self._run_complete_and_get_log(workflow_type="bug")
        self.assertIn("workflow_type", log)
        self.assertEqual(log["workflow_type"], "bug")

    def test_ac5_log_contains_outcome(self):
        # AC-5
        log = self._run_complete_and_get_log()
        self.assertIn("outcome", log)

    def test_ac5_log_contains_phases_completed(self):
        # AC-5
        log = self._run_complete_and_get_log()
        self.assertIn("phases_completed", log)
        self.assertIsInstance(log["phases_completed"], list)

    def test_ac5_log_contains_tdd_red_confirmed(self):
        # AC-5
        log = self._run_complete_and_get_log()
        self.assertIn("tdd_red_confirmed", log)

    def test_ac5_log_contains_adversary_verdict(self):
        # AC-5
        log = self._run_complete_and_get_log(adversary_verdict="VERIFIED")
        self.assertIn("adversary_verdict", log)
        self.assertEqual(log["adversary_verdict"], "VERIFIED")

    def test_ac5_log_contains_adversary_run_count(self):
        # AC-5
        log = self._run_complete_and_get_log(adversary_run_count=2)
        self.assertIn("adversary_run_count", log)
        self.assertEqual(log["adversary_run_count"], 2)

    def test_ac5_log_contains_fix_loop_count(self):
        # AC-5
        log = self._run_complete_and_get_log()
        self.assertIn("fix_loop_count", log)

    def test_ac5_log_contains_scope_loc_delta(self):
        # AC-5 — scope_loc_delta muss berechnet werden (20 + 8 = 28 aus mock)
        log = self._run_complete_and_get_log()
        self.assertIn("scope_loc_delta", log)
        self.assertEqual(log["scope_loc_delta"], 28,
                         "scope_loc_delta muss Additions + Deletions aus git diff summieren")

    def test_ac5_log_contains_completed_at(self):
        # AC-5
        log = self._run_complete_and_get_log()
        self.assertIn("completed_at", log)
        self.assertIsInstance(log["completed_at"], str)
        # ISO-Timestamp muss mindestens Datum enthalten (YYYY-MM-DD)
        self.assertRegex(log["completed_at"], r"\d{4}-\d{2}-\d{2}",
                         "completed_at muss ein ISO-Timestamp sein")

    def test_ac5_all_required_fields_present(self):
        # AC-5 — Sammeltest: alle Pflichtfelder auf einmal prüfen
        log = self._run_complete_and_get_log()
        missing = [f for f in self.REQUIRED_FIELDS if f not in log]
        self.assertEqual(missing, [],
                         f"Folgende Pflichtfelder fehlen im Log: {missing}")


# ---------------------------------------------------------------------------
# AC-6: status zeigt Fix-Loop-Count an
# ---------------------------------------------------------------------------

class TestStatusShowsFixLoopCount(ExecutionLogTestBase):
    """AC-6: workflow.py status gibt eine Zeile 'Fix-Loop-Count: <n>' aus."""

    def test_ac6_status_output_contains_fix_loop_count_line(self):
        # AC-6 — Statusausgabe muss Fix-Loop-Count enthalten
        self._create_workflow(fix_loop_count=0)

        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            workflow.cmd_status([])
        output = buf.getvalue()

        self.assertIn("Fix-Loop-Count", output,
                      "cmd_status() muss 'Fix-Loop-Count' in der Ausgabe enthalten")

    def test_ac6_status_shows_correct_fix_loop_count_value(self):
        # AC-6 — Wert muss korrekt aus State gelesen werden
        self._create_workflow(fix_loop_count=3)

        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            workflow.cmd_status([])
        output = buf.getvalue()

        self.assertIn("Fix-Loop-Count: 3", output,
                      "cmd_status() muss den korrekten fix_loop_count-Wert anzeigen")

    def test_ac6_status_shows_zero_by_default(self):
        # AC-6 — Bei neuem Workflow muss Fix-Loop-Count: 0 stehen
        self._create_workflow()  # kein fix_loop_count Override

        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            workflow.cmd_status([])
        output = buf.getvalue()

        self.assertIn("Fix-Loop-Count: 0", output,
                      "cmd_status() muss bei neuem Workflow 'Fix-Loop-Count: 0' anzeigen")


# ---------------------------------------------------------------------------
# AC-7: _logs/-Verzeichnis wird bei Bedarf angelegt
# ---------------------------------------------------------------------------

class TestLogsDirectoryCreatedIfMissing(ExecutionLogTestBase):
    """AC-7: cmd_complete() legt _logs/ an wenn es nicht existiert."""

    def test_ac7_logs_dir_created_automatically_if_missing(self):
        # AC-7 — _logs/ darf nicht vorher existieren
        logs_dir = Path(self.tmpdir) / ".claude" / "workflows" / "_logs"
        self.assertFalse(logs_dir.exists(),
                         "Vorbedingung: _logs/ darf noch nicht existieren")

        self._create_workflow(**self._complete_prereqs())

        mock_result = MagicMock()
        mock_result.stdout = "5\t2\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_complete([])

        self.assertTrue(logs_dir.exists(),
                        "cmd_complete() muss _logs/ automatisch anlegen wenn es fehlt")

    def test_ac7_complete_writes_log_even_when_logs_dir_already_exists(self):
        # AC-7 — Auch wenn _logs/ bereits existiert muss das Log geschrieben werden.
        # Beweist dass mkdir(exist_ok=True) verwendet wird UND Log-Schreiben erfolgt.
        logs_dir = Path(self.tmpdir) / ".claude" / "workflows" / "_logs"
        logs_dir.mkdir(parents=True)
        self.assertTrue(logs_dir.exists(), "Vorbedingung: _logs/ existiert bereits")

        self._create_workflow(name="existing-dir-test", **self._complete_prereqs())

        mock_result = MagicMock()
        mock_result.stdout = "5\t2\tsome/file.py\n"
        with patch("subprocess.run", return_value=mock_result):
            workflow.cmd_complete([])

        # Log-Datei muss trotzdem existieren — beweist dass das Feature funktioniert
        log_files = list(logs_dir.glob("existing-dir-test-*.json"))
        self.assertEqual(len(log_files), 1,
                         "cmd_complete() muss Log schreiben auch wenn _logs/ bereits existiert")


# ---------------------------------------------------------------------------
# Zusatz: execution_log_written Guard (aus Spec: Guard gegen Doppelschreiben)
# ---------------------------------------------------------------------------

class TestExecutionLogWrittenGuard(ExecutionLogTestBase):
    """Stellt sicher dass execution_log_written als Guard-Feld initialisiert wird."""

    def test_new_workflow_has_execution_log_written_false(self):
        # AC-4 (Initialisierung) — Guard-Feld muss initialisiert sein
        data = workflow._new_workflow("guard-test")

        self.assertIn("execution_log_written", data,
                      "_new_workflow() muss execution_log_written initialisieren")
        self.assertFalse(data["execution_log_written"],
                         "execution_log_written muss bei neuem Workflow False sein")


if __name__ == "__main__":
    unittest.main(verbosity=2)
