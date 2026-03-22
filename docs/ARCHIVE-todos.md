# Archiv — Erledigte Todos

> Hierher verschoben aus `ACTIVE-todos.md` am 2026-03-12.
> Aktive Items: siehe `docs/ACTIVE-todos.md`

---

## RW_0.1a — Smart Notification Engine Phase A (Foundation) — ERLEDIGT (2026-03-22)

- **Epic:** 0 Infrastruktur | **Spec:** `docs/specs/rework/0.1-smart-notification-engine-impl.md`
- **Ziel:** Zentraler SmartNotificationEngine-Service mit Reconcile-on-Event-Strategie, 3 Notification-Profile, Budget-Priorisierung (64 Slots)
- **Aenderungen:**
  - `Sources/Services/SmartNotificationEngine.swift` — NEU: Engine Core mit reconcile(), buildAllRequests(), Timer/Task-Request-Builder, BGAppRefreshTask
  - `Sources/Models/AppSettings.swift` — Notification Profile Property (quiet/balanced/active)
  - `Sources/FocusBloxApp.swift` — reconcile() Integration bei Foreground/Background, rescheduleDueDateNotifications() entfernt
- **Tests:** 12 Unit Tests + 2 UI Tests (alle gruen)
- **Naechste Phasen:** RW_0.1b (FocusBlock Migration), RW_0.1c (DueDate + Settings UI)

---

## RW_3.2 — Focus Sprint ("Los"-Button) — ERLEDIGT (2026-03-21)

- **Epic:** 3 Ausfuehrung | **Spec:** `docs/specs/rework/3.2-focus-sprint-impl.md`
- **Ziel:** Focus Sprint direkt aus dem Backlog starten ueber "Los"-Button
- **Commit:** `72bfc9d`

---

## RW_1.1 — Quick Dump — ERLEDIGT (2026-03-21)

- **Epic:** 1 Erfassung | **Spec:** `docs/specs/rework/1.1-quick-dump.md`
- **Ziel:** Task-Erfassung in < 3 Sekunden, Task landet im Refiner statt im Backlog
- **Aenderungen:**
  - `LocalTask.swift`: `TaskLifecycleStatus` Enum (raw/refined/active) + `lifecycleStatus` Property (String, Default "active"), Migration setzt bestehende Tasks auf `.active`
  - 6 Quick-Capture-Einstiegspunkte setzen `lifecycleStatus = "raw"`: `QuickCaptureView`, `QuickCapturePanel`, `CreateTaskIntent`, iOS ShareExtension, macOS ShareExtension, watchOS VoiceInput
  - `LocalTaskSource.fetchIncompleteTasks()`: filtert `.raw`-Tasks aus dem Backlog heraus
  - `WatchLocalTask.swift`: passendes Schema fuer CloudKit-Parity
  - `PlanItem`: kopiert `lifecycleStatus` von `LocalTask`

---

## FEATURE_027 — Erledigt-View Kontextmenü & Swipe-Aktionen — ERLEDIGT

- **Beschreibung:** Erledigt-View (Papierkorb-Metapher): Kontextmenü und Swipe-Gesten fokussieren auf Wiederherstellen als primäre Aktion. Löschen ist sekundär.
- **Änderungen:**
  - iOS (`BacklogView.swift`): CompletedTaskRow vereinfacht (keine Inline-Buttons), Kontextmenü hinzugefügt (Wiederherstellen + Löschen), trailing Swipe ohne Full-Swipe
  - macOS (`ContentView.swift`): Eigene `completedTaskRowWithSwipe()`, `completedContextMenu()`, `uncompleteTasksByIds()` — nutzt SyncEngine
- **Tests:** 2 iOS UI Tests + 4 macOS UI Tests — alle GREEN
- **Spec:** `docs/specs/features/feature-027-erledigt-view-kontextmenue.md`
- **Datum:** 2026-03-19

---

## BUG_112 — macOS Series-Delete Crash (LocalTask.tags BackingData detach) — ERLEDIGT

- **Problem:** macOS App crasht beim Rechtsklick → Löschen → "Alle offenen dieser Serie". Crash: `Fatal error: This backing data was detached from a context without resolving attribute faults: \LocalTask.tags`
- **Root Cause:** `taskToDeleteRecurring: LocalTask?` (class/reference type) wurde NACH `deleteRecurringSeries()` auf nil gesetzt. Die Funktion löschte den Task inkl. sich selbst → backing data sofort detached. SwiftUI Re-render griff auf `task.tags` zu → CRASH.
- **Fix (ContentView.swift):**
  1. `taskToDeleteRecurring = nil` + `selectedTasks.removeAll()` VOR dem Delete
  2. Lokale `deleteRecurringSeries(_ task: LocalTask)` durch `SyncEngine.deleteRecurringSeries(groupID: String)` ersetzt (kein LocalTask-Objekt mehr nach Delete)
  3. `modelContext != nil` Guard in `nextUpTasks` hinzugefügt (defensive Absicherung)
