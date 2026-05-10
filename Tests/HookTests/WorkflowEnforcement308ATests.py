#!/usr/bin/env python3
"""
Tests für Feature #308-A: Workflow Enforcement

Drei Enforcement-Bereiche:
  A) Kumulativer LoC-Delta-Check in workflow.py _validate_transition()
  B) AC-Format-Check in workflow.py _validate_transition()
  C) Adversary-Verdict-Gate in bash_gate.py Commit-Gate

TDD RED: Alle Tests MÜSSEN fehlschlagen — die Funktionen sind noch nicht implementiert.
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
# Gemeinsame Basis — Workflow-State in tempdir
# ---------------------------------------------------------------------------

class EnforcementTestBase(unittest.TestCase):
    """Base class: erstellt tempdir + patches _project_root."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self._patcher = patch.object(workflow, "_project_root",
                                     return_value=Path(self.tmpdir))
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def _create_workflow(self, name="test-308a", **overrides):
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

    def _phase5_prereqs(self, **overrides):
        """Alle Voraussetzungen für phase5_implement — ausser dem was getestet wird."""
        defaults = dict(
            current_phase="phase4_tdd_red",
            context_file="ctx.md",
            checkpoint1_approved=True,
            checkpoint2_approved=True,
            spec_file="spec.md",
            spec_approved=True,
            ui_test_red_done=True,
            test_artifacts=[{"phase": "phase4_tdd_red", "path": "test.py"}],
        )
        defaults.update(overrides)
        return defaults

    def _make_git_numstat_output(self, added: int, deleted: int) -> str:
        """Hilfsfunktion: git diff --numstat Ausgabe simulieren."""
        return f"{added}\t{deleted}\tsome/file.py\n"


# ---------------------------------------------------------------------------
# A) LoC-Delta-Check — AC-1, AC-2, AC-3
# ---------------------------------------------------------------------------

class TestLocLimitFeatureWorkflow(EnforcementTestBase):
    """AC-1: Feature-Workflow mit >250 LoC wird blockiert."""

    def test_ac1_loc_limit_feature_workflow_blocked_above_250(self):
        # AC-1
        # Given: Feature-Workflow, 251 geänderte LoC
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="feature",
                loc_limit_override=False,
            )
        )
        data, _ = workflow._read_active()

        # Act: _validate_transition mit gemocktem git-Output (130 additions + 121 deletions = 251)
        git_output = self._make_git_numstat_output(added=130, deleted=121)
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        # Assert: Transition muss blockiert sein mit LoC-Meldung
        self.assertIsNotNone(err, "Feature-Workflow mit 251 LoC muss blockiert werden")
        self.assertIn("BLOCKED", err)
        self.assertIn("251", err)
        self.assertIn("250", err)

    def test_ac1_loc_limit_feature_workflow_passes_at_250(self):
        # AC-1 (Grenzwert: genau 250 ist erlaubt)
        # Given: Feature-Workflow, exakt 250 geänderte LoC
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="feature",
                loc_limit_override=False,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=125, deleted=125)  # = 250
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNone(err, "Feature-Workflow mit exakt 250 LoC darf NICHT blockiert werden")


class TestLocLimitBugWorkflow(EnforcementTestBase):
    """AC-2: Bug-Workflow mit >150 LoC wird blockiert (niedrigerer Threshold)."""

    def test_ac2_loc_limit_bug_workflow_blocked_above_150(self):
        # AC-2
        # Given: Bug-Workflow, 151 geänderte LoC
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="bug",
                loc_limit_override=False,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=80, deleted=71)  # = 151
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        # Assert: Blockiert mit Bug-spezifischem Threshold 150
        self.assertIsNotNone(err, "Bug-Workflow mit 151 LoC muss blockiert werden")
        self.assertIn("BLOCKED", err)
        self.assertIn("151", err)
        self.assertIn("150", err)

    def test_ac2_bug_threshold_is_not_250(self):
        # AC-2 — Stellt sicher dass Bug-Threshold != Feature-Threshold
        # Given: Bug-Workflow mit 200 LoC — wäre bei Feature erlaubt, muss bei Bug blockiert sein
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="bug",
                loc_limit_override=False,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=100, deleted=100)  # = 200
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNotNone(err, "Bug-Workflow mit 200 LoC muss blockiert werden (Threshold 150, nicht 250)")

    def test_ac2_loc_limit_bug_workflow_passes_at_150(self):
        # AC-2 (Grenzwert: genau 150 ist erlaubt)
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="bug",
                loc_limit_override=False,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=75, deleted=75)  # = 150
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNone(err, "Bug-Workflow mit exakt 150 LoC darf NICHT blockiert werden")


