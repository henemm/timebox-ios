# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!

---

## Status-Legende

| Status | Bedeutung |
|--------|-----------|
| **OFFEN** | Noch nicht begonnen |
| **SPEC READY** | Spec geschrieben & approved, Implementation ausstehend |
| **IN ARBEIT** | Aktive Bearbeitung |
| **ERLEDIGT** | Fertig (nur nach Phase 8 / vollstaendiger Validierung) |
| **BLOCKIERT** | Kann nicht fortgesetzt werden |

**WICHTIG:** "SPEC READY" ≠ "ERLEDIGT"! Eine fertige Spec bedeutet NICHT, dass das Feature fertig ist.

---

## Offene Bugs

<!-- Beispiel-Format:
**Bug 1: [Kurze Beschreibung]**
- Location: [Datei(en)]
- Problem: [Was passiert falsch]
- Expected: [Was sollte passieren]
- Root Cause: [Warum passiert es - Code-Stelle]
- Test: [Wie Fix verifizieren]
- Status: OFFEN / SPEC READY / IN ARBEIT / ERLEDIGT / BLOCKIERT
-->

_Keine offenen Bugs_

---

## Offene Tasks

<!-- Beispiel-Format:
**Task 1: [Kurze Beschreibung]**
- Beschreibung: [Was soll gemacht werden]
- Prioritaet: Hoch / Mittel / Niedrig
- Status: OFFEN / SPEC READY / IN ARBEIT / ERLEDIGT / BLOCKIERT
-->

_Keine offenen Tasks_

---

## Spec Ready (Implementation ausstehend)

<!-- Items mit fertiger Spec, aber noch nicht implementiert -->

_Keine Items mit fertiger Spec_

---

## Zuletzt erledigt

<!-- Archiv der letzten erledigten Items -->

**Feature: Multi-Source Task System**
- Beschreibung: Task-Source Protocol System mit lokaler SwiftData Storage und CloudKit Sync
- Implementiert: LocalTask Model, TaskSource Protocol, LocalTaskSource Implementation
- Tests: Alle neuen Tests grün (TaskSourceTests, LocalTaskTests, LocalTaskSourceTests, PlanItemTests)
- Validation: 2026-01-15
- Status: ERLEDIGT
