#!/usr/bin/env python3
"""Adversary Dialog Helper — #309

Modi:
  generate-checklist <spec-pfad>       — Checkliste aus ## Expected Behavior extrahieren
  validate-artifact <artifact> <spec>  — Runden + Verdict prüfen
  --help                               — Hilfetext ausgeben
"""
import sys
import re
from pathlib import Path


def parse_expected_behavior(spec_content: str) -> list[str]:
    """Extrahiert Bullet-Punkte aus ## Expected Behavior."""
    lines = spec_content.splitlines()
    in_section = False
    bullets = []

    for line in lines:
        if re.match(r'^##\s+Expected Behavior', line):
            in_section = True
            continue
        if in_section:
            # Naechster ## Abschnitt beendet den Block
            if re.match(r'^##\s+', line):
                break
            stripped = line.strip()
            if stripped.startswith('- '):
                bullets.append(stripped[2:].strip())

    return bullets


def cmd_generate_checklist(spec_path: str) -> int:
    """Modus A: generate-checklist <spec-pfad>"""
    path = Path(spec_path)
    if not path.exists():
        print(f"Spec nicht gefunden: {spec_path}", file=sys.stderr)
        return 1

    spec_content = path.read_text(encoding="utf-8")
    lines = spec_content.splitlines()

    # Prüfen ob ## Expected Behavior überhaupt vorkommt
    has_section = any(re.match(r'^##\s+Expected Behavior', l) for l in lines)
    if not has_section:
        print("Kein Expected-Behavior-Abschnitt gefunden", file=sys.stderr)
        return 1

    bullets = parse_expected_behavior(spec_content)
    if not bullets:
        print("Keine Bullet-Punkte im Expected-Behavior-Abschnitt", file=sys.stderr)
        return 1

    print("## Adversary-Checkliste")
    for i, bullet in enumerate(bullets, start=1):
        print(f"- [ ] Punkt {i}: {bullet}")

    return 0


def cmd_validate_artifact(artifact_path: str, spec_path: str) -> int:
    """Modus B: validate-artifact <artifact-pfad> <spec-pfad>"""
    artifact = Path(artifact_path)
    if not artifact.exists():
        print(f"Artifact nicht gefunden: {artifact_path}", file=sys.stderr)
        return 1

    artifact_content = artifact.read_text(encoding="utf-8")

    # Runden prüfen
    has_runde1 = "### Runde 1" in artifact_content
    has_runde2 = "### Runde 2" in artifact_content

    if not (has_runde1 and has_runde2):
        print("Weniger als 2 Runden dokumentiert", file=sys.stderr)
        return 1

    # Verdict prüfen
    valid_verdicts = [
        "**VERIFIED**", "**BROKEN**", "**AMBIGUOUS**",
        "**VERDICT: VERIFIED**", "**VERDICT: BROKEN**", "**VERDICT: AMBIGUOUS**",
    ]
    has_verdict = any(v in artifact_content for v in valid_verdicts)

    if not has_verdict:
        print(
            "Kein Verdict gefunden (erwartet: **VERDICT: VERIFIED** / **VERDICT: BROKEN** / **VERDICT: AMBIGUOUS**)",
            file=sys.stderr,
        )
        return 1

    # Alles bestanden
    found_verdict = next(v for v in valid_verdicts if v in artifact_content)
    print("Validierungsbericht:")
    print(f"  Runden: Runde 1 ✓, Runde 2 ✓")
    print(f"  Verdict: {found_verdict} ✓")
    print("Artifact-Validierung bestanden.")

    return 0


def cmd_help() -> int:
    """Modus C: --help"""
    print(
        """\
Adversary Dialog Helper — #309

Modi:
  generate-checklist <spec-pfad>
      Extrahiert Bullet-Punkte aus dem ## Expected Behavior Abschnitt einer Spec
      und gibt eine Markdown-Checkliste aus.

      Beispiel:
        python3 .claude/hooks/adversary_dialog.py generate-checklist docs/specs/feature/foo.md

  validate-artifact <artifact-pfad> <spec-pfad>
      Prüft ein Dialog-Artifact auf Vollständigkeit:
        - Mindestens 2 Runden (### Runde 1, ### Runde 2)
        - Ein Verdict (**VERDICT: VERIFIED** / **VERDICT: BROKEN** / **VERDICT: AMBIGUOUS**
          oder Kurzform **VERIFIED** / **BROKEN** / **AMBIGUOUS**)

      Beispiel:
        python3 .claude/hooks/adversary_dialog.py validate-artifact /tmp/adversary.md docs/specs/feature/foo.md

  --help
      Gibt diesen Hilfetext aus.
"""
    )
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] == "--help":
        sys.exit(cmd_help())
    elif args[0] == "generate-checklist" and len(args) >= 2:
        sys.exit(cmd_generate_checklist(args[1]))
    elif args[0] == "validate-artifact" and len(args) >= 3:
        sys.exit(cmd_validate_artifact(args[1], args[2]))
    else:
        print("Unbekannter Befehl. Nutze --help.", file=sys.stderr)
        sys.exit(1)