class TestLocLimitOverride(EnforcementTestBase):
    """AC-3: loc_limit_override=True deaktiviert den LoC-Check."""

    def test_ac3_loc_override_bypasses_feature_limit(self):
        # AC-3
        # Given: Feature-Workflow, 999 LoC, ABER loc_limit_override=True
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="feature",
                loc_limit_override=True,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=500, deleted=499)  # = 999
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        # Assert: LoC-Check darf NICHT blockieren wenn Override gesetzt
        self.assertIsNone(err, "Mit loc_limit_override=True darf LoC-Check nicht blockieren")

    def test_ac3_loc_override_bypasses_bug_limit(self):
        # AC-3
        # Given: Bug-Workflow, 500 LoC, ABER loc_limit_override=True
        self._create_workflow(
            **self._phase5_prereqs(
                workflow_type="bug",
                loc_limit_override=True,
            )
        )
        data, _ = workflow._read_active()

        git_output = self._make_git_numstat_output(added=250, deleted=250)  # = 500
        mock_result = MagicMock()
        mock_result.stdout = git_output

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNone(err, "Mit loc_limit_override=True darf LoC-Check nicht blockieren (Bug-Workflow)")

    def test_ac3_new_workflow_has_loc_override_false_by_default(self):
        # AC-3 — Stellt sicher dass Override standardmäßig nicht gesetzt ist
        data = workflow._new_workflow("default-test")
        self.assertIn("loc_limit_override", data,
                      "_new_workflow() muss loc_limit_override initialisieren")
        self.assertFalse(data["loc_limit_override"],
                         "loc_limit_override muss standardmäßig False sein")


# ---------------------------------------------------------------------------
# B) AC-Format-Check — AC-4, AC-5
# ---------------------------------------------------------------------------

class TestAcFormatCheck(EnforcementTestBase):
    """AC-4 & AC-5: Spec muss ## Acceptance Criteria + AC-1 Item enthalten."""

    def _create_spec_file(self, content: str) -> str:
        """Schreibt eine temporäre Spec-Datei und gibt den Pfad zurück."""
        spec_path = Path(self.tmpdir) / "spec.md"
        spec_path.write_text(content)
        return str(spec_path)

    def test_ac4_blocked_when_spec_has_no_acceptance_criteria_section(self):
        # AC-4
        # Given: Spec ohne ## Acceptance Criteria
        spec_without_ac = """
# My Feature Spec

## Purpose
Does something useful.

## Implementation
Some details here.
"""
        spec_path = self._create_spec_file(spec_without_ac)
        self._create_workflow(
            **self._phase5_prereqs(
                spec_file=spec_path,
                workflow_type="feature",
                loc_limit_override=True,  # LoC-Check umgehen, nur AC-Check testen
            )
        )
        data, _ = workflow._read_active()

        # LoC-Check umgehen: 0 LoC simulieren
        mock_result = MagicMock()
        mock_result.stdout = self._make_git_numstat_output(0, 0)

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNotNone(err, "Spec ohne ## Acceptance Criteria muss blockiert werden")
        self.assertIn("BLOCKED", err)
        self.assertIn("Acceptance Criteria", err)

    def test_ac4_blocked_when_spec_has_section_but_no_ac_item(self):
        # AC-4
        # Given: Spec mit ## Acceptance Criteria Abschnitt, aber ohne AC-1 Item
        spec_with_empty_ac = """
# My Feature Spec

## Acceptance Criteria

This section exists but has no actual AC items listed.
"""
        spec_path = self._create_spec_file(spec_with_empty_ac)
        self._create_workflow(
            **self._phase5_prereqs(
                spec_file=spec_path,
                workflow_type="feature",
                loc_limit_override=True,
            )
        )
        data, _ = workflow._read_active()

        mock_result = MagicMock()
        mock_result.stdout = self._make_git_numstat_output(0, 0)

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNotNone(err, "Spec ohne AC-N Item muss blockiert werden")
        self.assertIn("BLOCKED", err)

    def test_ac5_passes_with_bold_ac_format(self):
        # AC-5
        # Given: Spec mit ## Acceptance Criteria und **AC-1** Format
        valid_spec_bold = """
# My Feature Spec

## Acceptance Criteria

**AC-1** — Feature tut X wenn Y.

**AC-2** — Feature zeigt Z.
"""
        spec_path = self._create_spec_file(valid_spec_bold)
        self._create_workflow(
            **self._phase5_prereqs(
                spec_file=spec_path,
                workflow_type="feature",
                loc_limit_override=True,
            )
        )
        data, _ = workflow._read_active()

        mock_result = MagicMock()
        mock_result.stdout = self._make_git_numstat_output(0, 0)

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNone(err, "Spec mit **AC-1** Format darf NICHT durch AC-Check blockiert werden")

    def test_ac5_passes_with_dash_ac_format(self):
        # AC-5
        # Given: Spec mit ## Acceptance Criteria und - AC-1: Format
        valid_spec_dash = """
# My Feature Spec

## Acceptance Criteria

- AC-1: Feature tut X wenn Y.
- AC-2: Feature zeigt Z.
"""
        spec_path = self._create_spec_file(valid_spec_dash)
        self._create_workflow(
            **self._phase5_prereqs(
                spec_file=spec_path,
                workflow_type="feature",
                loc_limit_override=True,
            )
        )
        data, _ = workflow._read_active()

        mock_result = MagicMock()
        mock_result.stdout = self._make_git_numstat_output(0, 0)

        with patch("subprocess.run", return_value=mock_result):
            err = workflow._validate_transition(data, "phase5_implement")

        self.assertIsNone(err, "Spec mit - AC-1: Format darf NICHT durch AC-Check blockiert werden")


