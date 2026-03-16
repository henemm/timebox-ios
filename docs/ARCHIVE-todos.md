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
