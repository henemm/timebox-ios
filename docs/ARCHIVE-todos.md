# Archiv — Erledigte Todos

> Hierher verschoben aus `ACTIVE-todos.md` am 2026-03-12.
> Aktive Items: siehe `docs/ACTIVE-todos.md`

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