- **Tests:** 3 macOS UI Tests (`MacSeriesDeleteCrashUITests`) — alle GREEN
- **Commit:** `133cb10`
- **Datum:** 2026-03-19

---

## FEATURE_015 — UX: Tag-Auswahl redesignen (ERLEDIGT)

- **Problem:** Tag-Sektion in TaskFormSheet unuebersichtlich — "Neuer Tag" Input dominierte, bestehende Tags erschienen erst darunter
- **Fix:** Layout-Reorder in TagInputView: Suggestions (FlowLayout Chips) oben, zugewiesene Tags mittig, Input-Feld unten. Einheitlicher Chip-Style cross-platform.
- **Dateien:** TagInputView.swift, TagRedesignUITests.swift (neu), project.pbxproj, sim.sh
- **Tests:** 3 UI Tests GREEN (Layout-Order, Tap-Suggestion, Remove-Tag)
- **Spec:** `docs/specs/ios/feature-015-tag-redesign.md`

---

## BUG_105 — Coach AI-Pitches: generisch + halluziniert + abgeschnitten (ERLEDIGT)

- **Problem:** AI halluzinierte Task-Namen, Text abgeschnitten
- **Fix:** `@Generable` Struct mit `@Guide` in CoachPitchService, `shouldAcceptPitch` entfernt
- **Dateien:** CoachPitchService.swift
- **Artefakte:** `docs/artifacts/bug-coach-pitch-quality/`

---

## FEATURE_002 — Coach-Backlog iOS: Blocked-Row Editing (ERLEDIGT)

- **Problem:** Blocked Rows im Coach-Backlog hatten keine Trailing-Swipe-Actions (Bearbeiten + Loeschen)
- **Fix:** `.swipeActions(edge: .trailing)` in `CoachBacklogView.blockedRow()` ergaenzt — 1:1 Parity mit BacklogView
- **Dateien:** CoachBacklogView.swift (+12 LoC), CoachBacklogViewUITests.swift (+40 LoC)
- **Tests:** 2 UI Tests GREEN

---

## BUG_106 — Trend-Chart: Disziplin statt Kategorie (ERLEDIGT)

- **Problem:** Discipline.classify() hatte Proxy-Bug — effectiveDuration == estimatedDuration immer true → 95% Tasks in Fokus/Ausdauer → einfarbige Trend-Wand
- **Fix:** Trend-Chart gruppiert nach TaskCategory statt Discipline
- **Dateien:** CategoryStatsService.swift (neu), CategoryTrendChart.swift (neu), CoachMeinTagView.swift, ReviewComponents.swift
- **Tests:** 10 Unit + 3 UI Tests GREEN

---

## ERLEDIGT: Feature — Monster Coach Phase 2 (Morning Intention)

- **Anforderung:** Morning Intention Screen — die taegliche Frage "Wie wird dein Tag?" mit 6 waehlbaren Intentionen (Mehrfach-Auswahl)
- **Umfang:**
  - `DailyIntention` Model + `IntentionOption` Enum (6 Cases: survival, fokus, bhag, balance, growth, connection)
  - `MorningIntentionView` — Zwei-Zustand View (Selection Grid mit 6 Chips / kompakte Zusammenfassung)
  - Review-Tab zeigt "Mein Tag" statt "Review" wenn Coach aktiviert
  - Konfigurierbare Push-Notification Morgen-Erinnerung ("Guten Morgen — Was soll heute zaehlen?")
  - Settings: Morgen-Erinnerung Toggle + Uhrzeit-Picker im Monster Coach Bereich
  - UserDefaults-Persistenz (pro Tag ein Key: `dailyIntention_YYYY-MM-DD`)
- **Tests:** 16 Unit Tests + 6 UI Tests (alle GREEN)
- **Dateien:** 2 neue (DailyIntention.swift, MorningIntentionView.swift) + 6 geaendert (DailyReviewView, MainTabView, AppSettings, NotificationService, SettingsView, FocusBloxApp)

---

## ERLEDIGT: Cleanup — XP/Evolution-System entfernt (widersprach User Story)

- **Grund:** Phase 1 hat ein Gamification-System gebaut (XP, Levels, Evolution Ei→Meister) das der User Story explizit widerspricht: "Keine XP, Levels, Achievements". Henning: "Es geht nicht um XP sondern darum, dass ich abends gelobt werde und worauf ich mit Stolz zurueckblicken kann."
- **Was BLEIBT:**
  - `Discipline.swift` — Task-Klassifizierung (Konsequenz, Ausdauer, Mut, Fokus) ist gewollt
  - `coachModeEnabled` Toggle + Morning Intention + Reminder — alles Phase 2, korrekt
  - "Mein Tag" Tab-Name bei aktivem Coach
