#!/usr/bin/env python3
"""
Adversary Dialog System — INFRA_013

Orchestriert einen echten Dialog zwischen QA-Agent und Implementierer.
Parst die Spec, erstellt eine Checkliste aller Expected-Behavior-Punkte,
und validiert das Dialog-Artifact.

Funktionen:
  - parse_spec_expected_behavior(spec_path) → list[str]
  - create_checklist(points) → list[dict]
  - render_dialog_artifact(...) → str
  - validate_dialog_artifact(artifact_path) → tuple[bool, str]

Usage (CLI):
  python3 adversary_dialog.py parse <spec-path>
  python3 adversary_dialog.py validate <artifact-path>
"""

import re
import sys
import time
from datetime import datetime
from pathlib import Path


def parse_spec_expected_behavior(spec_path: str) -> list[str]:
    """Parse a spec file and extract Expected Behavior bullet points.

    Sucht nach einer '## Expected Behavior' Section und extrahiert
    alle Bullet-Points (Zeilen die mit '- ' beginnen) bis zur naechsten
    '## ' Section oder Dateiende.

    Returns:
        Liste von Strings, jeder ein Expected-Behavior-Punkt.
        Leere Liste wenn keine Section gefunden.
    """
    path = Path(spec_path)
    if not path.exists():
        return []

    content = path.read_text(errors="replace")
    lines = content.splitlines()

    in_section = False
    points = []

    for line in lines:
        stripped = line.strip()

        # Section-Start erkennen
        if re.match(r"^##\s+Expected Behavior", stripped, re.IGNORECASE):
            in_section = True
            continue

        # Naechste Section beendet Expected Behavior
        if in_section and re.match(r"^##\s+", stripped):
            break

        # Bullet-Points und nummerierte Listen sammeln
        if in_section and (re.match(r"^-\s+", stripped) or re.match(r"^\d+\.\s+", stripped)):
            # Prefix entfernen (- oder 1.)
            point = re.sub(r"^(-\s+|\d+\.\s+)", "", stripped)
            if point:
                points.append(point)

    return points


def parse_spec_test_plan(spec_path: str) -> list[str]:
    """Parse a spec file and extract Test Plan bullet points.

    Sucht nach einer '## Test Plan' Section und extrahiert
    alle Bullet-Points bis zur naechsten '## ' Section oder Dateiende.

    Returns:
        Liste von Strings, jeder ein Test-Plan-Punkt.
        Leere Liste wenn keine Section gefunden.
    """
    path = Path(spec_path)
    if not path.exists():
        return []

    content = path.read_text(errors="replace")
    lines = content.splitlines()

    in_section = False
    points = []

    for line in lines:
        stripped = line.strip()

        # Section-Start erkennen (## Test Plan oder ### Unit Tests etc.)
        if re.match(r"^##\s+Test Plan", stripped, re.IGNORECASE):
            in_section = True
            continue

        # Naechste gleichrangige Section beendet Test Plan
        if in_section and re.match(r"^##\s+(?!#)", stripped):
            # Check it's not a subsection (### is ok, ## is end)
            if not stripped.startswith("###"):
                break

        # Subsections die keine automatisierten Tests enthalten ueberspringen
        if in_section and re.match(r"^###\s+", stripped):
            subsection = stripped.lstrip("#").strip().lower()
            if "manuell" in subsection or "manual" in subsection:
                # Manuelle Verifikation-Subsection: Items ueberspringen bis naechste ###
                in_section = False  # Wird bei naechstem ### wieder aktiviert
                continue
            else:
                in_section = True  # Automatisierte Subsection: weiter sammeln
                continue

        # Bullet-Points und nummerierte Listen sammeln
        if in_section and (re.match(r"^-\s+", stripped) or re.match(r"^\d+\.\s+", stripped)):
            point = re.sub(r"^(-\s+|\d+\.\s+)", "", stripped)
            if point:
                points.append(point)

    return points


