#!/usr/bin/env python3
"""
Tests für Feature #309: Adversary-Dialog strukturieren

Getestetes Skript: .claude/hooks/adversary_dialog.py (existiert noch nicht — TDD RED)

Alle Tests MÜSSEN fehlschlagen, weil das Skript noch nicht implementiert ist.

Modi:
  A) generate-checklist <spec-pfad>     — Checkliste aus Expected-Behavior-Abschnitt
  B) validate-artifact <artifact> <spec> — Runden + Verdict prüfen
  C) --help                              — Hilfetext ausgeben
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS_DIR = Path(__file__).parent.parent.parent / ".claude" / "hooks"
SCRIPT = str(HOOKS_DIR / "adversary_dialog.py")

# Spec-Inhalte für Tests

SPEC_WITH_EXPECTED_BEHAVIOR = """\
---
entity_id: test-feature
---

# Test Feature

## Purpose
Etwas tun.

## Expected Behavior
- Benutzer kann eine Aufgabe erstellen
- Aufgabe erscheint in der Liste

## Acceptance Criteria
**AC-1** — Feature tut X.
"""

SPEC_WITHOUT_EXPECTED_BEHAVIOR = """\
---
entity_id: test-feature
---

# Test Feature

## Purpose
Etwas tun ohne Expected Behavior Abschnitt.

## Acceptance Criteria
**AC-1** — Feature tut X.
"""

ARTIFACT_VALID = """\
### Runde 1
Adversary: Zeig mir die Aufgabenerstellung.
Implementierer: Screenshot beigefügt.

### Runde 2
Adversary: Bestätigt.

**VERIFIED**
"""

ARTIFACT_NO_VERDICT = """\
### Runde 1
Etwas text.

