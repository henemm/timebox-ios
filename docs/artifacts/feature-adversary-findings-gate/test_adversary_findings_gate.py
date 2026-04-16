#!/usr/bin/env python3
"""
TDD RED Tests für Adversary-Findings-Gate

Tests für strukturelle Erzwingung:
1. workflow.py: add-finding, resolve-finding, list-findings Commands
2. workflow.py: _validate_transition blockiert phase6_done bei offenen Findings
3. workflow.py: resolve-finding ist geschützt (nur phase_listener)
4. bash_gate.py: Commit blockiert bei offenen Findings
5. phase_listener.py: "fixen"/"akzeptabel" löst nächstes Finding auf

Alle Tests MÜSSEN fehlschlagen bis die Implementation existiert.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[3]
HOOKS_DIR = PROJECT_ROOT / ".claude" / "hooks"
sys.path.insert(0, str(HOOKS_DIR))


class TestWorkflowAddFinding(unittest.TestCase):
    """workflow.py add-finding muss Findings zur Liste hinzufügen."""

    def test_add_finding_command_exists(self):
        """add-finding muss als Command registriert sein."""
        import workflow
        self.assertIn("add-finding", workflow.COMMANDS,
                       "add-finding muss in workflow.COMMANDS registriert sein")

    def test_resolve_finding_command_exists(self):
        """resolve-finding muss als Command registriert sein."""
        import workflow
        self.assertIn("resolve-finding", workflow.COMMANDS,
                       "resolve-finding muss in workflow.COMMANDS registriert sein")

    def test_list_findings_command_exists(self):
        """list-findings muss als Command registriert sein."""
        import workflow
        self.assertIn("list-findings", workflow.COMMANDS,
                       "list-findings muss in workflow.COMMANDS registriert sein")


class TestWorkflowAddFindingBehavior(unittest.TestCase):
    """add-finding muss Findings korrekt in workflow_state speichern."""

    def setUp(self):
        """Temporäres Workflow-Verzeichnis für Tests."""
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        # Minimaler Workflow
        self.wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "adversary_findings": [],
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))

        # Symlink als .active
        active_link = self.wf_dir / ".active"
        os.symlink("test-findings.json", str(active_link))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_add_finding_creates_entry_with_auto_id(self):
        """add-finding soll ein Finding mit auto-increment ID erstellen."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "add-finding",
             "Tags bleiben gespeichert",
             "Keine sichtbare Auswirkung",
             "Unit Test zeigt tag in suggestedTags nach Accept"],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0, f"add-finding fehlgeschlagen: {result.stderr}")

        # Prüfe Workflow-State
        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data.get("adversary_findings", [])
        self.assertEqual(len(findings), 1, "Genau 1 Finding erwartet")
        self.assertEqual(findings[0]["id"], 1, "Erstes Finding sollte ID 1 haben")
        self.assertEqual(findings[0]["title"], "Tags bleiben gespeichert")
        self.assertIsNone(findings[0]["status"], "Status sollte None/null sein")

    def test_add_finding_auto_increments_id(self):
        """Zweites Finding bekommt ID 2."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        # Erstes Finding
        subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "add-finding",
             "Finding 1", "Impact 1", "Proof 1"],
            env=env, capture_output=True, text=True, timeout=5
        )
        # Zweites Finding
        subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "add-finding",
             "Finding 2", "Impact 2", "Proof 2"],
            env=env, capture_output=True, text=True, timeout=5
        )

        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data.get("adversary_findings", [])
        self.assertEqual(len(findings), 2)
        self.assertEqual(findings[0]["id"], 1)
        self.assertEqual(findings[1]["id"], 2)


class TestResolveFindingProtection(unittest.TestCase):
    """resolve-finding darf NUR von phase_listener aufgerufen werden."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        self.wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "adversary_findings": [
                {"id": 1, "title": "Bug 1", "impact": "X", "proof": "Y",
                 "status": None, "resolved_at": None}
            ],
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))
        os.symlink("test-findings.json", str(self.wf_dir / ".active"))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_resolve_finding_blocked_without_caller(self):
        """resolve-finding OHNE WORKFLOW_CALLER=phase_listener → BLOCK."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env.pop("WORKFLOW_CALLER", None)  # Sicherstellen: kein Caller

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "resolve-finding", "1", "accept"],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertNotEqual(result.returncode, 0,
                            "resolve-finding ohne WORKFLOW_CALLER sollte blockiert sein")
        self.assertIn("BLOCKED", result.stderr)

    def test_resolve_finding_allowed_with_phase_listener(self):
        """resolve-finding MIT WORKFLOW_CALLER=phase_listener → ALLOW."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["WORKFLOW_CALLER"] = "phase_listener"

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "resolve-finding", "1", "fix"],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0, f"resolve-finding fehlgeschlagen: {result.stderr}")

        # Prüfe Status
        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        finding = data["adversary_findings"][0]
        self.assertEqual(finding["status"], "fix")
        self.assertIsNotNone(finding["resolved_at"])