def check_test_coverage(spec_path: str, test_files: list[str]) -> list[str]:
    """Compare spec test plan against actual test methods in files.

    Extrahiert geplante Tests aus der Spec und vergleicht sie mit
    tatsaechlich vorhandenen func test*() Methoden in den Test-Dateien.

    Returns:
        Liste von fehlenden Test-Beschreibungen (Spec-Punkte ohne Match).
    """
    # 1. Geplante Tests aus Spec
    planned = parse_spec_test_plan(spec_path)
    if not planned:
        return []

    # 2. Tatsaechliche Test-Methoden sammeln
    actual_methods = []
    for tf in test_files:
        p = Path(tf)
        if not p.exists():
            continue
        content = p.read_text(errors="replace")
        # Swift: func test...() oder func test_...()
        methods = re.findall(r"func\s+(test\w+)\s*\(", content)
        # Python: def test...()
        methods += re.findall(r"def\s+(test\w+)\s*\(", content)
        actual_methods.extend(methods)

    # 3. Fuzzy-Matching: Fuer jeden geplanten Test pruefen ob ein Match existiert
    missing = []
    for plan_item in planned:
        # Extrahiere Test-Name aus Plan-Item (z.B. "test_create_task — Task erstellen")
        # Nimm alles vor " — " oder " - " als Funktionsname
        name_part = re.split(r"\s*[—\-]\s*", plan_item)[0].strip()
        # Entferne Backticks
        name_part = name_part.strip("`")

        # Suche ob irgendeine tatsaechliche Methode den Kern-Namen enthaelt
        name_lower = name_part.lower().replace("_", "")
        found = False
        for method in actual_methods:
            method_lower = method.lower().replace("_", "")
            if name_lower in method_lower or method_lower in name_lower:
                found = True
                break

        if not found:
            missing.append(plan_item)

    return missing


def create_checklist(points: list[str]) -> list[dict]:
    """Erstellt eine Checkliste aus Expected-Behavior-Punkten.

    Jeder Punkt wird zu einem Item mit:
      - description: Der Punkt-Text
      - status: "open" (noch nicht bewiesen)
      - evidence: None (noch kein Beweis)

    Returns:
        Liste von Dicts.
    """
    return [
        {"description": p, "status": "open", "evidence": None}
        for p in points
    ]


def render_dialog_artifact(
    workflow_name: str,
    spec_path: str,
    checklist: list[dict],
    rounds: list[dict],
    final_verdict: str,
) -> str:
    """Rendert das Dialog-Protokoll als Markdown-Artifact.

    Args:
        workflow_name: Name des Workflows
        spec_path: Pfad zur Spec-Datei
        checklist: Liste von Checklisten-Items (mit status + evidence)
        rounds: Liste von Dialog-Runden (mit round, adversary, implementer, verdict)
        final_verdict: "VERIFIED" oder "BROKEN: <Grund>"

    Returns:
        Markdown-String des Artifacts.
    """
    lines = []
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    # Header
    lines.append(f"# Adversary Dialog \u2014 {workflow_name}")
    lines.append(f"Spec: {spec_path}")
    lines.append(f"Datum: {timestamp}")
    lines.append("")

    # Checkliste
    lines.append("## Checkliste")
    for item in checklist:
        marker = "x" if item["status"] == "verified" else " "
        evidence = f" \u2014 Beweis: {item['evidence']}" if item.get("evidence") else " \u2014 OFFEN"
        lines.append(f"- [{marker}] {item['description']}{evidence}")
    lines.append("")

    # Dialog-Runden
    lines.append("## Dialog")

    # Warnung bei < 2 Runden
    if len(rounds) < 2:
        lines.append("")
        lines.append("> **Warnung:** Nur {0} Runde(n) dokumentiert. Minimum sind 2 Runden.".format(len(rounds)))
        lines.append("")

    for r in rounds:
        lines.append(f"### Runde {r['round']}")
        lines.append(f"**Adversary:** {r['adversary']}")
        lines.append(f"**Implementierer:** {r['implementer']}")
        if r.get("verdict"):
            lines.append(f"**Bewertung:** {r['verdict']}")
        lines.append("")

    # Verdict
    lines.append("## Verdict")
    lines.append(f"**{final_verdict}**")

    open_count = sum(1 for item in checklist if item["status"] != "verified")
    total = len(checklist)
    lines.append(f"Offene Punkte: {open_count} / {total}")

    return "\n".join(lines)


