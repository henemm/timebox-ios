#!/usr/bin/env python3
"""Tests for adversary_dialog.py — Spec-Parsing, Checkliste, Dialog-Artifact."""

import json
import os
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

# Add hooks dir to path
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestParseSpecExpectedBehavior(unittest.TestCase):
    """Test: Spec-Parser extrahiert Expected-Behavior-Punkte korrekt."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def _write_spec(self, content: str) -> str:
        path = Path(self.tmpdir) / "spec.md"
        path.write_text(textwrap.dedent(content))
        return str(path)

    def test_parse_spec_extracts_expected_behavior(self):
        """Spec mit Expected-Behavior-Section → Liste mit Punkten."""
        from adversary_dialog import parse_spec_expected_behavior

        spec_path = self._write_spec("""
            # Feature X

            ## Expected Behavior

            - **Input:** User tippt auf Button
            - **Output:** Modal oeffnet sich
            - **Side effects:** Haptic Feedback

            ## Known Limitations
            - None
        """)

        points = parse_spec_expected_behavior(spec_path)
        self.assertGreaterEqual(len(points), 1)
        # Jeder Punkt ist ein nicht-leerer String
        for p in points:
            self.assertIsInstance(p, str)
            self.assertTrue(len(p.strip()) > 0)

    def test_parse_spec_empty_section(self):
        """Spec ohne Expected-Behavior-Section → leere Liste."""
        from adversary_dialog import parse_spec_expected_behavior

        spec_path = self._write_spec("""
            # Feature X

            ## Purpose
            Does something.

            ## Known Limitations
            - None
        """)

        points = parse_spec_expected_behavior(spec_path)
        self.assertEqual(len(points), 0)

    def test_parse_spec_multiformat_bullets(self):
        """Expected-Behavior mit verschiedenen Bullet-Formaten."""
        from adversary_dialog import parse_spec_expected_behavior

        spec_path = self._write_spec("""
            # Feature X

            ## Expected Behavior

            - Punkt eins
            - **Punkt zwei:** mit Details
            - Punkt drei mit `code`

            ## Next Section
        """)

        points = parse_spec_expected_behavior(spec_path)
        self.assertEqual(len(points), 3)


class TestChecklistCreation(unittest.TestCase):
    """Test: Jeder Bullet wird zu einem offenen Checklisten-Item."""

    def test_checklist_creation(self):
        """Punkte werden zu Items mit status=open."""
        from adversary_dialog import create_checklist

        points = ["User sieht Modal", "Haptic Feedback", "Daten gespeichert"]
        checklist = create_checklist(points)

        self.assertEqual(len(checklist), 3)
        for item in checklist:
            self.assertEqual(item["status"], "open")
            self.assertIn("description", item)
            self.assertIsNone(item.get("evidence"))

    def test_checklist_empty_input(self):
        """Leere Punkte-Liste → leere Checkliste."""
        from adversary_dialog import create_checklist

        checklist = create_checklist([])
        self.assertEqual(len(checklist), 0)


class TestDialogArtifactFormat(unittest.TestCase):
    """Test: Dialog-Artifact ist valides Markdown mit Header, Checkliste, Runden, Verdict."""

    def test_dialog_artifact_format(self):
        """Vollstaendiges Artifact enthaelt alle Pflichtfelder."""
        from adversary_dialog import render_dialog_artifact

        checklist = [
            {"description": "Modal oeffnet sich", "status": "verified", "evidence": "Screenshot r1.png"},
            {"description": "Haptic Feedback", "status": "verified", "evidence": "Test-Output"},
        ]
        rounds = [
            {
                "round": 1,
                "adversary": "Zeig mir das Modal mit echten Daten.",
                "implementer": "Screenshot: /tmp/r1.png",
                "verdict": "Akzeptiert.",
            },
            {
                "round": 2,
                "adversary": "Was passiert bei leerem Zustand?",
                "implementer": "Screenshot: /tmp/r2.png",
                "verdict": "Akzeptiert.",
            },
        ]

        artifact = render_dialog_artifact(
            workflow_name="feature-123",
            spec_path="docs/specs/feature-123.md",
            checklist=checklist,
            rounds=rounds,
            final_verdict="VERIFIED",
        )

        # Pflichtfelder im Artifact
        self.assertIn("# Adversary Dialog", artifact)
        self.assertIn("feature-123", artifact)
        self.assertIn("## Checkliste", artifact)
        self.assertIn("[x]", artifact)
        self.assertIn("## Dialog", artifact)
        self.assertIn("### Runde 1", artifact)
        self.assertIn("### Runde 2", artifact)
        self.assertIn("## Verdict", artifact)
        self.assertIn("VERIFIED", artifact)

    def test_dialog_minimum_rounds_warning(self):
        """Dialog mit nur 1 Runde → Warnung im Artifact."""
        from adversary_dialog import render_dialog_artifact

        checklist = [{"description": "Punkt 1", "status": "verified", "evidence": "ok"}]
        rounds = [{"round": 1, "adversary": "Frage", "implementer": "Antwort", "verdict": "Ok"}]

        artifact = render_dialog_artifact(
            workflow_name="test",
            spec_path="spec.md",
            checklist=checklist,
            rounds=rounds,
            final_verdict="VERIFIED",
        )

        # Warnung bei < 2 Runden
        self.assertIn("warnung", artifact.lower())


class TestQaGateChecklistValidation(unittest.TestCase):
    """Test: qa_gate.py --checklist Erweiterung."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def _write_artifact(self, content: str, age_minutes: int = 0) -> str:
        path = Path(self.tmpdir) / "adversary-dialog.md"
        path.write_text(content)
        if age_minutes > 0:
            import time
            old_time = time.time() - (age_minutes * 60)
            os.utime(str(path), (old_time, old_time))
        return str(path)

    def test_checklist_all_checked_passes(self):
        """Alle [x] → valid."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact(textwrap.dedent("""
            # Adversary Dialog — test
            ## Checkliste
            - [x] Punkt 1 — Beweis: Screenshot
            - [x] Punkt 2 — Beweis: Test-Output

            ## Dialog
            ### Runde 1
            **Adversary:** Frage 1
            **Implementierer:** Antwort 1
            ### Runde 2
            **Adversary:** Frage 2
            **Implementierer:** Antwort 2

            ## Verdict
            **VERIFIED**
        """))

        valid, message = validate_dialog_artifact(path)
        self.assertTrue(valid)

    def test_checklist_open_points_fails(self):
        """Mind. 1 offener Punkt → invalid."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact(textwrap.dedent("""
            # Adversary Dialog — test
            ## Checkliste
            - [x] Punkt 1 — Beweis: Screenshot
            - [ ] Punkt 2 — OFFEN

            ## Dialog
            ### Runde 1
            **Adversary:** Frage
            **Implementierer:** Antwort
            ### Runde 2
            **Adversary:** Frage
            **Implementierer:** Antwort

            ## Verdict
            **BROKEN**
        """))

        valid, message = validate_dialog_artifact(path)
        self.assertFalse(valid)
        self.assertIn("offen", message.lower())

    def test_checklist_too_few_rounds_fails(self):
        """< 2 Runden → invalid."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact(textwrap.dedent("""
            # Adversary Dialog — test
            ## Checkliste
            - [x] Punkt 1 — Beweis: ok

            ## Dialog
            ### Runde 1
            **Adversary:** Frage
            **Implementierer:** Antwort

            ## Verdict
            **VERIFIED**
        """))

        valid, message = validate_dialog_artifact(path)
        self.assertFalse(valid)
        self.assertIn("runde", message.lower())

    def test_checklist_file_missing_fails(self):
        """Artifact existiert nicht → invalid."""
        from adversary_dialog import validate_dialog_artifact

        valid, message = validate_dialog_artifact("/nonexistent/path.md")
        self.assertFalse(valid)
        self.assertIn("not found", message.lower())

    def test_checklist_file_too_old_fails(self):
        """Artifact > 60 Min alt → invalid."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact(textwrap.dedent("""
            # Adversary Dialog — test
            ## Checkliste
            - [x] Punkt 1 — ok

            ## Dialog
            ### Runde 1
            **Adversary:** F
            **Implementierer:** A
            ### Runde 2
            **Adversary:** F
            **Implementierer:** A

            ## Verdict
            **VERIFIED**
        """), age_minutes=65)

        valid, message = validate_dialog_artifact(path)
        self.assertFalse(valid)
        self.assertIn("old", message.lower())


class TestBugfixes(unittest.TestCase):
    """Tests fuer Adversary-gefundene Bugs."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def _write_artifact(self, content: str) -> str:
        path = Path(self.tmpdir) / "adversary-dialog.md"
        path.write_text(textwrap.dedent(content))
        return str(path)

    def test_broken_verdict_fails_validation(self):
        """BUG-001: BROKEN-Artifact mit allen [x] darf NICHT als valid gelten."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact("""
            # Adversary Dialog — test
            ## Checkliste
            - [x] Punkt 1 — Beweis: ok
            - [x] Punkt 2 — Beweis: ok

            ## Dialog
            ### Runde 1
            **Adversary:** Frage
            **Implementierer:** Antwort
            ### Runde 2
            **Adversary:** Frage
            **Implementierer:** Antwort

            ## Verdict
            **BROKEN: Feature funktioniert bei Edge Case nicht**
        """)

        valid, message = validate_dialog_artifact(path)
        self.assertFalse(valid)
        self.assertIn("BROKEN", message)

    def test_numbered_list_parsing(self):
        """BUG-003: Nummerierte Listen muessen auch geparst werden."""
        from adversary_dialog import parse_spec_expected_behavior

        spec_path = Path(self.tmpdir) / "spec.md"
        spec_path.write_text(textwrap.dedent("""
            # Feature

            ## Expected Behavior

            1. Implementierer ruft adversary_dialog.py auf
            2. Script parst Spec
            3. Dialog laeuft min. 2 Runden

            ## Next
        """))

        points = parse_spec_expected_behavior(str(spec_path))
        self.assertEqual(len(points), 3)
        self.assertIn("Implementierer ruft adversary_dialog.py auf", points[0])

    def test_uppercase_x_recognized(self):
        """BUG-007: [X] uppercase muss als gecheckt erkannt werden."""
        from adversary_dialog import validate_dialog_artifact

        path = self._write_artifact("""
            # Adversary Dialog — test
            ## Checkliste
            - [X] Punkt 1 — Beweis: ok
            - [x] Punkt 2 — Beweis: ok

            ## Dialog
            ### Runde 1
            **Adversary:** Frage
            **Implementierer:** Antwort
            ### Runde 2
            **Adversary:** Frage
            **Implementierer:** Antwort

            ## Verdict
            **VERIFIED**
        """)

        valid, message = validate_dialog_artifact(path)
        self.assertTrue(valid)

    def test_mixed_bullets_and_numbered(self):
        """Gemischte Formate: Bullets + nummerierte Listen."""
        from adversary_dialog import parse_spec_expected_behavior

        spec_path = Path(self.tmpdir) / "spec.md"
        spec_path.write_text(textwrap.dedent("""
            # Feature

            ## Expected Behavior

            - Bullet eins
            1. Nummeriert zwei
            - Bullet drei
            2. Nummeriert vier

            ## Next
        """))

        points = parse_spec_expected_behavior(str(spec_path))
        self.assertEqual(len(points), 4)


if __name__ == "__main__":
    unittest.main()