- **Was WEG muss (Code):**
  - [x] `MonsterCoach.swift` — GELOESCHT
  - [x] `MonsterStatusView.swift` — GELOESCHT
  - [x] `MonsterCoachTests.swift` — GELOESCHT
  - [x] `MonsterCoachUITests.swift` — GELOESCHT
  - [x] `DailyReviewView.swift` — `monsterCoach` State + `MonsterStatusView` Block entfernt
  - [x] `project.pbxproj` — Geloeschte Files aus Build-Targets entfernt
- **Dateien:** 4 loeschen + 2 modifizieren + 3 Docs aktualisieren

---

## ENTFERNT: Feature — Monster Coach Phase 1 (Foundation) — XP/Evolution WIDERSPRICHT User Story

- **Problem:** Hat XP-Punkte, Evolution-Levels (Ei→Meister) und Gamification gebaut — obwohl die User Story explizit sagt: "Keine XP, Levels, Achievements"
- **Was entfernt wird:** MonsterCoach Model, MonsterStatusView, zugehoerige Tests
- **Was bleibt:** Discipline Enum (Task-Klassifizierung), Coach-Modus Toggle, Settings-Integration

---

## ERLEDIGT: Monster Coach Phase 3a: Intention-basierter Backlog-Filter

- Nach Morgen-Auswahl → App wechselt automatisch zum Backlog-Tab mit aktivem Filter-Chip
- 6 Filter-Mappings implementiert
- **Tests:** 10 Unit Tests + 6 UI Tests — alle GRUEN
- **Spec:** `openspec/changes/monster-coach-phase3a/proposal.md`

---

## ERLEDIGT: Monster Coach Phase 3b: Smart Notifications — Tagesbegleitung

- Notifications feuern NUR bei Luecken zwischen Intention und Handlung
- Stille-Regel: Sobald Intention erfuellt → keine weiteren Notifications
- Neuer `IntentionEvaluationService` (stateless, pure functions)
- **Tests:** 27 Unit Tests + 5 UI Tests — alle GRUEN
- **Spec:** `openspec/changes/monster-coach-phase3b/proposal.md`

---

## ERLEDIGT: Feature — Task-Abhaengigkeiten (Blocker)

- **Phase 1-3 + BUG-DEP-1 bis BUG-DEP-7:** Alle erledigt
- **Spec:** `openspec/changes/sub-tasks/proposal.md`

---

## ERLEDIGT: Bug — Recurring Tasks erscheinen nach Loeschen wieder ("Zombie-Schleife")

- **Fix:** Template-Check in `repairOrphanedRecurringSeries()`
- **Tests:** 4 Repair-Tests GREEN

---

## ERLEDIGT: Bug — AI Title Improvement entfernt Doppelpunkt-Prefixe

- **Fix:** Dreifach-Schutz: Safety Guard + AI-Instruktionen + @Guide verschaerft
- **Tests:** 7 neue Tests, 34 gesamt

---

## ERLEDIGT: Feature — Deferred Task Completion (3-Sekunden Delay)

- **Loesung:** `DeferredCompletionController` — Shared Service
- **Tests:** 7 Unit Tests + 7 UI Tests

---

## ERLEDIGT: Bug — macOS UI Tests leaken Mock-Daten in echte Datenbank

- **Fix:** `-UITesting` Flag + Cleanup-Funktion
- **Tests:** Build OK

---

## ERLEDIGT: Bug 83 — Focus View Task Count Widerspruch (iOS + macOS)

- **Fix:** `resolvedTaskCount()` / `resolvedCompletedCount()` Helper
- **Tests:** 7 Unit Tests

---

## ERLEDIGT: Bug — Ueberlappende Timeline-Events falsch dargestellt (iOS + macOS)

- **Fix:** Greedy Column-Assignment in `TimelineItem.assignColumns()`
- **Tests:** 20 Unit Tests + 2 UI Tests

---

## ERLEDIGT: Bug — Tasks springen bei Wichtigkeit/Dringlichkeit/Dauer-Aenderung (iOS + macOS)

- **Fix:** `frozenSortSnapshot` friert Scores ein, sanftes Gleiten nach 3s
- **Tests:** 5 UI Tests

---

## ERLEDIGT: Bug 90 — Watch Notification Actions wirkungslos

- **Fix:** Delegate-Registrierung von `.onAppear` nach `init()`, macOS @Query → @State
- **Tests:** 8 Unit Tests

---

## ERLEDIGT: Bug — Watch-Tasks ohne Enrichment

- **Fix:** `enrichAllTbdTasks()` bei App-Start + CloudKit-Sync
- **Tests:** 5 Unit Tests

---

## ERLEDIGT: Feature #29 — Badge-Zahl (Overdue) + Interaktive Frist-Notifications