def validate_dialog_artifact(artifact_path: str) -> tuple[bool, str]:
    """Validiert ein Dialog-Artifact fuer qa_gate.py.

    Prueft:
    1. Datei existiert
    2. Datei ist < 60 Min alt
    3. Alle Checklisten-Punkte sind [x] (abgehakt)
    4. Mindestens 2 Dialog-Runden dokumentiert

    Returns:
        (valid: bool, message: str)
    """
    path = Path(artifact_path)

    # 1. Existenz
    if not path.exists():
        return False, f"Dialog artifact not found: {artifact_path}"

    # 2. Alter
    age_min = (time.time() - path.stat().st_mtime) / 60
    if age_min > 60:
        return False, f"Dialog artifact is {age_min:.0f} min old (max 60). Too old, re-run dialog."

    content = path.read_text(errors="replace")

    # 3. Checkliste: Alle Punkte muessen [x] sein
    checked = len(re.findall(r"- \[x\]", content, re.IGNORECASE))
    unchecked = len(re.findall(r"- \[ \]", content))

    if unchecked > 0:
        return False, f"{unchecked} Checklisten-Punkt(e) noch offen. Alle muessen bewiesen sein."

    if checked == 0:
        return False, "Keine Checklisten-Punkte gefunden."

    # 4. Mindestens 2 Runden
    rounds = len(re.findall(r"### Runde \d+", content))
    if rounds < 2:
        return False, f"Nur {rounds} Dialog-Runde(n) dokumentiert. Minimum sind 2 Runden."

    # 5. Verdict muss VERIFIED sein (nicht BROKEN)
    verdict_match = re.search(r"## Verdict\s*\n\*\*(.+?)\*\*", content)
    if not verdict_match:
        return False, "Kein Verdict im Artifact gefunden."
    verdict_text = verdict_match.group(1).strip()
    if not verdict_text.startswith("VERIFIED"):
        return False, f"Verdict ist '{verdict_text}' — nicht VERIFIED."

    return True, f"Dialog valid: {checked} Punkte bewiesen, {rounds} Runden, Verdict VERIFIED."


def main():
    """CLI-Einstiegspunkt."""
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python3 adversary_dialog.py parse <spec-path>")
        print("  python3 adversary_dialog.py validate <artifact-path>")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "parse":
        spec_path = sys.argv[2]
        points = parse_spec_expected_behavior(spec_path)
        if not points:
            print("Keine Expected-Behavior-Punkte gefunden.")
            sys.exit(0)
        print(f"{len(points)} Expected-Behavior-Punkte gefunden:")
        for i, p in enumerate(points, 1):
            print(f"  {i}. {p}")

    elif cmd == "validate":
        artifact_path = sys.argv[2]
        valid, message = validate_dialog_artifact(artifact_path)
        print(message)
        sys.exit(0 if valid else 1)

    elif cmd == "coverage":
        if len(sys.argv) < 4:
            print("Usage: python3 adversary_dialog.py coverage <spec-path> <test-file1> [test-file2...]")
            sys.exit(1)
        spec_path = sys.argv[2]
        test_files = sys.argv[3:]
        planned = parse_spec_test_plan(spec_path)
        if not planned:
            print("Keine Test-Plan-Punkte in der Spec gefunden.")
            sys.exit(0)
        missing = check_test_coverage(spec_path, test_files)
        print(f"Spec-Testplan: {len(planned)} geplante Tests")
        print(f"Abgedeckt: {len(planned) - len(missing)}/{len(planned)}")
        if missing:
            print(f"\nFEHLENDE Tests ({len(missing)}):")
            for m in missing:
                print(f"  MISSING: {m}")
            sys.exit(1)
        else:
            print("Alle geplanten Tests sind implementiert.")
            sys.exit(0)

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
