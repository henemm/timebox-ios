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

### BACKLOG-003: defaultTaskDuration synct nicht
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** MITTEL
**Dateien:** `AppSettings.swift`, `SettingsView.swift`, `SyncedSettings.swift`
**Fix:** Property in `AppSettings`, Picker auf iOS, iCloud KV Store Sync. Commit `0d0b0e2`.

---

### BACKLOG-004: Timer-Berechnungen dupliziert
**Status:** OFFEN
**Prioritaet:** MITTEL
**Dateien:** `MacFocusView.swift` (525-549), `FocusLiveView.swift` (577-671)
**Problem:** `calculateTaskProgress()`, `calculateRemainingTaskMinutes()` identisch in beiden Plattformen.
**Fix:** `TimerCalculator` Utility in `Sources/Services/` extrahieren.
**Scope:** ~60 LoC, 3 Dateien

---

### BACKLOG-005: Date-Formatter dupliziert (5x)
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Dateien:** `MacFocusView.swift`, `MacPlanningView.swift`, `MacReviewView.swift`, `DailyReviewView.swift`, `FocusLiveView.swift`
**Problem:** `timeRangeText()` wird in 5 Dateien identisch implementiert.
**Fix:** `FocusBlock` Extension mit computed property `timeRangeText`.
**Scope:** ~15 LoC, 5 Dateien

---

### BACKLOG-006: Color Hex Extension dupliziert
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Dateien:** `MacSettingsView.swift` (373-391), `SettingsView.swift` (214-232)
**Problem:** Identische `Color.init(hex:)` Extension in zwei Dateien.
**Fix:** Nach `Sources/Extensions/Color+Hex.swift` verschieben.
**Scope:** ~20 LoC, 3 Dateien

---

### BACKLOG-007: Review-Komponenten dupliziert (StatItem, CategoryBar, AccuracyPill)
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Dateien:** `MacReviewView.swift`, `DailyReviewView.swift`
**Problem:** `MacStatItem`/`StatItem`, `MacCategoryStat`/`CategoryStat`, `MacCategoryBar`/`CategoryBar` und `accuracyPill`/`macAccuracyPill` sind identische Komponenten mit unterschiedlichen Namen.
**Fix:** Unified Components in `Sources/Views/Components/` erstellen.
**Scope:** ~80 LoC, 3 Dateien

---

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

---

## ✅ Kuerzlich erledigt

### BACKLOG-001: Task Complete/Skip Logik in Shared Service extrahiert
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** `FocusBlockActionService` in `Sources/Services/` extrahiert. Beide Plattformen nutzen jetzt denselben Service fuer `markTaskComplete()` und `skipTask()`.
**Commit:** `fb4b76a`

### BACKLOG-002: EventKitRepository Injection (macOS)
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** Alle macOS Views nutzen jetzt `@Environment(\.eventKitRepository)` statt direkter Instanziierung. Shared Instanz wird in `FocusBloxMacApp` erstellt und injiziert.
**Commit:** `2487aa8`

### Bug 47: Vorwarnung-Settings ohne Auswirkung (macOS)
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix 1:** `MacFocusView.checkBlockEnd()` nutzt jetzt `AppSettings.shared.warningTiming` + `SoundService.playWarning()` (analog iOS)
**Fix 2:** `MacSettingsView` Picker nutzt jetzt `WarningTiming` Enum statt hardcodierter Werte
**Fix 3:** `SoundService` plattformkompatibel gemacht (`#if os(macOS)` / `NSSound.beep()`)
**Fix 4:** `SoundService.swift` zum macOS-Target hinzugefuegt
**Guideline:** Cross-Platform Code-Sharing Regel in CLAUDE.md aufgenommen

### Bug 35: Quick Capture - Spotlight + CC Button
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix 1:** CC Button setzt UserDefaults-Flag statt OpenURLIntent (Widget-Extension kompatibel)
**Fix 2:** Spotlight oeffnet App mit Titel-Vorbelegung statt Interactive Snippet
**Commit:** `382a5a1`

### Bug 41: LiveActivity Timer Fixes
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix 1:** Timer stoppt bei 0:00 statt hochzuzaehlen (`timerInterval:countsDown:`)
**Fix 2:** Timer zeigt Task-Restzeit statt Block-Restzeit (`taskEndDate` in ContentState)
**Commit:** `dd74009`

### Bug 40: Review Tab zeigt erledigte Tasks nicht
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix:** `markTaskComplete()` setzt jetzt auch `LocalTask.isCompleted = true` in SwiftData
**Commit:** `ccbcf0f`

### Bug 39: FocusBlock Lifecycle
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix 1:** Block bleibt nach Ende sichtbar (Sprint Review moeglich)
**Fix 2:** Unerledigte Tasks zurueck in Next Up
**Fix 3:** Abgelaufene Blocks nicht in Zuweisen-Tab
**Fix 4:** Push-Notification bei Block-Ende
**Commit:** `149ab4e`

### Bug 38: Cross-Platform Sync
**Status:** ✅ ERLEDIGT (2026-02-12)
**Fix 1:** FocusBlocks aus ALLEN Kalendern laden (nicht nur sichtbare)
**Fix 2:** SyncedSettings mit iCloud Key-Value Store
**Commit:** `49f5f9c`

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
