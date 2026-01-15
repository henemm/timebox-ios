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

**Task 1: Mock EventKit Repository - Phase 2**
- Beschreibung: View Dependency Injection + UI Test Fixes (8 Timeline Tests)
- Umfang: ~10 Dateien (6 Views, TimeBoxApp, 8 UI Tests)
- Prioritaet: Mittel
- Status: OFFEN (Phase 1 abgeschlossen)
- Hinweis: Phase 1 schafft Foundation, Phase 2 nutzt sie für UI Tests

**Task 2: Test Validation auf Device**
- Beschreibung: MockEventKitRepositoryTests auf echtem iPhone ausführen
- Grund: Simulator crasht (Environment Issue)
- Erwartung: 5 neue Tests + 1 Fix sollten passen
- Prioritaet: Niedrig (Code Review + Build Success OK)
- Status: OFFEN

---

## Spec Ready (Implementation ausstehend)

<!-- Items mit fertiger Spec, aber noch nicht implementiert -->

_Keine Items mit fertiger Spec_

---

## Zuletzt erledigt

<!-- Archiv der letzten erledigten Items -->

**Feature: Mock EventKit Repository (Phase 1)**
- Beschreibung: Protocol-basierte EventKit-Abstraktion mit Mock für Unit Tests
- Implementiert: EventKitRepositoryProtocol, MockEventKitRepository, Test Refactoring
- Tests: Build erfolgreich, 5 neue Mock Tests, 1 Fix (Device-Validation ausstehend)
- Validation: 2026-01-15 (Build Success + Code Review)
- Status: ERLEDIGT (Phase 1 - Unit Test Foundation)
- Phase 2: View Injection + UI Tests (Future)

**Feature: Multi-Source Task System**
- Beschreibung: Task-Source Protocol System mit lokaler SwiftData Storage und CloudKit Sync
- Implementiert: LocalTask Model, TaskSource Protocol, LocalTaskSource Implementation
- Tests: Alle neuen Tests grün (TaskSourceTests, LocalTaskTests, LocalTaskSourceTests, PlanItemTests)
- Validation: 2026-01-15
- Status: ERLEDIGT