class TestValidateTransitionFindingsGate(unittest.TestCase):
    """_validate_transition blockiert phase6_done bei offenen Findings."""

    def _make_workflow_data(self, findings=None, checkpoint3=True):
        """Helper: vollständiger Workflow-State."""
        return {
            "name": "test-wf",
            "current_phase": "phase5_implement",
            "context_file": "docs/context/test.md",
            "spec_file": "docs/specs/test.md",
            "spec_approved": True,
            "checkpoint1_approved": True,
            "checkpoint2_approved": True,
            "checkpoint3_approved": checkpoint3,
            "red_test_done": True,
            "ui_test_red_done": True,
            "test_artifacts": [
                {"phase": "phase4_tdd_red", "type": "unit_test",
                 "path": "test.swift", "description": "test"}
            ],
            "adversary_findings": findings or [],
        }

    def test_blocks_phase6_with_unresolved_findings(self):
        """Offene Findings blockieren phase6_done — AUCH wenn Checkpoint 3 gesetzt."""
        import workflow

        data = self._make_workflow_data(
            findings=[
                {"id": 1, "title": "Bug", "status": None},
                {"id": 2, "title": "Anderer Bug", "status": "fix"},
            ],
            checkpoint3=True,
        )

        error = workflow._validate_transition(data, "phase6_done")
        self.assertIsNotNone(error,
                             "phase6_done sollte blockiert sein mit offenem Finding")
        self.assertIn("Finding", error,
                      "Fehlermeldung sollte 'Finding' erwähnen")

    def test_allows_phase6_when_all_resolved(self):
        """Alle Findings resolved + Checkpoint 3 → phase6_done erlaubt."""
        import workflow

        data = self._make_workflow_data(
            findings=[
                {"id": 1, "title": "Bug", "status": "fix"},
                {"id": 2, "title": "Anderer Bug", "status": "accept"},
            ],
            checkpoint3=True,
        )

        error = workflow._validate_transition(data, "phase6_done")
        self.assertIsNone(error,
                          f"phase6_done sollte erlaubt sein, aber: {error}")

    def test_allows_phase6_with_no_findings(self):
        """Keine Findings (Adversary findet nichts) → phase6_done erlaubt."""
        import workflow

        data = self._make_workflow_data(findings=[], checkpoint3=True)

        error = workflow._validate_transition(data, "phase6_done")
        self.assertIsNone(error,
                          f"phase6_done ohne Findings sollte erlaubt sein, aber: {error}")