- **Spec:** `docs/specs/features/badge-overdue-notifications.md`
- **Tests:** 5 Tests

---

## ERLEDIGT: Feature — Watch Quick Capture Complication

- **Spec:** `docs/specs/features/watch-complication.md`
- **Tests:** 27 Watch-Tests

---

## ERLEDIGT: Feature — Watch Quick Capture In-App Flow vereinfacht

- **Spec:** `docs/specs/features/watch-quick-capture-inapp.md`
- **Tests:** 4 UI Tests

---

## ERLEDIGT: Bug — Watch-Task erscheint nicht auf iPhone (Watch→iPhone Sync)

- **Fix:** CloudKit-Entitlements + Stored-Property-Defaults
- **Tests:** 3 neue Tests, 19 Watch-Tests gesamt

---

## ERLEDIGT: Bug — Watch-App Crash auf Apple Watch Ultra 3

- **Fix:** 3 fehlende Felder in `WatchLocalTask.swift`
- **Tests:** 4 neue Tests, 16 Watch-Tests gesamt

---

## ERLEDIGT: Feature — Unified Calendar View (Phase 1)

- **Spec:** `docs/specs/features/unified-calendar-view.md`
- **Tests:** 8 UI Tests

---

## ERLEDIGT: Bug 88 — Siri "Erstelle Task" verliert diktierten Text

- **Fix:** `defaults.synchronize()` nach UserDefaults-Writes
- **Tests:** 2 Unit Tests

---

## ERLEDIGT: Bug — Siri-Shortcuts nicht funktional + SiriTipView nicht persistent

- **Fix:** `updateAppShortcutParameters()` + `@AppStorage` statt `@State`
- **Tests:** UI Test

---

## ERLEDIGT: Bug — Toolbar inkonsistent in BacklogView (iOS)

- **Fix:** SiriTipView entfernt, Toolbar konsolidiert (3 Items)
- **Tests:** 7 UI Tests

---

## ERLEDIGT: Bug — Sync zwischen macOS und iOS langsam/nicht automatisch

- **Fix:** scenePhase Handler + remoteChangeCount Observer + save() vor fetch()
- **Tests:** 8 Unit Tests

---

## ERLEDIGT: Bug — macOS Arithmetic Overflow in addToNextUp

- **Fix:** Shared `SyncEngine.updateNextUp()`
- **Tests:** 4 Unit Tests

---

## ERLEDIGT: ITB-G macOS Build Fix

- Intent Donations mit `#if !os(macOS)` guarded

---

## ERLEDIGT: TD-02 Paket 1-3 — Shared Components

- **Paket 1:** Shared Badge Components (5 Badges)
- **Paket 2:** Shared Sheet Components (CreateFocusBlockSheet + EventCategorySheet)
- **Paket 3:** Shared FocusBlockCardHeader

---

## ERLEDIGT: CTC-3 — macOS Share Extension

- Neues Target `FocusBloxMacShareExtension`

---

## ERLEDIGT: Bug 62-89 (alle geloest)

- Bug 62: Share Extension CloudKit Crash
- Bug 63: Kategorie-Zuweisung bei wiederkehrenden Events
- Bug 64: Kategorie-Icon zu klein
- Bug 65: Listendarstellung iOS vs macOS divergiert
- Bug 66: macOS FocusBlock MenuBar + Sync-Deadlock
- Bug 67: Tab-Labels Deutsch→English
- Bug 68: FocusBlock View-Umbau
- Bug 69: FocusBlock Cross-Platform Sync
- Bug 70a-d: FocusBlock Snapping, Drag & Drop, Resize, Drag-Indicator
- Bug 70c-1a/1b: Shared Timeline Layout + iOS Canvas Rebuild
- Bug 71: Urgency-Keywords nicht entfernt
- Bug 72: macOS Gear-Icon fehlt
- Bug 73: Tasks-Dialog ohne Prioritaets-Info
- Bug 74: Sheet dismiss nach Speichern
- Bug 75: macOS App-Icon falsch
- Bug 76: macOS Task verschwindet nach Anlegen
- Bug 77: macOS Orange Umrandung zu eng
- Bug 78: macOS Crash bei Swipe (SwiftData Fault)
- Bug 79: Kalender-Event-Badges deutsche Labels
- Bug 80: Kalender-Kategorien iOS↔macOS Sync
- Bug 81: FocusBlock Task-Zuweisung verliert ersten Task
- Bug 82: Erledigte Tasks — Suche funktioniert nicht
- Bug 83: Focus View Task Count Widerspruch
- Bug 84: App-Icon Badge zaehlt NextUp/FocusBlock-Tasks mit
- Bug 85-A: Uhrzeit bei Faelligkeitsdatum anzeigen
- Bug 85-B: Notification Snooze-Optionen
- Bug 85-C: Kontextmenue Verschieben-Optionen
- Bug 85-D: Postpone falsches Ursprungsdatum
- Bug 86: macOS Text-Truncation
- Bug 87: QuickCapture Dialog schliesst nicht
- Bug 88: macOS MenuBar Timer falsch
- Bug 89: Kategorie-Aenderung erst nach Verschieben sichtbar
- Bug 90: Watch Notification Actions wirkungslos
- Bug 91: macOS Menuleisten-Icon

