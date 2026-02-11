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

---

## 🔴 OFFEN

### Bug 22: Edit-Button in Backlog Toolbar ohne Funktion
**Status:** OFFEN
**Gemeldet:** 2026-02-02
**Platform:** iOS
**Location:** `Sources/Views/BacklogView.swift:218`
**Prioritaet:** MITTEL

**Problem:**
- `EditButton()` in Toolbar sichtbar, hat aber keine Funktion
- Tap zeigt "Fertig" an, aber keine Drag-Handles, kein Reorder moeglich

**Root Cause:**
- `EditButton()` existiert, aber `List` hat keinen `.onMove` Handler
- Ohne `.onMove` kann SwiftUI keine Drag-Reorder-Funktion aktivieren

**Fix erfordert:**
1. `.onMove(perform:)` Handler zu List hinzufuegen
2. `reorderTasks(_:)` Funktion implementieren
3. `TaskMetadata.sortOrder` bei Move aktualisieren

---

## ✅ Kuerzlich erledigt

### Bug 34: Duplikate nach CloudKit-Aktivierung
**Status:** ✅ ERLEDIGT (2026-02-11)
**Fix 1:** Reminders-Import auf iOS ueberspringen wenn CloudKit aktiv (`BacklogView.swift`)
**Fix 2 (v2):** externalID-basierte Dedup-Bereinigung beim App-Start (`FocusBloxApp.swift`)
**Commit:** `cd936e6`

### Feature: Kalender-Events in Review-Statistiken (macOS + iOS)
**Status:** ✅ ERLEDIGT (2026-02-11)
**Commit:** `e6abc5d`

### Bug 33: Cross-Platform Sync (CloudKit + App Group auf iOS)
**Status:** ✅ ERLEDIGT (2026-02-11)

### Bug 32: Importance/Urgency Race Condition
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 31: Focus Block Startzeit/Endzeit Synchronisation
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 30: Kategorie-Bezeichnungen inkonsistent
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 29: Duration-Werte korrigiert
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 26: macOS Zuweisen Drag&Drop
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 25: macOS Planen echte Kalender-Daten
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 21: Tags-Eingabe ohne Autocomplete
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 18: Reminders-Tasks Dringlichkeit/Wichtigkeit nicht speicherbar
**Status:** ✅ ERLEDIGT (2026-02-10)

### Bug 17: BacklogRow Badges als Chips
**Status:** ✅ ERLEDIGT - Alle Badges als Chips mit `.ultraThinMaterial` implementiert

---

## ✅ Aeltere erledigte Bugs (Archiv)

| Bug | Beschreibung | Status |
|-----|--------------|--------|
| Bug 24 | iOS App keine Tasks (Info.plist) | ✅ ERLEDIGT (2026-02-02) |
| Bug 23 | macOS Kalender-Zugriff (Info.plist) | ✅ ERLEDIGT (2026-02-02) |
| Bug 20 | QuickCapture Tastatur verdeckt | ✅ ERLEDIGT (2026-02-02) |
| Bug 19 | Wiederkehrende Aufgaben | ✅ ERLEDIGT (bereits implementiert) |
| Bug 16 | Focus Tab keine weiteren Tasks | ✅ ERLEDIGT (bereits im Code) |
| Bug 15 | Ueberspringen Endlosschleife | ✅ ERLEDIGT (2026-01-30) |
| Bug 14 | Assign Tab Next Up nicht sichtbar | ✅ ERLEDIGT (bereits im Code) |
| Bug 13 | Blox Tab keine Block-Details | ✅ ERLEDIGT (2026-01-29) |
| Bug 12 | Kategorie-System inkonsistent | ✅ ERLEDIGT (2026-01-26) |
| Bug 11 | Pull-to-Refresh nur Backlog | ✅ ERLEDIGT (2026-01-26) |
| Bug 9 | Vergangene Zeitslots | ✅ ERLEDIGT (2026-01-24) |
| Bug 8 | Kalender-Berechtigung | ✅ ERLEDIGT (2026-01-24) |
| Bug 7 | Focus Block Scrolling | ✅ ERLEDIGT |

### Themengruppen (alle abgeschlossen)

| Gruppe | Thema | Status |
|--------|-------|--------|
| A | Next Up Layout (Horizontal → Vertikal) | ✅ Alle 3 Stellen |
| B | Next Up State Management | ✅ Alle Bugs |
| C | Drag & Drop Sortierung | ✅ Next Up + Focus Block |
| D | Quick Task Capture | ✅ Control Center, Widget, Siri |
| E | Focus Block Ausfuehrung | ✅ Live Activity, Timer, Notifications |
| F | Sprint Review | ✅ Zeit-Tracking + UI |
| G | BacklogRow Redesign | ✅ Glass Cards, Chips, Swipe-Actions |

---

## Tooling

### Workflow-System: Parallele Workflows
**Status:** ✅ ERLEDIGT (2026-02-11)
**Fix:** Dateibasierte Workflow-Aufloesung in `workflow_gate.py`