class TestBashGateFindingsBlock(unittest.TestCase):
    """bash_gate.py blockiert git commit bei offenen Adversary-Findings."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _write_workflow(self, findings, checkpoint3=True):
        wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "checkpoint3_approved": checkpoint3,
            "adversary_findings": findings,
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(wf_data, indent=2))
        os.symlink("test-findings.json", str(self.wf_dir / ".active"))

    def test_commit_blocked_with_unresolved_findings(self):
        """git commit mit offenen Findings → BLOCK (exit 2)."""
        self._write_workflow(
            findings=[{"id": 1, "title": "Offener Bug", "status": None}],
            checkpoint3=True,
        )

        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["CLAUDE_TOOL_INPUT"] = json.dumps({
            "command": 'git commit -m "feat: some feature (#123)"'
        })

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "bash_gate.py")],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 2,
                         f"Commit mit offenen Findings sollte blockiert sein. stderr: {result.stderr}")

    def test_commit_allowed_with_all_resolved(self):
        """git commit mit allen Findings resolved → ALLOW (exit 0)."""
        self._write_workflow(
            findings=[
                {"id": 1, "title": "Bug", "status": "fix"},
                {"id": 2, "title": "Anderer", "status": "accept"},
            ],
            checkpoint3=True,
        )

        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["CLAUDE_TOOL_INPUT"] = json.dumps({
            "command": 'git commit -m "feat: some feature (#123)"'
        })

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "bash_gate.py")],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0,
                         f"Commit mit allen resolved Findings sollte erlaubt sein. stderr: {result.stderr}")


class TestPhaseListenerFindingResolution(unittest.TestCase):
    """phase_listener erkennt 'fixen'/'akzeptabel' und löst Findings auf."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        self.wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "checkpoint3_approved": False,
            "adversary_findings": [
                {"id": 1, "title": "Bug 1", "impact": "X", "proof": "Y",
                 "status": None, "resolved_at": None},
                {"id": 2, "title": "Bug 2", "impact": "A", "proof": "B",
                 "status": None, "resolved_at": None},
            ],
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))
        os.symlink("test-findings.json", str(self.wf_dir / ".active"))
        # Sessions mapping
        sessions = {"test-session": "test-findings"}
        (self.wf_dir / ".sessions.json").write_text(json.dumps(sessions))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _run_phase_listener(self, message):
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["CLAUDE_SESSION_ID"] = "test-session"
        env["CLAUDE_TOOL_INPUT"] = json.dumps({"prompt": message})

        return subprocess.run(
            ["python3", str(HOOKS_DIR / "phase_listener.py")],
            env=env, capture_output=True, text=True, timeout=5
        )

    def test_fixen_resolves_first_unresolved_finding(self):
        """'fixen' löst das erste unresolved Finding als 'fix' auf."""
        result = self._run_phase_listener("fixen")
        self.assertEqual(result.returncode, 0)

        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data["adversary_findings"]

        self.assertEqual(findings[0]["status"], "fix",
                         "Erstes Finding sollte 'fix' sein")
        self.assertIsNone(findings[1]["status"],
                          "Zweites Finding sollte noch offen sein")

    def test_akzeptabel_resolves_as_accept(self):
        """'akzeptabel' löst als 'accept' auf."""
        result = self._run_phase_listener("akzeptabel")
        self.assertEqual(result.returncode, 0)

        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data["adversary_findings"]

        self.assertEqual(findings[0]["status"], "accept",
                         "Erstes Finding sollte 'accept' sein")

    def test_sequential_resolution(self):
        """Zwei Antworten lösen zwei Findings nacheinander auf."""
        self._run_phase_listener("fixen")
        self._run_phase_listener("akzeptabel")

        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data["adversary_findings"]

        self.assertEqual(findings[0]["status"], "fix")
        self.assertEqual(findings[1]["status"], "accept")


class TestStatusShowsFindings(unittest.TestCase):
    """workflow.py status muss Adversary-Findings anzeigen."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        self.wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "context_file": "docs/context.md",
            "spec_file": "docs/spec.md",
            "spec_approved": True,
            "checkpoint1_approved": True,
            "checkpoint2_approved": True,
            "checkpoint3_approved": False,
            "red_test_done": True,
            "ui_test_red_done": True,
            "test_artifacts": [],
            "adversary_findings": [
                {"id": 1, "title": "Bug 1", "status": None},
                {"id": 2, "title": "Bug 2", "status": "fix"},
                {"id": 3, "title": "Bug 3", "status": None},
            ],
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))
        os.symlink("test-findings.json", str(self.wf_dir / ".active"))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_status_shows_findings_count(self):
        """status muss Findings-Anzahl und offene Findings anzeigen."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "status"],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("Findings", result.stdout,
                       "Status-Output muss 'Findings' enthalten")
        self.assertIn("2 open", result.stdout,
                       "Status muss 2 offene Findings anzeigen")