---

## ERLEDIGT: Feature — Blocker-Picker mit Suchfunktion

- Shared `BlockerPickerSheet` (iOS + macOS)
- **Tests:** 4 UI Tests

---

## ERLEDIGT: Feature — App Icon (alle Plattformen)

- **Spec:** `docs/specs/design/app-icon-liquid-glass.md`
- Two Rings + Dot Design

---

## Erledigte Tech-Debts

- BACKLOG-001: Task Complete/Skip Divergenz
- BACKLOG-002: EventKitRepository Injection macOS
- BACKLOG-003: NextUp Toolbar Divergenz
- BACKLOG-004: BacklogView/BacklogRow
- BACKLOG-005: RecurrenceRuleView Divergenz
- BACKLOG-006: TaskEditView Divergenz
- BACKLOG-007: SidebarView macOS-only (kein Debt)
- BACKLOG-008: Workflow-System Parallelitaet
- BACKLOG-009: Tech-Debt Quick Wins
- BACKLOG-010: Deferred Sort Logik dupliziert
- BACKLOG-011: MacBacklogRow Score-Berechnung
- BACKLOG-012: displayedRegularTasks toter Wrapper
- BACKLOG-013: macOS Text-Truncation Blast Radius
- BACKLOG-014: calculateScore() Duplikation

---

## Chronologisches Archiv (aelteste zuerst)

### 2026-02-03: ITB-B — Smart Priority (AI-Enrichment + Hybrid-Scoring)
### 2026-02-04: Recurring Tasks Phase 1B/2
### 2026-02-05: Push Notifications bei Frist
### 2026-02-06: Generische Suche (iOS+macOS)
### 2026-02-07: List-Views Cleanup (ViewModes 9→5)
### 2026-02-08: NextUp Wischgesten (Edit+Delete)
### 2026-02-09: NextUp Long Press Vorschau
### 2026-02-10: Settings UX - Build-Info + Vorwarnungs-Labels
### 2026-02-11: Bug 52 - Import aus Erinnerungen
### 2026-02-12: Bug 53 - macOS Swipe Actions
### 2026-02-13: Bug 54 - Recurring Tasks nach Completion sichtbar
### 2026-02-14: Recurrence Editing Phase 2
### 2026-02-15: Bug 55 - Recurring Tasks Divergenz iOS/macOS
### 2026-02-16: Bug 56 - AI Enrichment bei EventKit Import
### 2026-02-17: Bug 57 - Safe Setter importance/urgency/duration
### 2026-02-18: Bug 38 - CloudKit Sync zwischen iOS Geraeten
### 2026-02-19: ITB-A — FocusBlockEntity
### 2026-02-20: ITB-D — Pulsierender Glow-Effekt
### 2026-02-21: ITB-F-lite — NSUserActivity
### 2026-02-22: Undo Task Completion
### 2026-03-03: Deferred List Sorting — 3 Bugfixes
### 2026-03-04: Tech-Debt Quick Wins Bundle
### 2026-03-04: Stop-Lock + API-Guard
### 2026-03-12: XP/Evolution-System entfernt
### 2026-03-12: Monster Coach Phase 2 — Morning Intention Screen

---

## Verschoben am 2026-03-20: Backlog-Aufraeumen

### TD_004: Monster-Removal: Dead Code Cleanup — ERLEDIGT
- 4 tote Dateien geloescht (DailyIntention.swift, 3 Coach-UI-Tests), 3 Dateien bereinigt (DebugHierarchy, MacToolbar, AI-Prompt), PBX-Refs entfernt. -426 LoC. 6 Validierungstests GRUEN.

### BUG_114: FocusBloxMac: SwiftData Cast-Fehler in LocalTask.tags — ERLEDIGT
- **Root Cause:** `LocalTask.tags` war `[String]` (non-optional). Bei NULL in SQLite (CloudKit sync) → `swift_dynamicCastFailure`. Fix: `tags` auf `[String]?` (optional) + `?? []` an allen ~20 Zugriffspunkten.

### BUG_113: FocusBloxMac: Start-Crash in DEBUG — CloudKit Signing-Assertion — ERLEDIGT
- **Problem:** macOS App crasht beim Start in DEBUG-Builds mit EXC_BREAKPOINT auf `com.apple.coredata.cloudkit.queue`. Root Cause: CloudKit in DEBUG-Builds mit leerer `codeSigningTeamID`. Nicht mehr reproduzierbar.