# ---------------------------------------------------------------------------
# C) Adversary-Verdict im Commit-Gate — AC-6 bis AC-10
#
# bash_gate.py wird via subprocess getestet (kein direkter Import, da bash_gate
# als Hook-Script konzipiert ist und sys.exit() aufruft).
# Wir übergeben einen echten git-commit-Befehl im Input-JSON.
# ---------------------------------------------------------------------------

class TestAdversaryCommitGate(unittest.TestCase):
    """AC-6 bis AC-10: bash_gate.py blockiert/erlaubt Commits basierend auf adversary_verdict."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmpdir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)
        self.hooks_dir = Path(__file__).parent.parent.parent / ".claude" / "hooks"

    def _write_workflow_state(self, **fields) -> None:
        """Schreibt Workflow-State in tempdir und setzt .active-Symlink."""
        base = {
            "name": "test-308a",
            "current_phase": "phase7_done",
            "checkpoint3_approved": True,
            "adversary_verdict": None,
            "adversary_override_ambiguous": False,
            "adversary_findings": [],
            "localize_checked": True,
            "no_user_strings": False,
        }
        base.update(fields)
        wf_path = self.wf_dir / "test-308a.json"
        wf_path.write_text(json.dumps(base, indent=2))
        link = self.wf_dir / ".active"
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to("test-308a.json")

    def _run_bash_gate(self, commit_message: str) -> tuple[int, str]:
        """
        Führt bash_gate.py als Subprocess aus.
        Gibt (exit_code, stderr) zurück.
        """
        import subprocess
        command = f'git commit -m "feat: test commit #123 {commit_message}"'
        stdin_payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmpdir
        env["CLAUDE_ADMIN"] = ""  # Hooks aktiv halten
        env.pop("CLAUDE_SESSION_ID", None)  # Kein Session-Mapping, .active wird benutzt
        result = subprocess.run(
            [sys.executable, str(self.hooks_dir / "bash_gate.py")],
            input=stdin_payload,
            capture_output=True,
            text=True,
            env=env,
        )
        return result.returncode, result.stderr

    def test_ac6_commit_blocked_when_adversary_verdict_is_none(self):
        # AC-6
        # Given: Kein Adversary-Lauf (adversary_verdict=None)
        self._write_workflow_state(adversary_verdict=None)

        exit_code, stderr = self._run_bash_gate("no adversary run")

        self.assertEqual(exit_code, 2,
                         "Commit muss blockiert werden wenn adversary_verdict=None")
        self.assertIn("BLOCKED", stderr)
        self.assertIn("Adversary", stderr)

    def test_ac7_commit_blocked_when_adversary_verdict_is_broken(self):
        # AC-7
        # Given: Adversary-Verdict ist BROKEN
        self._write_workflow_state(adversary_verdict="BROKEN")

        exit_code, stderr = self._run_bash_gate("broken implementation")

        self.assertEqual(exit_code, 2,
                         "Commit muss blockiert werden wenn adversary_verdict=BROKEN")
        self.assertIn("BLOCKED", stderr)
        self.assertIn("BROKEN", stderr)

    def test_ac8_commit_blocked_when_ambiguous_without_override(self):
        # AC-8
        # Given: Adversary-Verdict ist AMBIGUOUS, kein Override
        self._write_workflow_state(
            adversary_verdict="AMBIGUOUS",
            adversary_override_ambiguous=False,
        )

        exit_code, stderr = self._run_bash_gate("ambiguous result")

        self.assertEqual(exit_code, 2,
                         "Commit muss blockiert werden wenn AMBIGUOUS ohne Override")
        self.assertIn("BLOCKED", stderr)
        self.assertIn("AMBIGUOUS", stderr)
        # Muss auf override-ambiguous als Ausweg hinweisen
        self.assertIn("override-ambiguous", stderr)

    def test_ac9_commit_allowed_when_ambiguous_with_override(self):
        # AC-9
        # Given: Adversary-Verdict ist AMBIGUOUS, Override gesetzt
        self._write_workflow_state(
            adversary_verdict="AMBIGUOUS",
            adversary_override_ambiguous=True,
        )

        exit_code, stderr = self._run_bash_gate("ambiguous but overridden")

        # Assert: Adversary-Gate darf NICHT blockieren (andere Gates könnten noch blockieren,
        # aber NICHT wegen AMBIGUOUS)
        adversary_blocked = exit_code == 2 and "AMBIGUOUS" in stderr
        self.assertFalse(adversary_blocked,
                         "AMBIGUOUS mit Override darf NICHT vom Adversary-Gate blockiert werden")

    def test_ac10_commit_allowed_when_verdict_is_verified(self):
        # AC-10
        # Given: Adversary-Verdict ist VERIFIED
        self._write_workflow_state(adversary_verdict="VERIFIED")

        exit_code, stderr = self._run_bash_gate("verified implementation")

        # Assert: Adversary-Gate darf NICHT blockieren wegen Verdict
        adversary_verdict_blocked = (
            exit_code == 2 and
            any(kw in stderr for kw in ["BROKEN", "AMBIGUOUS", "Adversary-Lauf", "Kein Adversary"])
        )
        self.assertFalse(adversary_verdict_blocked,
                         "VERIFIED-Verdict darf NICHT vom Adversary-Gate blockiert werden")

    def test_ac6_new_workflow_has_adversary_override_false_by_default(self):
        # AC-6 (Initialisierung)
        # _new_workflow() muss adversary_override_ambiguous=False initialisieren
        data = workflow._new_workflow("init-test")
        self.assertIn("adversary_override_ambiguous", data,
                      "_new_workflow() muss adversary_override_ambiguous initialisieren")
        self.assertFalse(data["adversary_override_ambiguous"],
                         "adversary_override_ambiguous muss standardmäßig False sein")


# ---------------------------------------------------------------------------
# Override-Commands: cmd_override_loc und cmd_override_ambiguous
# ---------------------------------------------------------------------------

class TestOverrideCommands(EnforcementTestBase):
    """Stellt sicher dass die Override-Commands existieren und korrekt funktionieren."""

    def test_cmd_override_loc_sets_loc_limit_override(self):
        # AC-3 (Command-Test)
        # Given: Aktiver Workflow ohne Override
        self._create_workflow(**self._phase5_prereqs(loc_limit_override=False))

        # When: override-loc Command ausgeführt
        workflow.cmd_override_loc([])

        # Then: loc_limit_override=True im State
        data, _ = workflow._read_active()
        self.assertTrue(data.get("loc_limit_override"),
                        "cmd_override_loc() muss loc_limit_override=True setzen")

    def test_cmd_override_ambiguous_sets_adversary_override(self):
        # AC-9 (Command-Test)
        # Given: Aktiver Workflow ohne Override
        self._create_workflow(**self._phase5_prereqs(adversary_override_ambiguous=False))

        # When: override-ambiguous Command ausgeführt
        workflow.cmd_override_ambiguous([])

        # Then: adversary_override_ambiguous=True im State
        data, _ = workflow._read_active()
        self.assertTrue(data.get("adversary_override_ambiguous"),
                        "cmd_override_ambiguous() muss adversary_override_ambiguous=True setzen")


if __name__ == "__main__":
    unittest.main(verbosity=2)