class TestImportFindings(unittest.TestCase):
    """workflow.py import-findings muss JSON-Array batch-importieren."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        self.wf_data = {
            "name": "test-findings",
            "current_phase": "phase5_implement",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "adversary_findings": [],
        }
        wf_file = self.wf_dir / "test-findings.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))
        os.symlink("test-findings.json", str(self.wf_dir / ".active"))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_import_findings_command_exists(self):
        """import-findings muss als Command registriert sein."""
        import workflow
        self.assertIn("import-findings", workflow.COMMANDS,
                       "import-findings muss in workflow.COMMANDS registriert sein")

    def test_import_findings_creates_entries(self):
        """import-findings mit JSON-Array erstellt alle Findings."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        findings_json = json.dumps([
            {"title": "Bug A", "impact": "User sieht Fehler", "proof": "Screenshot X"},
            {"title": "Bug B", "impact": "Daten gehen verloren", "proof": "Unit Test Y"},
        ])

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "import-findings", findings_json],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0, f"import-findings fehlgeschlagen: {result.stderr}")
        self.assertIn("Imported 2", result.stdout)

        # Prüfe Workflow-State
        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data.get("adversary_findings", [])
        self.assertEqual(len(findings), 2)
        self.assertEqual(findings[0]["id"], 1)
        self.assertEqual(findings[0]["title"], "Bug A")
        self.assertIsNone(findings[0]["status"])
        self.assertEqual(findings[1]["id"], 2)
        self.assertEqual(findings[1]["title"], "Bug B")

    def test_import_findings_skips_invalid_entries(self):
        """Einträge ohne title/impact/proof werden übersprungen."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        findings_json = json.dumps([
            {"title": "Valid", "impact": "Ja", "proof": "Test"},
            {"title": "Missing proof"},
        ])

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "import-findings", findings_json],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("Imported 1", result.stdout)

    def test_import_findings_rejects_invalid_json(self):
        """Ungültiges JSON → Exit 1."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "import-findings", "not json"],
            env=env, capture_output=True, text=True, timeout=5
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid JSON", result.stderr)

    def test_import_findings_continues_id_sequence(self):
        """IDs setzen dort fort wo bestehende Findings aufhören."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir

        # Erst ein Finding manuell hinzufügen
        subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "add-finding",
             "Existing", "Impact", "Proof"],
            env=env, capture_output=True, text=True, timeout=5
        )

        # Dann importieren
        findings_json = json.dumps([
            {"title": "New", "impact": "X", "proof": "Y"},
        ])
        subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "import-findings", findings_json],
            env=env, capture_output=True, text=True, timeout=5
        )

        wf_file = self.wf_dir / "test-findings.json"
        data = json.loads(wf_file.read_text())
        findings = data.get("adversary_findings", [])
        self.assertEqual(findings[0]["id"], 1)
        self.assertEqual(findings[1]["id"], 2, "Importiertes Finding muss ID 2 haben")


class TestAutoTicketForFixFindings(unittest.TestCase):
    """resolve-finding mit status 'fix' soll gh issue create aufrufen."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.wf_dir = Path(self.tmp_dir) / ".claude" / "workflows"
        self.wf_dir.mkdir(parents=True)

        self.wf_data = {
            "name": "test-auto-ticket",
            "current_phase": "phase5_implement",
            "created": datetime.now().isoformat(),
            "last_updated": datetime.now().isoformat(),
            "adversary_findings": [
                {"id": 1, "title": "Schwerer Bug", "impact": "User verliert Daten",
                 "proof": "Unit Test zeigt Datenverlust", "status": None, "resolved_at": None},
            ],
        }
        wf_file = self.wf_dir / "test-auto-ticket.json"
        wf_file.write_text(json.dumps(self.wf_data, indent=2))
        os.symlink("test-auto-ticket.json", str(self.wf_dir / ".active"))

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_fix_status_triggers_gh_issue_create(self):
        """resolve-finding mit 'fix' muss versuchen ein GitHub Issue zu erstellen."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["WORKFLOW_CALLER"] = "phase_listener"

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "resolve-finding", "1", "fix"],
            env=env, capture_output=True, text=True, timeout=10
        )
        self.assertEqual(result.returncode, 0, f"resolve-finding fehlgeschlagen: {result.stderr}")

        # Prüfe dass "Issue" in stdout oder stderr erwähnt wird
        combined = result.stdout + result.stderr
        self.assertTrue(
            "Issue" in combined or "issue" in combined,
            "resolve-finding mit 'fix' sollte GitHub Issue erstellen (oder Warnung ausgeben)"
        )

    def test_accept_status_does_not_create_ticket(self):
        """resolve-finding mit 'accept' soll KEIN Issue erstellen."""
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = self.tmp_dir
        env["WORKFLOW_CALLER"] = "phase_listener"

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "workflow.py"), "resolve-finding", "1", "accept"],
            env=env, capture_output=True, text=True, timeout=10
        )
        self.assertEqual(result.returncode, 0)

        combined = result.stdout + result.stderr
        self.assertNotIn("Issue created", combined,
                         "accept sollte kein Issue erstellen")


if __name__ == "__main__":
    unittest.main()