---

## Verschoben am 2026-03-19: Session-Ergebnisse

### FEATURE_026: Priority View Score-Sortierung & Coach-Boost — ERLEDIGT
- **Fix:** Alle Sections (Ueberfaellig, Coach) nach Priority Score sortiert. Ueberfaellige Daten rot hervorgehoben. Monster-Modus boostet Score (+15) statt eigener Section. Commit f7ba5f7.

### FEATURE_023 (v2): macOS Suche vereinheitlichen — ERLEDIGT
- **v1.1:** Quick-Add Bar entfernt, (+) Button + MacTaskCreateSheet.
- **v2 (2026-03-19):** `.searchable()` Toolbar-Suche durch Inline-TextField ersetzt (backlogSearchField). Alle UI Tests gruen.
- **Specs:** `docs/specs/macos/feature-023-unified-search.md`, `docs/specs/macos/feature-023-v2-inline-search.md`. Commit 253574d.

### FEATURE_004: Coach-Backlog-Suche (macOS) — ERLEDIGT
- Implementiert durch FEATURE_023_v2 (Inline-Suchfeld ueber Task-Liste). Coach-Backlog filtert in Echtzeit. 4 TDD-Tests GREEN. Abgeschlossen 2026-03-19.

### BUG_109: Backlog Relevanz-Sortierung invertiert — ERLEDIGT
- **Root Cause:** Next Up Section hatte keine Score-Sortierung (Tasks in DB-Einfuegereihenfolge statt nach priorityScore absteigend).
- **Fix:** `.sorted { $0.priorityScore > $1.priorityScore }` in `nextUpTasks`. UI Test: `NextUpSortOrderUITests`. macOS nicht betroffen. Commit 7f4ba90.

### BUG_110: macOS Coach-Backlog Doppelte Controls — ERLEDIGT
- **Fix:** Coach-Toolbar (ViewMode-Switcher + Sync/Import) entfernt; Sidebar und App-Toolbar decken alles ab. Commit 51ca698.

### TD_003: Workflow-Bypass-Haertung — ERLEDIGT
- 4 Bypass-Vektoren geschlossen: (1) `state_integrity_guard.py` blockiert Bash-Schreibzugriffe auf State/Hooks/Settings, (2) `set-field` Blocklist auf 16 Felder erweitert, (3) `--force` Flag entfernt, (4) `.claude/hooks/` aus Whitelists entfernt. Commit 5f74211.

---

## Verschoben am 2026-03-18: Backlog-Aufraeumen nach View-Merge (BUG_109)

### BUG_109: Coach-Backlog macOS: Sidebar-Filter fehlen im Monster-Modus — ERLEDIGT
- **Fix:** SidebarView fuer beide Modi (Normal + Monster). View-Vereinheitlichung: CoachBacklogView.swift (iOS) + MacCoachBacklogView.swift (macOS) geloescht, Features in BacklogView.swift bzw. ContentView.swift gemergt (~1400 LoC Duplikation eliminiert).
- **Analyse:** `docs/artifacts/bug-backlog-monster-views/analysis.md`

### BUG_107: Coach-Backlog: Blocked Tasks erscheinen doppelt — ERLEDIGT
- **Fix:** 4 Filter in CoachBacklogViewModel ergaenzt (`blockerTaskID == nil` / `!isBlocked`). 30/30 Unit Tests gruen.

### BUG_108: Zehnagel-Zombie: Recurring Task ueberlebt Serien-Ende — ERLEDIGT
- **Fix:** deleteRecurringTemplate neutralisiert completed Tasks (recurrencePattern=none), Startup-Reihenfolge migration→dedup→repair.
- **Analyse:** `docs/artifacts/bug-108-zehnagel-zombie/analysis.md`

### FEATURE_003: Coach-Backlog macOS: Quick-Add TextField — ERLEDIGT
- **Fix:** Quick-Add TextField + Button + onAddTask callback. 2 UI Tests gruen.

### FEATURE_004, 006, 007, 008, 009, 013, 014: Coach-Backlog Feature-Gaps — OBSOLET durch View-Merge
- **Grund:** BUG_109 hat CoachBacklogView.swift (iOS) + MacCoachBacklogView.swift (macOS) geloescht und alle Features in die gemeinsame BacklogView/ContentView gemergt. Monster-Modus erbt automatisch alle Normal-Modus-Features:
  - FEATURE_004: Suchfunktion (.searchable)
  - FEATURE_006: Inspector Panel (3-Spalten-Layout)
  - FEATURE_007: Multi-Selection + Bulk Actions
  - FEATURE_008: Drag-to-Reorder NextUp
  - FEATURE_009: Deferred Sort/Completion Feedback
  - FEATURE_013: Serien-Bearbeitung (Recurring-Dialoge)
  - FEATURE_014: Apple Reminders Import