### Runde 2
Mehr text.
"""

ARTIFACT_ONLY_ONE_ROUND = """\
### Runde 1
Adversary: Erste Runde.
Implementierer: Antwort.
"""


def _run(args: list[str], input_text: str | None = None) -> tuple[int, str, str]:
    """Führt adversary_dialog.py als Subprocess aus. Gibt (exit_code, stdout, stderr) zurück."""
    result = subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True,
        text=True,
        input=input_text,
    )
    return result.returncode, result.stdout, result.stderr


class TestGenerateChecklist(unittest.TestCase):
    """Modus A: generate-checklist <spec-pfad>"""

    def _write_spec(self, content: str) -> str:
        """Schreibt temporäre Spec-Datei, gibt Pfad zurück."""
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix=".md", delete=False, encoding="utf-8"
        )
        f.write(content)
        f.close()
        self.addCleanup(os.unlink, f.name)
        return f.name

    def test_ac1_generate_checklist_returns_checklist(self):
        # AC-1: Spec mit Expected Behavior → Checkliste auf stdout, Exit 0
        spec_path = self._write_spec(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(["generate-checklist", spec_path])

        # Skript muss Exit 0 liefern
        self.assertEqual(exit_code, 0,
                         f"Exit-Code muss 0 sein. stderr: {stderr}")
        # Stdout muss Markdown-Checkliste enthalten
        self.assertIn("## Adversary-Checkliste", stdout,
                      "stdout muss '## Adversary-Checkliste' enthalten")
        # Jeder Bullet-Punkt muss als Checkbox erscheinen
        self.assertIn("- [ ] Punkt 1:", stdout,
                      "stdout muss '- [ ] Punkt 1:' enthalten")
        self.assertIn("- [ ] Punkt 2:", stdout,
                      "stdout muss '- [ ] Punkt 2:' enthalten")
        # Kein Fehler auf stderr
        self.assertEqual(stderr.strip(), "",
                         f"Bei Erfolg darf stderr leer sein. Hatte: {stderr}")

    def test_ac1_checklist_contains_bullet_text(self):
        # AC-1: Der Text der Bullet-Punkte muss in der Checkliste erscheinen
        spec_path = self._write_spec(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, _ = _run(["generate-checklist", spec_path])

        self.assertEqual(exit_code, 0)
        self.assertIn("Aufgabe erstellen", stdout,
                      "Bullet-Text 'Aufgabe erstellen' muss in Checkliste erscheinen")
        self.assertIn("erscheint in der Liste", stdout,
                      "Bullet-Text 'erscheint in der Liste' muss in Checkliste erscheinen")

    def test_ac2_generate_checklist_fails_when_no_expected_behavior(self):
        # AC-2: Spec ohne ## Expected Behavior → Exit 1 + Fehler auf stderr
        spec_path = self._write_spec(SPEC_WITHOUT_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(["generate-checklist", spec_path])

        self.assertEqual(exit_code, 1,
                         f"Exit-Code muss 1 sein wenn kein Expected-Behavior-Abschnitt. stdout: {stdout}")
        self.assertNotEqual(stderr.strip(), "",
                            "stderr muss eine Fehlermeldung enthalten")
        # Keine leere Checkliste — stdout darf KEINE Checkliste enthalten
        self.assertNotIn("## Adversary-Checkliste", stdout,
                         "Bei fehlendem Abschnitt darf KEINE Checkliste ausgegeben werden")

    def test_ac2_error_message_mentions_expected_behavior(self):
        # AC-2: Fehlermeldung muss den fehlenden Abschnitt benennen
        spec_path = self._write_spec(SPEC_WITHOUT_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(["generate-checklist", spec_path])

        self.assertEqual(exit_code, 1)
        self.assertIn("Expected", stderr,
                      "Fehlermeldung muss 'Expected' (Behavior) erwähnen")

    def test_ac_file_not_found_exits_with_error(self):
        # Zusatz: Datei existiert nicht → Exit 1 + erklärender Fehlertext auf stderr
        nonexistent = "/tmp/does_not_exist_309_test.md"

        exit_code, stdout, stderr = _run(["generate-checklist", nonexistent])

        self.assertEqual(exit_code, 1,
                         f"Exit-Code muss 1 sein bei fehlender Datei. stdout: {stdout}")
        self.assertNotEqual(stderr.strip(), "",
                            "stderr muss einen Fehlertext enthalten")
        # Stdout darf keine Checkliste ausgeben
        self.assertNotIn("## Adversary-Checkliste", stdout,
                         "Bei fehlender Datei darf KEINE Checkliste ausgegeben werden")


class TestValidateArtifact(unittest.TestCase):
    """Modus B: validate-artifact <artifact-pfad> <spec-pfad>"""

    def _write_file(self, content: str, suffix: str = ".md") -> str:
        """Schreibt temporäre Datei, gibt Pfad zurück."""
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix=suffix, delete=False, encoding="utf-8"
        )
        f.write(content)
        f.close()
        self.addCleanup(os.unlink, f.name)
        return f.name

    def test_ac3_valid_artifact_exits_zero(self):
        # AC-3: Artifact mit Runde 1 + Runde 2 + VERIFIED → Exit 0
        artifact_path = self._write_file(ARTIFACT_VALID)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"Exit-Code muss 0 sein bei validem Artifact. stderr: {stderr}")
        # stdout muss Validierungsbericht enthalten
        self.assertNotEqual(stdout.strip(), "",
                            "stdout muss einen Validierungsbericht enthalten")

    def test_ac3_valid_artifact_with_broken_verdict_exits_zero(self):
        # AC-3: BROKEN ist ebenfalls ein gültiges Verdict
        artifact_broken = ARTIFACT_VALID.replace("**VERIFIED**", "**BROKEN**")
        artifact_path = self._write_file(artifact_broken)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"**BROKEN** ist gültiges Verdict, Exit-Code muss 0 sein. stderr: {stderr}")

    def test_ac3_valid_artifact_with_ambiguous_verdict_exits_zero(self):
        # AC-3: AMBIGUOUS ist ebenfalls ein gültiges Verdict
        artifact_ambiguous = ARTIFACT_VALID.replace("**VERIFIED**", "**AMBIGUOUS**")
        artifact_path = self._write_file(artifact_ambiguous)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"**AMBIGUOUS** ist gültiges Verdict, Exit-Code muss 0 sein. stderr: {stderr}")

    def test_ac4_artifact_without_verdict_exits_one(self):
        # AC-4: Artifact ohne Verdict-Keyword → Exit 1
        artifact_path = self._write_file(ARTIFACT_NO_VERDICT)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 1,
                         f"Exit-Code muss 1 sein wenn kein Verdict. stdout: {stdout}")

    def test_ac4_error_message_mentions_kein_verdict(self):
        # AC-4: Fehlermeldung muss "Kein Verdict gefunden" enthalten
        artifact_path = self._write_file(ARTIFACT_NO_VERDICT)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 1)
        self.assertIn("Kein Verdict", stderr,
                      "Fehlermeldung muss 'Kein Verdict' enthalten")

    def test_ac5_artifact_with_only_one_round_exits_one(self):
        # AC-5: Artifact mit nur Runde 1 (kein ### Runde 2) → Exit 1
        artifact_path = self._write_file(ARTIFACT_ONLY_ONE_ROUND)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 1,
                         f"Exit-Code muss 1 sein wenn weniger als 2 Runden. stdout: {stdout}")

    def test_ac5_error_message_mentions_weniger_als_2_runden(self):
        # AC-5: Fehlermeldung muss "Weniger als 2 Runden" enthalten
        artifact_path = self._write_file(ARTIFACT_ONLY_ONE_ROUND)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 1)
        self.assertIn("Weniger als 2 Runden", stderr,
                      "Fehlermeldung muss 'Weniger als 2 Runden' enthalten")


class TestValidateArtifactVerdictPrefix(unittest.TestCase):
    """Modus B: validate-artifact — VERDICT:-Präfix-Format (adversary.md Pflichtformat)"""

    def _write_file(self, content: str, suffix: str = ".md") -> str:
        """Schreibt temporäre Datei, gibt Pfad zurück."""
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix=suffix, delete=False, encoding="utf-8"
        )
        f.write(content)
        f.close()
        self.addCleanup(os.unlink, f.name)
        return f.name

    def test_ac3_valid_artifact_with_verdict_prefix_verified(self):
        """AC-3: VERDICT: VERIFIED Präfix-Format wird erkannt"""
        artifact = ARTIFACT_VALID.replace("**VERIFIED**", "**VERDICT: VERIFIED**")
        artifact_path = self._write_file(artifact)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, stdout, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"**VERDICT: VERIFIED** muss als gültiges Verdict erkannt werden. stderr: {stderr}")
        self.assertNotEqual(stdout.strip(), "",
                            "stdout muss einen Validierungsbericht enthalten")

    def test_ac3_valid_artifact_with_verdict_prefix_broken(self):
        """AC-3: VERDICT: BROKEN Präfix-Format wird erkannt"""
        artifact = ARTIFACT_VALID.replace("**VERIFIED**", "**VERDICT: BROKEN**")
        artifact_path = self._write_file(artifact)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"**VERDICT: BROKEN** muss als gültiges Verdict erkannt werden. stderr: {stderr}")

    def test_ac3_valid_artifact_with_verdict_prefix_ambiguous(self):
        """AC-3: VERDICT: AMBIGUOUS Präfix-Format wird erkannt"""
        artifact = ARTIFACT_VALID.replace("**VERIFIED**", "**VERDICT: AMBIGUOUS**")
        artifact_path = self._write_file(artifact)
        spec_path = self._write_file(SPEC_WITH_EXPECTED_BEHAVIOR)

        exit_code, _, stderr = _run(
            ["validate-artifact", artifact_path, spec_path]
        )

        self.assertEqual(exit_code, 0,
                         f"**VERDICT: AMBIGUOUS** muss als gültiges Verdict erkannt werden. stderr: {stderr}")


class TestHelpMode(unittest.TestCase):
    """Modus C: --help"""

    def test_help_exits_zero(self):
        # Modus C: --help gibt Hilfetext aus und beendet mit Exit 0
        exit_code, stdout, stderr = _run(["--help"])

        self.assertEqual(exit_code, 0,
                         f"--help muss mit Exit 0 beenden. stderr: {stderr}")

    def test_help_output_mentions_generate_checklist(self):
        # --help muss generate-checklist als Modus nennen
        exit_code, stdout, _ = _run(["--help"])

        self.assertEqual(exit_code, 0)
        self.assertIn("generate-checklist", stdout,
                      "--help muss 'generate-checklist' erwähnen")

    def test_help_output_mentions_validate_artifact(self):
        # --help muss validate-artifact als Modus nennen
        exit_code, stdout, _ = _run(["--help"])

        self.assertEqual(exit_code, 0)
        self.assertIn("validate-artifact", stdout,
                      "--help muss 'validate-artifact' erwähnen")


if __name__ == "__main__":
    unittest.main(verbosity=2)
