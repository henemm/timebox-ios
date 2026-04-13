# Adversary Dialog — INFRA_014-workflow-hardening
Spec: docs/specs/infra/INFRA_014-workflow-hardening.md
Datum: 2026-04-13 14:30

## Checkliste
- [x] AC-A1: Edit auf UITests in Phase 5 geblockt ohne inspect_ui_done — Beweis: Unit Test green + edit_gate.py Zeile 319-326
- [x] AC-A2: Edit auf UITests in Phase 5 erlaubt mit inspect_ui_done — Beweis: Unit Test green
- [x] AC-A3: Unit-Tests nicht blockiert — Beweis: Unit Test green
- [x] AC-A4: Phase-Transition erfordert inspect_ui_done — Beweis: Unit Test green + workflow.py Zeile 393-396
- [x] AC-B1: parse_spec_test_plan() extrahiert korrekt — Beweis: Unit Test green
- [x] AC-B2: check_test_coverage() erkennt fehlende Tests — Beweis: 2 Unit Tests green
- [x] AC-B3: coverage CLI funktioniert — Beweis: Live-Aufruf 6/6
- [x] AC-B4: 06-validate nutzt coverage-Check — Beweis: Task 2 in 06-validate.md
- [x] AC-C1: 03-write-spec.md hat Cross-Check-Schritt — Beweis: Step 3b vorhanden
- [x] AC-C2: Anleitung zum Nachregistrieren — Beweis: set-affected-files Befehl in Step 3b
- [x] AC-D1: Mindest-Regressions-Scope definiert — Beweis: MINIMUM-Abschnitt in Task 3
- [x] AC-D2: Volle Unit-Suite + 3 UI-Suiten — Beweis: Konkrete Befehle in 06-validate.md

## Dialog

### Runde 1
**Adversary:** Alle 12 ACs einzeln gegen Code und Tests geprueft. Befund: parse_spec_test_plan() sammelt auch Punkte aus "### Manuelle Verifikation" Subsection — erzeugt false positives im coverage-Report.
**Implementierer:** Fix implementiert: Subsections mit "manuell" oder "manual" im Titel werden uebersprungen. Coverage-CLI zeigt jetzt 6/6 statt 7/8.
**Bewertung:** Befund behoben, alle Tests weiterhin green.

### Runde 2
**Adversary:** Nachpruefung: coverage CLI korrekt (6/6), Unit Tests 8/8 green, alle Prompt-Updates in Commands vorhanden. Dead-Code-Check: alle neuen Funktionen haben Aufrufer in COMMANDS-Map, _validate_transition, edit_gate.
**Implementierer:** Alle Punkte bestaetigt.
**Bewertung:** Keine weiteren Befunde.

## Verdict
**VERIFIED**
Offene Punkte: 0 / 12