---

## Verschoben am 2026-03-16: Backlog-Restrukturierung

### Bug 104: Coach-Backlog Feature-Paritaet — iOS + macOS — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Problem:** CoachBacklogView (iOS) und MacCoachBacklogView (macOS) fehlten zahlreiche Features der normalen BacklogView.
- **Fix (7 Pakete):**
  - P0: macOS Completion-Button repariert (onToggleComplete verdrahtet)
  - P1: CoachBacklogViewModel erweitert: coachBoostedTasks, remainingTasks, overdueTasks, tierTasks, recentTasks, completedTasks, recurringTasks, coachSectionTitle (shared Logic)
  - P2a: iOS alle Callbacks verdrahtet (11 BacklogRow-Closures), DurationPicker/CategoryPicker Sheets, TaskFormSheet, Postpone-Kontextmenu, DeferredSort/Completion
  - P2b: iOS ViewMode-Switcher (5 Modi: Prioritaet/Zuletzt/Ueberfaellig/Wiederkehrend/Erledigt), Coach-Boost-Section, Priority-Tier-Sections (4 Stufen), deduplizierte Task-Zuordnung
  - P3: macOS volle Paritaet: ViewMode-Switcher, alle MacBacklogRow-Callbacks, Tier-Sections, Coach-Boost, Postpone/Disziplin/Delete Context-Menu
  - P4: iOS CloudKit Sync Auto-Refresh + Shake-to-Undo
  - P5: Blocked-Task-Rendering (Lock-Icon, Einrueckung, Freigeben-Aktion) auf beiden Plattformen
- **Tests:** 24 CoachBacklogViewModelTests gruen (7 neue Methoden getestet)
- **Dateien:** CoachBacklogViewModel.swift, CoachBacklogView.swift, MacCoachBacklogView.swift, CoachBacklogViewModelTests.swift

### Bug 103: NextUp-Section fehlt in Monster-Modus — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** CoachBacklogView wurde in Phase 5a mit nur 2 Sections designed — NextUp-Tasks waren unsichtbar.
- **Fix:** `CoachBacklogViewModel.nextUpTasks()`, NextUp-Section mit gruenem Header + Count-Badge, macOS Context-Menu erweitert
- **Tests:** 5 Unit Tests + 2 iOS UI Tests + 1 macOS UI Test

### Bug: macOS Coach Backlog leer im Monster-Mode — ERLEDIGT
- **Status:** DONE
- **Plattform:** macOS
- **Root Cause:** `.task { refreshTasks() }` an `backlogView` gebunden — bei `coachModeEnabled == true` nie gerendert.
- **Fix:** `.task` und `.onChange` auf NavigationSplitView verschoben

### Bug 102: Coach-Wahl wird NICHT zwischen iOS und macOS synchronisiert — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** pushToCloud() ueberschrieb valide Remote-Daten mit leeren lokalen Werten.
- **Fix:** pullFromCloud() vor pushToCloud(), Guard gegen leere Coach-Pushes
- **Tests:** 7 Unit Tests + 2 UI Tests

### Bug 98: Mein Tag Woche zeigt nur Sprint-Tasks — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** DailyReviewView Guard zu restriktiv + CoachMeinTagView hatte keine Wochenansicht.
- **Fix:** Guard erweitert, CoachMeinTagView Weekly Mode mit Coach-Texten
- **Tests:** 48 IntentionEvaluationServiceTests + 20 EveningReflectionTextServiceTests

### Bug 101: macOS hat 5 Views statt 4 — ERLEDIGT
- **Status:** DONE
- **Plattform:** macOS
- **Fix:** `.assign` aus MainSection entfernt, MacAssignView geloescht (-720 LoC)
- **Tests:** 6 MacToolbarNavigationUITests + 2 UnifiedTabSymbolsTests

### Bugs 93, 94, 95, 96, 97, 99, 100, Abend-Review — alle ERLEDIGT
- Bug 93: Swipe-Gesten bei eingerueckten Tasks
- Bug 94: macOS — Neuer Task bekommt keinen Fokus
- Bug 95: Neue Tasks bekommen immer Faelligkeitsdatum "heute"
- Bug 96: Apple Shortcut oeffnet App statt Hintergrund-Save
- Bug 97: Apple Shortcut — "heute" nicht als Datum erkannt
- Bug 99: CoachBacklogView — Next-Up-Swipe fehlt
- Bug 100: Intention-Labels (OBSOLET nach Coach-Redesign)
- Bug: Abend-Review Text zu generisch

### Coach-Redesign: 4 Coaches statt 6 Absichten — ERLEDIGT
- 116 Unit Tests + 14 UI Tests gruen
- 6 Morgen-Absichten ersetzt durch 4 Monster-Coaches (Troll, Feuer, Eule, Golem)

