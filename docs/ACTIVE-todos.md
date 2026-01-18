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

_Keine ausstehenden Specs_

---

## Zuletzt erledigt

<!-- Archiv der letzten erledigten Items -->

**Feature: Eisenhower Matrix als ViewMode in BacklogView**
- Beschreibung: Eisenhower Matrix von separatem Tab zu ViewMode in BacklogView umgebaut
- Type: AENDERUNG (Modification)
- Implementiert:
  - ViewMode enum mit 5 Modi (List, Matrix, Category, Duration, Due Date)
  - Swift Liquid Glass Switcher im Toolbar (Menu Button)
  - AppStorage Persistence mit Key "backlogViewMode"
  - Matrix Tab aus MainTabView entfernt
  - 5 View-Renderer in BacklogView integriert
- Files Changed: MainTabView.swift (-4 lines), BacklogView.swift (+150 net), BacklogViewUITests.swift (+64)
- Tests: 4 TDD UI Tests (alle grün)
  - testViewModeSwitcherExists ✅
  - testViewModeSwitcherShowsAllOptions ✅
  - testSwitchToEisenhowerMatrixMode ✅
  - testMatrixTabDoesNotExist ✅
- TDD-Status: ✅ Vollständig TDD (RED → GREEN)
- Spec: `TimeBox/docs/artifacts/eisenhower-view-mode/spec.md`
- Validation: 2026-01-18
- Status: ERLEDIGT ✅

**Feature: Task System v2.0 - Phase 2: Backlog Enhancements**
- Beschreibung: Visual Indicators + Eisenhower Matrix für besseres Task-Prioritization
- Implementiert:
  - BacklogRow mit Priority Icons, Tag Chips, Due Date Badges (f049830)
  - EisenhowerMatrixView mit 4 Quadranten (Do First, Schedule, Delegate, Eliminate) (ed56d42)
  - Retroaktive Tests: 10 Unit Tests + 12 UI Tests (4af9209)
  - TDD-Enforcement: strict_code_gate.py Hook aktiviert (3843335)
- Files Changed: BacklogView.swift, BacklogRow.swift, PlanItem.swift, MainTabView.swift
- Tests: 22 Tests geschrieben (EisenhowerMatrixTests.swift, EisenhowerMatrixUITests.swift)
- TDD-Status: ⚠️ Implementiert OHNE TDD (vor Hook-Aktivierung), Tests retroaktiv geschrieben
- Hook-System: strict_code_gate.py verhindert zukünftige TDD-Bypasses
- Validation: 2026-01-17
- Status: ERLEDIGT ✅ (Tests geschrieben, Hook aktiv, Feature funktioniert)
- Note: Filter/Sort UI blocked by Swift 6 Toolbar Bug (deferred)

**Feature: Mock EventKit Repository (Phase 2)**
- Beschreibung: SwiftUI Environment Injection für Mock in UI Tests + CloudKit Fix für Simulator
- Implementiert: EventKitRepositoryEnvironment, TimeBoxApp Mock Injection + CloudKit Disable, View @Environment Updates
- Changes: 13 files (EventKitRepositoryEnvironment.swift, TimeBoxApp, 2 Views, 2 UI Test files, Mock moved to main target)
- Tests: 7 Timeline UI Tests bestehen (PlanningViewUITests 3/3, SchedulingUITests 4/4), App startet erfolgreich, keine Crashes
- Root Cause Fix: CloudKit Initialisierung crashte im Simulator → isStoredInMemoryOnly + cloudKitDatabase: .none für Tests
- Validation: 2026-01-16
- Status: KOMPLETT ERLEDIGT ✅ (alle Acceptance Criteria erfüllt)

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