### Coach Mission Card — ERLEDIGT
- Monster spricht mit konkreter Tages-Mission an. 10 Unit Tests gruen.

### Coach Preview + Apple Intelligence Pitches — ERLEDIGT
- Coach-Auswahl zeigt konkrete Tasks + AI-Pitches. 23 Tests gruen.

### Coach-Auswahl vertikales Layout + ausfuehrliche AI-Pitches — ERLEDIGT
- 2x2-Grid durch vertikale Liste ersetzt. 14 Tests gruen.

### Discipline manuell ueberschreiben — ERLEDIGT
- Long-Press Context Menu mit 4 Disziplin-Optionen. 10 Unit + 6 UI Tests gruen.

### Monster Coach Phase 3 "Der Tagesbogen" — KOMPLETT ERLEDIGT
- Phase 3a-3f alle erledigt (Backlog-Filter, Smart Notifications, Abend-Spiegel, Foundation Models, Push-Notification, Siri Integration)

### Monster Coach Phase 4 "Monster-Grafiken & Visualisierung" — KOMPLETT ERLEDIGT
- Phase 4a-4e alle erledigt (Monster-Assets, Coach-Auswahl, Abend-Spiegel, Push-Notifications)

### Monster Coach Phase 5 "Eigene Coach-Views" — KOMPLETT ERLEDIGT
- Phase 5a: CoachBacklogView, Phase 5b: CoachMeinTagView

### Monster Coach Phase 6 "macOS-Paritaet" — KOMPLETT ERLEDIGT
- Phase 6a: Coach-Settings macOS
- Phase 6b: CoachBacklogView macOS
- Phase 6c: Coach-Auswahl macOS
- Phase 6d: EveningReflectionCard macOS
- Phase 6e: CoachMeinTagView macOS (shared, MacCoachReviewView geloescht)

### Watch: Quick Capture vereinfachen — ERLEDIGT
- VoiceInputSheet vereinfacht, Auto-Save 1.5s→0.5s. 7 UI Tests gruen.

### TD-03: Services ohne Tests — ERLEDIGT
- 44 Unit Tests (GapFinder 15, NotificationService 17, FocusBlockActionService 12)

### TD-04: Parallele Claude Code Sessions absichern — ERLEDIGT
- File-Locking, Overlap→Block, Phase-Eintritt-Guard

### TD-05: Coach Views Cross-Platform Consolidation (Pilot) — ERLEDIGT
- Duplizierte Filter-Logik in shared CoachBacklogViewModel extrahiert. 14 Unit Tests gruen.

---

## Verschoben am 2026-03-16: Session-Ergebnisse

### FEATURE_001: Coach-Backlog iOS: Recurring-Serie-Dialoge — ERLEDIGT
- Confirmation-Dialoge (Nur diese Aufgabe / Alle offenen dieser Serie) beim Loeschen/Bearbeiten wiederkehrender Tasks. 3 Dialoge, Recurring-Check + Template-Check, 5 UI Tests gruen.

### FEATURE_005: Coach-Backlog macOS: Toolbar (Sync + Import) — ERLEDIGT
- Commit bc87d5e + Adversary-Fix.

### FEATURE_012: Coach-Backlog macOS: effectiveScore/Tier/dependentCount — ERLEDIGT
- dependentCount, effectiveScore, effectiveTier an MacBacklogRow uebergeben. DEP-Blocker-Tasks zeigen korrekten Score mit Boost (+3). 2 UI Tests gruen. TaskBadges: macOS-Accessibility-Fix. Commit de67c9f.

### FEATURE_016: Disziplin-Entwicklung sichtbar machen — ERLEDIGT
- Phase 1: Disziplin-Profil (Heute + Woche) in CoachMeinTagView. Phase 2 (Multi-Wochen-Trend) als separates Ticket (FEATURE_023).

### FEATURE_023: Disziplin-Trend (Multi-Wochen) — ERLEDIGT
- Multi-Wochen-Trend mit Swift Charts in CoachMeinTagView. Stacked Bar Chart (6 Wochen), Trend-Erkennung (growing/declining/stable), staerkstes Disziplin-Highlight. 9 Unit Tests + 3 UI Tests gruen. Commit 37fa398.

### FEATURE_024: Sprint Follow-up Action — ERLEDIGT
- Dritte Sprint-Aktion "Follow-up" neben Ueberspringen/Erledigt. Schliesst aktuellen Task, erstellt editierbare Kopie mit vollem TaskFormSheet. Cancel-Discard-Logik (Sheet-Abbruch loescht Kopie). 6 Unit Tests + 3 UI Tests gruen. Adversary verified. Commit 5b8cd64.

### CHORE_001: Aufraeumen uncommitted Dateien — ERLEDIGT
- .gitignore erweitert, State-Dateien aus Tracking entfernt, alle Artefakte committet.
