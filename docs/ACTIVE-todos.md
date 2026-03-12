# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!

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
  - [ ] `MonsterCoach.swift` — LOESCHEN (XP-Dict, Evolution-Levels, Persistence)
  - [ ] `MonsterStatusView.swift` — LOESCHEN (XP-Balken, Evolution-Anzeige)
  - [ ] `MonsterCoachTests.swift` — LOESCHEN (Tests fuer XP/Evolution)
  - [ ] `MonsterCoachUITests.swift` — LOESCHEN (UI Tests fuer MonsterStatusView)
  - [ ] `DailyReviewView.swift` — `monsterCoach` State + `MonsterStatusView` Block entfernen
  - [ ] `project.pbxproj` — Geloeschte Files aus Build-Targets entfernen
- **Was WEG muss (Docs):**
  - [ ] `ACTIVE-todos.md` — Phase 1 Eintrag korrigieren (als ENTFERNT markieren)
  - [ ] `monster-coach.md` User Story — Feature-Tabelle aktualisieren (Monster Evolution → entfernt)
  - [ ] `MEMORY.md` — Falls XP/Evolution erwaehnt wird, aktualisieren
- **Dateien:** 4 loeschen + 2 modifizieren + 3 Docs aktualisieren
- **Tests:** Discipline-Tests aus MonsterCoachTests.swift in eigene Datei extrahieren (6 Tests behalten)

---

## ENTFERNT: Feature — Monster Coach Phase 1 (Foundation) ⚠️ XP/Evolution WIDERSPRICHT User Story

- **Problem:** Hat XP-Punkte, Evolution-Levels (Ei→Meister) und Gamification gebaut — obwohl die User Story explizit sagt: "Keine XP, Levels, Achievements"
- **Was entfernt wird:** MonsterCoach Model, MonsterStatusView, zugehoerige Tests
- **Was bleibt:** Discipline Enum (Task-Klassifizierung), Coach-Modus Toggle, Settings-Integration
- **Urspruenglicher Umfang:**
  - `Discipline` Enum (4 Disziplinen) ← BLEIBT
  - `MonsterCoach` Model (XP, Evolution) ← WIRD ENTFERNT
  - `MonsterStatusView` (XP-Balken) ← WIRD ENTFERNT
  - Coach-Modus Toggle in Settings ← BLEIBT

---

## BACKLOG: Feature — Monster Coach Phase 3 "Der Tagesbogen"

- **User Story:** `docs/project/stories/monster-coach.md` — Sections "Der komplette Tagesbogen", "Nach der Morgen-Auswahl", "Smart Notifications", "Der Abend-Spiegel", "Apple Intelligence Integration"
- **Vision:** Nach der Morgen-Intention passiert bisher NICHTS. Phase 3 schliesst die Luecke: Morgen → Tag → Abend als durchgaengiges Erlebnis.

**Was Phase 1+2 gebaut hat (Grundlage fuer Phase 3):**
- `Sources/Models/DailyIntention.swift` — Model mit `IntentionOption` Enum (survival, fokus, bhag, balance, growth, connection)
- `Sources/Views/MorningIntentionView.swift` — Selection Grid (6 Chips) + kompakte Zusammenfassung
- `Sources/Views/DailyReviewView.swift` — Review-Tab, zeigt "Mein Tag" bei aktivem Coach
- `Sources/Models/Discipline.swift` — Task-Disziplin Enum (konsequenz, ausdauer, mut, fokus)
- Intention-Persistenz: `UserDefaults` Key `dailyIntention_YYYY-MM-DD`
- Coach-Toggle: `AppSettings.coachModeEnabled` (UserDefaults)
- Tab-Steuerung: `MainTabView` mit `@State var selectedTab` (programmatischer Tab-Wechsel moeglich)

### Phase 3a: Intention-basierter Backlog-Filter (Must) — ERLEDIGT ✓
- Nach Morgen-Auswahl → App wechselt automatisch zum Backlog-Tab mit aktivem Filter-Chip
- 6 Filter-Mappings implementiert (Survival=kein Filter, Fokus=NextUp, BHAG=importance 3 oder rescheduleCount≥2, Balance=alle Tasks, Growth=category "learning", Connection=category "giving_back")
- Filter-Chips sichtbar als Capsule-Buttons, per Tap einzeln abschaltbar
- Multi-Select: UNION-Logik, Survival ueberstimmt alles
- **Geaenderte Dateien:** `DailyIntention.swift` (matchesFilter), `BacklogView.swift` (Filter-UI + Logik), `MorningIntentionView.swift` (AppStorage-Writes), `FocusBloxApp.swift` (Tab-Switch)
- **Tests:** 10 Unit Tests + 6 UI Tests — alle GRUEN
- **Spec:** `openspec/changes/monster-coach-phase3a/proposal.md`

### Phase 3b: Smart Notifications — Tagesbegleitung (Must) — ERLEDIGT ✓
- Notifications feuern NUR bei Luecken zwischen Intention und Handlung
- Stille-Regel: Sobald Intention erfuellt → keine weiteren Notifications (Foreground-Check)
- Survival = absolute Ruhe (keine Nudges, niemals)
- Settings: An/Aus Toggle, Max pro Tag (1/2/3 Segmented Picker), Zeitfenster (Von/Bis DatePicker)
- Neuer `IntentionEvaluationService` (stateless, pure functions) — wird auch von Phase 3c gebraucht
- 7 Gap-Typen mit deutschen Nudge-Texten
- **Geaenderte Dateien:** IntentionEvaluationService.swift (NEU), NotificationService.swift, AppSettings.swift, SettingsView.swift, MorningIntentionView.swift, FocusBloxApp.swift
- **Tests:** 27 Unit Tests + 5 UI Tests — alle GRUEN
- **Spec:** `openspec/changes/monster-coach-phase3b/proposal.md`

### Phase 3c: Abend-Spiegel mit automatischer Auswertung (Must)
- Karte im Review-Tab (`DailyReviewView`) ab 18 Uhr, oberhalb der bestehenden Stats
- Automatische Bewertung aus Task-Daten — kein User-Input noetig
- 3 Stufen pro Intention mit konkreten Kriterien (Details: User Story Section "Der Abend-Spiegel" → "Automatische Auswertung"):
  - z.B. Fokus: Block-Completion ≥70% = erfuellt, 40-69% = teilweise, <40% = nicht erfuellt
  - z.B. Balance: Tasks in ≥3 Kategorien = erfuellt, 2 = teilweise, ≤1 = nicht erfuellt
- Stimmungs-Farbe: erfuellt=warm+Intentionsfarbe, teilweise=gedaempft, nicht erfuellt=grau-blau
- Fallback-Templates fuer Geraete ohne Apple Intelligence (statische Sprueche pro Intention+Stufe)
- **Dateien (geschaetzt):** EveningReflectionCard (NEU, SwiftUI View), IntentionEvaluationService (NEU, berechnet Erfuellungsgrad), DailyReviewView (Card einbetten)

### Phase 3d: Foundation Models Abend-Text (Must)
- On-Device AI generiert persoenlichen Text der konkrete Tasks beim Namen nennt
- Prompt-Input: Intention, erledigte Task-Titel, Erfuellungsgrad, Tageskontext (Blocks, Kategorien)
- Fallback auf handgeschriebene Template-Sprueche wenn Foundation Models nicht verfuegbar
- **Abhaengigkeit:** Apple Intelligence / Foundation Models Framework (iOS 26+), Phase 3c (EveningReflectionCard als Host)
- **Dateien (geschaetzt):** MonsterVoiceService (NEU, Foundation Models Prompt), EveningReflectionCard (Text-Integration)

### Phase 3e: Abend Push-Notification (Should)
- Optional, konfigurierbar (Default: 20:00 Uhr)
- Nur wenn `coachModeEnabled == true` UND heutige Intention gesetzt
- **Dateien (geschaetzt):** NotificationService (neuer Notification-Typ)

### Phase 3f: Siri Integration / App Intents (Should)
- "Hey Siri, wie war mein Tag?" → liest Abend-Spiegel Auswertung vor
- "Setz meine Intention auf Fokus" → setzt DailyIntention
- **Abhaengigkeit:** Phase 3c (IntentionEvaluationService fuer "wie war mein Tag")
- **Dateien (geschaetzt):** AppIntents (NEU)

### Empfohlene Reihenfolge
1. **3a** (Backlog-Filter) — baut direkt auf MorningIntentionView auf, kein neuer Service noetig
2. **3c** (Abend-Spiegel) — Kern-Feature, erstellt IntentionEvaluationService den 3b+3d+3f brauchen
3. **3b** (Smart Notifications) — nutzt IntentionEvaluationService aus 3c
4. **3d** (Foundation Models) — Enhancement fuer 3c, eigener Service
5. **3e** (Abend Push) — kleiner Zusatz zu NotificationService
6. **3f** (Siri) — eigenstaendig, kann jederzeit nach 3c

---

## ERLEDIGT: Feature — Task-Abhaengigkeiten (Blocker)

- **Anforderung:** Tasks koennen eine Finish-to-Start Abhaengigkeit bekommen. Task B kann erst bearbeitet werden wenn Task A (Blocker) erledigt ist. Blockierte Tasks werden eingerueckt + dimmed dargestellt. Blocker-Tasks bekommen Ranking-Boost.
- **Phase 1 (Daten-Layer + Scoring) — ERLEDIGT:**
  - `LocalTask.blockerTaskID: String?` — neues Property fuer Abhaengigkeit
  - `PlanItem.blockerTaskID` + `isBlocked` computed property
  - `TaskPriorityScoringService`: +3 Score pro abhaengigem Task (max +9)
  - 9 Unit Tests (alle GREEN), keine Regression
- **Phase 2 (iOS View-Aenderungen) — ERLEDIGT:**
  - BacklogView: Grouping (blockierte Tasks unter Blocker, keine Swipe-Actions)
  - BacklogRow: isBlocked → Einrueckung (24pt) + Dimming (0.5) + Lock-Icon + Checkbox disabled
  - PlanItem: topLevelTasks + dependents(of:) Grouping-Helpers
  - 3 neue Unit Tests (12 gesamt, alle GREEN)
- **Phase 2b (macOS View-Aenderungen) — ERLEDIGT:**
  - MacBacklogRow: isBlocked → Dimming (0.5) + Indent (20pt) + Lock-Icon + Checkbox disabled
  - ContentView: Grouping (blockierte Tasks unter Blocker, keine Swipe-Actions)
  - blockedDependents(of:) Helper, regularFilteredTasks/overdueTasks filtern blockerTaskID==nil
  - 2 Dateien, +27/-11 LoC, alle 12 Tests GREEN
- **Phase 3 (Erstellungs-UI) — ERLEDIGT:**
  - iOS TaskFormSheet: "Abhaengig von..." Picker (Menu-Style, filtert Self + zirkulaere Abhaengigkeiten)
  - macOS TaskInspector: "Abhaengigkeit" Sektion mit Picker + Binding
  - LocalTaskSource.createTask: blockerTaskID Parameter hinzugefuegt
  - 2 neue Unit Tests (14 gesamt, alle GREEN)
- **Spec:** `openspec/changes/sub-tasks/proposal.md`
- **BEKANNTE BUGS (aus kritischer Analyse):**

### BUG-DEP-1: Blocker erledigt → Dependents verschwinden — ERLEDIGT
- **Fix:** `SyncEngine.freeDependents(of:)` in `completeTask()` — setzt `blockerTaskID = nil` auf allen Dependents
- **Test:** `test_completeTask_clearsDependentsBlockerTaskID` GREEN

### BUG-DEP-2: Blocker geloescht → Dependents permanent gelockt — ERLEDIGT
- **Fix:** `SyncEngine.freeDependents(of:)` in `deleteTask()` vor dem Delete
- **Test:** `test_deleteTask_clearsDependentsBlockerTaskID` GREEN

### BUG-DEP-3: Ranking-Boost ist toter Code — ERLEDIGT
- **Fix:** `PlanItem.dependentCount` Feld + `populateDependentCounts()` auf Array-Extension. iOS: BacklogView ruft nach jedem sync() auf. macOS: ContentView.scoreFor() + MacBacklogRow nutzen `dependentCount(for:)` Helper.
- **Test:** `test_populateDependentCounts_boostsPriorityScore` GREEN

### BUG-DEP-4: Blockierte Tasks nicht vor Aktionen geschuetzt — ERLEDIGT
- **Fix:** 4 Guards implementiert:
  1. macOS TaskInspector: "Erledigt" + "Next Up" Chips `.disabled()` wenn blockiert
  2. iOS + macOS: `nextUpTasks` Filter schliesst blockierte Tasks aus (`!isBlocked` / `blockerTaskID == nil`)
  3. macOS Context Menu: `markTasksCompleted()` + `addToNextUp()` pruefen `blockerTaskID == nil`
  4. iOS FocusBlock-Zuweisung: `unscheduledTasks` Filter schliesst blockierte Tasks aus
- **Dateien:** TaskInspector.swift, BacklogView.swift, ContentView.swift, TaskAssignmentView.swift, PlanItem.swift
- **Tests:** 4 neue Unit Tests (22 gesamt), alle GREEN

### BUG-DEP-4b: Siri/Shortcuts + Notification koennen blockierte Tasks erledigen — ERLEDIGT
- **Symptom:** CompleteTaskIntent (Siri), Notification-Actions, FocusBlock-UI hatten keinen blockerTaskID-Guard. Zusaetzlich fehlte freeDependents in allen Pfaden ausser SyncEngine.
- **Fix:** Defense-in-Depth: Guard in SyncEngine.completeTask() (zentral), CompleteTaskIntent + NotificationActionDelegate durch SyncEngine geleitet, WatchNotificationDelegate + FocusBlockActionService mit inline Guard + freeDependents
- **Dateien:** SyncEngine.swift, CompleteTaskIntent.swift, NotificationActionDelegate.swift, WatchNotificationDelegate.swift, FocusBlockActionService.swift, WatchLocalTask.swift (blockerTaskID hinzugefuegt)
- **Tests:** 4 neue Unit Tests (30 gesamt), alle GREEN

### BUG-DEP-5: 3-Wege zirkulaere Abhaengigkeiten moeglich — ERLEDIGT
- **Fix:** `LocalTask.wouldCreateCycle()` prueft transitive Blocker-Kette. Beide Picker (iOS TaskFormSheet + macOS TaskInspector) nutzen diese Methode statt 1-Level Check.
- **Dateien:** LocalTask.swift, TaskInspector.swift, TaskFormSheet.swift
- **Tests:** 4 neue Unit Tests (26 gesamt), alle GREEN

### BUG-DEP-6: Swipe-Gesten in iOS Backlog kaputt — ERLEDIGT
- **Symptom:** Swipe-Gesten funktionierten nicht mehr in allen iOS Backlog-Views (Priority, Tier, Recent, Overdue)
- **Root Cause:** `ForEach(blockedTasks)` stand zwischen BacklogRow und .swipeActions — Modifier haengen in @ViewBuilder am letzten Ausdruck
- **Fix:** Modifier-Kette direkt an BacklogRow, ForEach danach. UI-Test-Richtungen korrigiert (swipeLeft/Right waren vertauscht).
- **Dateien:** `Sources/Views/BacklogView.swift`, `FocusBloxUITests/BacklogSwipeActionsUITests.swift`
- **Tests:** 4 UI Tests GREEN

### BUG-DEP-7: Abhaengigkeit wird beim Bearbeiten nicht gespeichert — ERLEDIGT
- **Symptom:** Einrueckung + Dimming nicht sichtbar im Backlog (beide Plattformen)
- **Root Cause:** `TaskFormSheet.swift:518` nutzte `#Predicate { $0.id == editID }` mit **computed property** `id` statt **stored property** `uuid`. SwiftData-Predicate konnte den Task nicht finden, `try?` schluckte den Fehler, `blockerTaskID` wurde nie gespeichert. Einzige Stelle im gesamten Projekt die `$0.id` statt `$0.uuid` im Predicate nutzte.
- **Fix:** Predicate auf `$0.uuid == editUUID` geaendert (konsistent mit 10+ anderen Stellen im Projekt)
- **Dateien:** `Sources/Views/TaskFormSheet.swift` (1 Stelle, 3 Zeilen)
- **Tests:** Regression-Test in `TaskDependencyTests` (30 Tests GREEN)

---

## ERLEDIGT: Bug — Recurring Tasks erscheinen nach Loeschen wieder ("Zombie-Schleife")

- **Symptom:** Wiederkehrender Task "Zehnagel" erscheint nach Loeschen bei jedem App-Start wieder
- **Root Cause:** `repairOrphanedRecurringSeries()` erstellt neue Instanzen aus erledigten Tasks, ohne zu pruefen ob die Serie bewusst beendet wurde (Template geloescht)
- **Fix:** Template-Check in `repairOrphanedRecurringSeries()` — nur reparieren wenn Template fuer die Serie noch existiert. Kein Template = Serie beendet = nicht reparieren.
- **Dateien:** `Sources/Services/RecurrenceService.swift` (2 Zeilen geaendert)
- **Tests:** 4 Repair-Tests GREEN (1 neuer Zombie-Prevention-Test)
- **Blast Radius:** Betrifft ALLE recurring Tasks, nicht nur "Zehnagel". Fix gilt fuer iOS + macOS (Shared Code).

---

## ERLEDIGT: Bug — AI Title Improvement entfernt Doppelpunkt-Prefixe

- **Symptom:** Task-Titel "Lohnsteuererklaerung: Rechnungsuebersicht erstellen" wird nach Erstellung zu "Rechnungsuebersicht erstellen" — das Prefix vor dem Doppelpunkt verschwindet.
- **Root Cause:** `TaskTitleEngine.performImprovement()` sendet den Titel an Apple Intelligence. Die AI interpretiert "Lohnsteuererklaerung:" als entfernbares Prefix (wie "Re:", "Fwd:") und gibt nur den Action-Teil zurueck. Der Code uebernimmt das AI-Ergebnis ohne Pruefung.
- **Fix:** Dreifach-Schutz:
  1. **Safety Guard** `shouldAcceptImprovedTitle()`: Lehnt AI-Output ab wenn >30% des Titels entfernt ohne bekannte Muster (E-Mail-Artefakte, Urgency, Floskeln)
  2. **AI-Instruktionen verschaerft**: Explizite Regel "Text vor Doppelpunkten ist IMMER Teil des Titels" + Negativbeispiele
  3. **@Guide verschaerft**: "NEVER remove text before colons unless email artifact"
- **Aenderungen:**
  - `Sources/Services/TaskTitleEngine.swift`: `shouldAcceptImprovedTitle()` (+22 LoC), Guard in `performImprovement()`, AI-Prompt-Updates
- **Tests:** 7 neue Tests (alle GREEN), 34 gesamt
- **Beide Plattformen:** Fix in Shared-Code (Sources/), wirkt auf iOS + macOS

---

## ERLEDIGT: Feature — Deferred Task Completion (3-Sekunden Delay)

- **Anforderung:** Wenn Tasks abgehakt werden (beliebige Liste, beliebiges OS) muss zuerst der gefuellte Punkt dargestellt werden und erst danach verschwindet der Task. Delay von ca. 3 Sekunden, aehnlich wie bei der Umsortierung.
- **Loesung:** `DeferredCompletionController` — neuer `@Observable` Service mit per-Task Timern. Checkbox wird sofort gruen gefuellt, Titel bekommt Durchstreichung + 50% Opacity. Nach 3 Sekunden wird `SyncEngine.completeTask()` aufgerufen und der Task verschwindet animiert.
- **Design-Entscheidung:** Delayed Data Write (isCompleted wird erst nach 3s gesetzt) statt sofortigem Write + UI-Overlay. Dadurch zero Blast Radius auf CloudKit Sync, @Query Predicates, Recurring Task Generation, Counter und Undo Service.
- **Aenderungen:**
  - `Sources/Services/DeferredCompletionController.swift` (NEU, 92 LoC): Shared Service
  - `Sources/Views/BacklogView.swift`: Environment + scheduleCompletion statt direktem completeTask
  - `Sources/Views/BacklogRow.swift`: isCompletionPending Visual State
  - `FocusBloxMac/ContentView.swift`: Environment + scheduleCompletion + Batch-Completion
  - `FocusBloxMac/MacBacklogRow.swift`: isCompletionPending Visual State
  - `Sources/FocusBloxApp.swift`: @State + .environment() + scenePhase Background Flush
  - `FocusBloxMac/FocusBloxMacApp.swift`: @State + .environment() + scenePhase Background Flush
- **Tests:** 7 Unit Tests + 7 UI Tests gruen (DeferredCompletionControllerTests + DeferredCompletionUITests + BacklogCompletionUITests)
- **Beide Plattformen:** iOS + macOS

---

## ERLEDIGT: Bug — macOS UI Tests leaken Mock-Daten in echte Datenbank

- **Symptom:** Nach macOS Tests tauchen zahlreiche Mock-Tasks ("UI Test Task XXXX", "Badge Test Task XXXX" etc.) in der echten App-Datenbank auf und werden nicht geloescht.
- **Root Cause:** 5 macOS UI Test-Dateien starteten die App OHNE `-UITesting` Flag. Ohne dieses Flag nutzt die App den persistenten Store statt In-Memory. Tasks die waehrend der Tests via UI erstellt werden, bleiben permanent gespeichert.
- **Fix:**
  1. `-UITesting` und `-MockData` zu allen 5 betroffenen Dateien hinzugefuegt
  2. Einmalige Cleanup-Funktion `cleanupLeakedTestData()` loescht bestehende Test-Tasks beim naechsten App-Start
- **Betroffene Dateien:**
  - `FocusBloxMacUITests/FocusBloxMacUITests.swift` (Launch-Args gefixt)
  - `FocusBloxMacUITests/MacSyncUIAlignmentUITests.swift` (Launch-Args gefixt)
  - `FocusBloxMacUITests/MacBacklogTagsUITests.swift` (falscher `-UITestMode` → `-UITesting`)
  - `FocusBloxMacUITests/RemindersSyncUITests.swift` (Launch-Args gefixt)
  - `FocusBloxMacUITests/FocusBloxMacUITestsLaunchTests.swift` (Launch-Args hinzugefuegt)
  - `FocusBloxMac/FocusBloxMacApp.swift` (Cleanup-Funktion)

---

## ERLEDIGT: Bug 83 — Focus View Task Count Widerspruch (iOS + macOS)

- **Symptom:** Focus View zeigt "2/3 Tasks" im Header aber "Alle Tasks erledigt!" im Content gleichzeitig
- **Root Cause:** Counter-Denominator nutzte `block.taskIDs.count` (EventKit, inkl. verwaister IDs), waehrend "Alle erledigt" Check `tasksForBlock()` nutzte (SwiftData, nur existierende Tasks). Wenn ein Task geloescht wird aber die ID in EventKit bleibt, divergieren die beiden Anzeigen.
- **Fix:** Neue Helper `resolvedTaskCount(knownTaskIDs:)` / `resolvedCompletedCount(knownTaskIDs:)` auf FocusBlock. Alle Counter nutzen jetzt nur noch existierende Tasks.
- **Aenderungen:**
  - `Sources/Models/FocusBlock.swift`: 2 neue Helper-Methoden (+15 LoC)
  - `Sources/Views/FocusLiveView.swift`: Counter + Notification nutzen resolved Counts
  - `FocusBloxMac/MacFocusView.swift`: Counter nutzt resolved Counts
  - `Sources/Services/LiveActivityManager.swift`: `knownTaskIDs` Parameter fuer Live Activity
- **Tests:** 7 Unit Tests gruen (FocusBlockTaskCountTests)
- **Beide Plattformen:** iOS + macOS gefixt

---

## ERLEDIGT: Bug — Ueberlappende Timeline-Events falsch dargestellt (iOS + macOS)

- **Symptom:** Langes Event (z.B. 08:00-12:00) + mehrere kuerzere Events → jedes Event bekommt eigene Spalte (1/4 Breite statt 1/2). Events die sich nicht direkt ueberlappen werden unnoetig nebeneinander gezeigt.
- **Root Cause:** Sequentielle Spalten-Zuordnung (`column = index`) statt Greedy Column Packing. Alle Events in einer Overlap-Gruppe bekamen jeweils eine eigene Spalte.
- **Fix:** `TimelineItem.assignColumns()` — Greedy-Algorithmus der Events in die erste freie Spalte packt. Events die sich zeitlich nicht ueberlappen teilen sich eine Spalte.
- **Aenderungen:**
  - `Sources/Models/TimelineItem.swift`: Neue `assignColumns()` Methode (+38 LoC)
  - `Sources/Views/BlockPlanningView.swift`: `positionedItems` nutzt `assignColumns()`
  - `FocusBloxMac/MacTimelineView.swift`: Gleicher Fix
  - `FocusBloxTests/TimelineCollisionTests.swift`: 6 neue Tests fuer Column-Assignment
- **Tests:** 20 Unit Tests + 2 UI Tests gruen
  - UI: `testOverlappingEventAndBlockAreSideBySide` (Breite < 70%, verschiedene X-Pos)
  - UI: `testNonOverlappingBlockIsFullWidth` (Breite > 80%)
- **Beide Plattformen:** iOS + macOS gefixt

---

## ERLEDIGT: Bug — Tasks springen bei Wichtigkeit/Dringlichkeit/Dauer-Aenderung (iOS + macOS)

- **Symptom:** Badge-Tap auf Wichtigkeit/Dringlichkeit → Task springt sofort an neue Position. 3 vorherige Fix-Versuche gescheitert.
- **Root Cause:** `updateImportance()` ersetzt PlanItem sofort mit neuem `priorityScore`. Priority-View sortiert bei jedem Render nach Score → sofortiger Sprung. `pendingResortIDs` kontrollierte nur den orangenen Rand, nicht die Sortierung.
- **Fix:** `frozenSortSnapshot` friert Priority-Scores aller Tasks ein BEVOR der PlanItem ersetzt wird. View sortiert nach frozen Scores → Task bleibt an Position. Nach 3s wird Snapshot mit Animation geloescht → Task gleitet sanft.
- **Aenderungen:**
  - `Sources/Views/BacklogView.swift`: frozenSortSnapshot State, freezeSortOrder(), effectivePriorityScore/Tier, sofortiger PlanItem-Replace fuer Duration
  - `FocusBloxMac/ContentView.swift`: displaySnapshot durch frozenSortSnapshot ersetzt, freezeSortOrder() vor jeder Wert-Aenderung
  - `FocusBloxUITests/TaskJumpingBugProofTest.swift`: 5 UI Tests (Importance/Urgency/Duration kein Sprung, Label sofort sichtbar, Reihenfolge stabil)
- **Tests:** 5 UI Tests gruen
- **Beide Plattformen:** iOS + macOS gefixt (macOS Nachbesserung: scoreFor() nutzte frozen Scores nicht)

---

## ERLEDIGT: Bug 90 — Watch Notification Actions wirkungslos (NextUp/Postpone/Complete)

- **Symptom:** User klickt "NextUp" in Watch-Notification → Task erscheint auf keiner Plattform in NextUp. iOS/macOS zeigen unterschiedliche NextUp-Tasks (Timing-Problem, loest sich nach Refresh).
- **Root Cause (1. Fix, Commit 5202817):** Watch App hatte keinen `UNUserNotificationCenterDelegate` registriert.
- **Root Cause (2. Fix, Bug 90):** Delegate wurde in `.onAppear` registriert statt in `init()`. Wenn watchOS die App fuer eine Notification-Action startet, wird `didReceive` aufgerufen BEVOR SwiftUI die View rendert → Delegate war nil → Action still verworfen. Gleicher Bug auf iOS (funktionierte nur zufaellig wegen schnellerem App-Start).
- **Fix (Symptom A):** Delegate-Registrierung von `.onAppear` nach `init()` verschoben (Watch + iOS). Error-Logging in WatchNotificationDelegate (statt try? stilles Schlucken). Postpone-Test gefixt (falscher Action-Identifier).
- **Fix (Symptom B):** macOS ContentView: `@Query` durch `@State` + manuelles `refreshTasks()` ersetzt. `@Query` aktualisiert sich nicht zuverlaessig nach CloudKit-Imports. Dasselbe Pattern wie iOS BacklogView, wo CloudKit-Sync nachweislich funktioniert.
- **Blast Radius:** Alle Watch-Notification-Actions + iOS-Notification-Actions + macOS CloudKit-Sync betroffen
- **Tests:** 8 Unit Tests gruen (WatchNotificationDelegateTests), Postpone-Test korrigiert
- **Dateien:** FocusBloxWatchApp.swift, WatchNotificationDelegate.swift, FocusBloxApp.swift, WatchNotificationDelegateTests.swift, ContentView.swift (macOS)

---

## ERLEDIGT: Bug — Watch-Tasks ohne Enrichment (? ? (?) ? im Backlog)

- **Symptom:** Via Apple Watch erstellte Tasks zeigen auf iPhone `? ? (?) ?` und Score 0
- **Root Cause:** Watch nutzt `modelContext.insert()` direkt — umgeht `LocalTaskSource.createTask()` und damit die gesamte Enrichment-Pipeline. Kein Code-Pfad triggerte Enrichment fuer remote/synced Tasks.
- **Fix:** `enrichAllTbdTasks()` wird jetzt automatisch aufgerufen bei:
  - App-Start (`FocusBloxApp.onAppear` + `FocusBloxMacApp.onAppear`)
  - CloudKit-Sync (`BacklogView.refreshLocalTasks()`)
- **Aenderungen:**
  - `Sources/FocusBloxApp.swift`: +2 Zeilen (enrichAllTbdTasks bei App-Start)
  - `Sources/Views/BacklogView.swift`: +6 Zeilen (enrichAllTbdTasks nach Sync)
  - `FocusBloxMac/FocusBloxMacApp.swift`: +4 Zeilen (Title+Enrichment bei App-Start)
  - `FocusBloxMac/ContentView.swift`: +3 Zeilen (enrichAllTbdTasks nach CloudKit-Sync)
- **Tests:** 5 Unit Tests (WatchEnrichmentGapTests) — alle gruen
- **Blast Radius:** Fix gilt auch fuer Siri, Share Extension, Reminders Import

---

## ERLEDIGT: Feature #29 — Badge-Zahl (Overdue) + Interaktive Frist-Notifications

- **Ziel:** App-Icon Badge zeigt Anzahl ueberfaelliger Tasks, Frist-Notifications bieten 3 Buttons (NextUp, Verschieben +1 Tag, Erledigt)
- **Aenderungen:**
  - `Sources/Services/NotificationService.swift`: Category-Registration, userInfo an Due-Date-Notifs, Badge-Update (iOS only)
  - `Sources/Services/NotificationActionDelegate.swift`: Shared-Code fuer iOS + macOS (extrahiert aus FocusBloxApp.swift)
  - `Sources/FocusBloxApp.swift`: Badge bei Foreground + Remote-Change
  - `FocusBloxMac/FocusBloxMacApp.swift`: NotificationActionDelegate (ohne Badge)
- **Nachtrag:** macOS Build war kaputt weil NotificationActionDelegate nur im iOS-Target definiert war. Extrahiert nach `Sources/Services/` als Shared-Code.
- **Tests:** 5 Tests gruen (3 Unit + 2 UI), keine neuen Regressionen
- **Spec:** `docs/specs/features/badge-overdue-notifications.md`

---

## ERLEDIGT: Feature — Watch Quick Capture Complication

- **Ziel:** 1-Tap vom Watchface zur Diktat-Eingabe (kein App-Oeffnen noetig)
- **User Story:** `docs/project/stories/watch-quick-capture.md`
- **Aenderungen:**
  - `FocusBloxWatchWidgets/QuickCaptureComplication.swift`: WidgetKit Complication (.accessoryCircular, StaticConfiguration, .never refresh)
  - `FocusBloxWatchWidgets/FocusBloxWatchWidgetsBundle.swift`: @main WidgetBundle
  - `FocusBloxWatchWidgets/FocusBloxWatchWidgets.entitlements`: App Group
  - `FocusBloxWatch Watch App/ContentView.swift`: .onOpenURL Deep-Link Handler (focusblox://voice-capture)
  - `FocusBlox.xcodeproj/project.pbxproj`: Neues Target FocusBloxWatchWidgetsExtension
- **Tests:** 27 Watch-Tests gruen (21 Unit + 6 UI). 2 Build-Artifact-Tests pruefen dass .appex in Watch App eingebettet ist.
- **Spec:** `docs/specs/features/watch-complication.md`
- **Naechste Schritte (Backlog):** Siri Shortcut Integration

---

## ERLEDIGT: Feature — Watch Quick Capture In-App Flow vereinfacht

- **Ziel:** Watch-Task-Erfassung von 5 auf 2 Schritte reduzieren (App oeffnen → sprechen → fertig)
- **User Story:** `docs/project/stories/watch-quick-capture.md`
- **Aenderungen:**
  - `ContentView.swift`: Auto-Open Sheet bei App-Start, ConfirmationView-Flow entfernt
  - `VoiceInputSheet.swift`: Auto-Save Timer (1.5s), Haptik-Feedback, OK-Button entfernt
  - `ConfirmationView.swift`: Komplett geloescht (Haptik ersetzt den Screen)
- **Tests:** 4 UI Tests gruen (auto-open, no-OK-button, cancel-exists, no-confirmation)
- **Spec:** `docs/specs/features/watch-quick-capture-inapp.md`
- **Naechste Schritte (Backlog):** ~~Watch Complication~~ ERLEDIGT + Siri Shortcut Integration

---

## ERLEDIGT: Bug — Watch-Task erscheint nicht auf iPhone (Watch→iPhone Sync)

- **Symptom:** Task auf Apple Watch erstellt → erscheint NIE im iPhone-Backlog
- **Root Cause:** Zwei Probleme in der Watch-App:
  1. **Fehlende CloudKit-Entitlements:** Watch-Entitlements hatten nur App Group, keine `icloud-container-identifiers` oder `icloud-services` → ModelContainer-Init mit CloudKit konnte fehlschlagen → stiller Fallback auf `.cloudKitDatabase: .none` (kein Sync)
  2. **Fehlende Stored-Property-Defaults:** WatchLocalTask.swift hatte keine Default-Werte auf den gespeicherten Properties (z.B. `var isCompleted: Bool` statt `var isCompleted: Bool = false`). CloudKit erfordert Default-Werte fuer Schema-Evolution.
- **Fix (3 Dateien):**
  - `WatchLocalTask.swift`: 13 Stored-Property-Defaults hinzugefuegt (Paritaet mit iOS LocalTask)
  - `FocusBloxWatch Watch App.entitlements`: CloudKit-Entitlements hinzugefuegt (`icloud-container-identifiers` + `icloud-services`)
  - `FocusBloxWatchApp.swift`: Logging bei ModelContainer-Init (Erfolg/Fallback sichtbar in Console)
- **Tests:** 3 neue Tests (Entitlements + Logging), alle 19 Watch-Tests gruen
- **Hinweis:** Watch-App muss auf dem Geraet geloescht und neu installiert werden

---

## ERLEDIGT: Bug — Watch-App Crash auf Apple Watch Ultra 3

- **Symptom:** App laedt kurz und stuerzt dann ab auf echter Apple Watch Ultra 3. Simulator funktioniert.
- **Root Cause:** Schema-Mismatch zwischen iOS `LocalTask` und Watch `LocalTask`. iOS hatte 3 Felder (`recurrenceInterval`, `isTemplate`, `modifiedAt`) die dem Watch-Model fehlten. CloudKit synct iOS-Daten mit diesen Feldern → `ModelContainer`-Init schlaegt fehl → `fatalError` → Crash. Simulator hat keine CloudKit-Daten → kein Crash.
- **Fix:** 3 fehlende Felder in `WatchLocalTask.swift` ergaenzt (Properties + init)
- **Tests:** 4 neue Tests (3 Schema-Parity + 1 ModelContainer-Integration mit vollen iOS-Daten), alle 16 Watch-Tests gruen
- **Hinweis:** Watch-App muss auf dem Geraet geloescht und neu installiert werden (alter SwiftData-Store)

---

## ERLEDIGT: Feature — Unified Calendar View (Phase 1)

- **Ziel:** Zuordnen-Tab entfernen, Task-Zuweisung direkt im Block-Sheet
- **Aenderungen:**
  - `MainTabView.swift`: Zuordnen-Tab entfernt (5→4 Tabs)
  - `BlockPlanningView.swift`: assignTaskToBlock + removeTaskFromBlock mit SyncEngine, nextUpTasksNotInBlock, Gear-Icon statt Ellipsis
  - `FocusBlockTasksSheet.swift`: Next-Up-Sektion mit arrow.up.circle Button zum Zuweisen
- **Tests:** 8 UI Tests gruen (2 neue + 6 Regression), Build OK (iOS + macOS)
- **Spec:** `docs/specs/features/unified-calendar-view.md`

---

## ERLEDIGT: Bug 88 — Siri "Erstelle Task" verliert diktierten Text

- **Symptom:** User sagt "Erstelle Task in FocusBlox", diktiert Text, tippt "FocusBlox oeffnen" — App zeigt normalen Hauptbildschirm, kein QuickCapture, diktierter Text verloren
- **Root Cause:** `CreateTaskIntent.perform()` laeuft in einem Extension-Prozess und schreibt in App Group UserDefaults OHNE `synchronize()`. iOS beendet den Extension-Prozess sofort nach perform() — UserDefaults-Daten nur im RAM, nie auf Disk geschrieben. App-Prozess liest von Disk → leer.
- **Fix:** `defaults.synchronize()` nach UserDefaults-Writes in `CreateTaskIntent.swift` und `CCQuickAddIntents.swift`
- **Blast Radius:** Nur CreateTaskIntent betroffen (Siri "Erstelle Task"). Alle anderen Flows (CC, Snippet, Widget, Share) nutzen andere Mechanismen.
- **Tests:** 2 Unit Tests in QuickCaptureIntentTests (UserDefaults round-trip Verifikation)

---

## ERLEDIGT: Bug — Siri-Shortcuts nicht funktional + SiriTipView nicht persistent

- **Symptom:** Siri-Tipps erscheinen in der App (ContentView, SettingsView), Siri-Kommandos funktionieren nicht auf echtem Geraet, SiriTipView erscheint bei jedem App-Start neu
- **Root Cause:**
  1. `updateAppShortcutParameters()` wurde nie aufgerufen — Siri konnte die Shortcuts nicht indizieren
  2. SiriTipView-Dismissal nutzte `@State` statt `@AppStorage` — State ging bei App-Neustart verloren
- **Fix:**
  - `FocusBloxApp.swift`: `FocusBloxShortcuts.updateAppShortcutParameters()` beim App-Start aufrufen
  - `ContentView.swift`: `@State` → `@AppStorage("siriTipGetNextUpVisible")` fuer persistentes Dismissal
  - `SettingsView.swift`: `@State` → `@AppStorage("siriTipCompleteTaskVisible")` fuer persistentes Dismissal
- **Tests:** UI Test (SiriTipPersistenceUITests) — Dismissal persistiert nach App-Relaunch

---

## ERLEDIGT: Bug — Toolbar inkonsistent in BacklogView (iOS)

- **Symptom:** + Button fehlt auf echtem Geraet, Import-Button erscheint inkonsistent, "..." Overflow, Dropdown fehlt in Wiederkehrend-Mode
- **Root Cause:** SiriTipView (Commit ef8460b, nie angefordert) im Group-Container erzeugte TupleView + zu viele Toolbar-Items (4-5 statt 3) + zwei separate .toolbar Modifier
- **Fix:**
  - SiriTipView komplett entfernt (import AppIntents, @State showCreateTaskTip, SiriTipView)
  - Import-Button aus Toolbar entfernt (gehoert in Settings)
  - Toolbar konsolidiert: genau 3 Items (+, Dropdown, Gear) in einem einzigen .toolbar Block
  - .withSettingsToolbar() durch inline Gear-Button ersetzt
- **Betroffene Datei:** Sources/Views/BacklogView.swift
- **Tests:** UI Tests (BacklogToolbarConsistencyUITests) — 7 Tests, alle 5 View-Modes geprueft

---

## ERLEDIGT: Bug — Sync zwischen macOS und iOS langsam/nicht automatisch

- **Symptom:** Sync dauert sehr lange, Aenderungen (Tasks, NextUp, Kategorien) werden nicht automatisch gepusht/gepullt
- **Root Cause:** macOS hatte den Bug-38-Fix nie bekommen:
  1. Kein `scenePhase` Handler — App-Wechsel loeste keinen Sync aus
  2. Kein `remoteChangeCount` Observer in ContentView — Remote-Changes wurden ignoriert
  3. `@Query` sah stale ModelContext-Cache nach CloudKit-Import
  4. `checkForChanges()` in CloudKitSyncMonitor las ohne `save()` vor Fetch (stale Data)
- **Fix:**
  - `FocusBloxMacApp.swift`: `onChange(of: scenePhase)` mit `triggerSync()` + `pushToCloud()` (wie iOS)
  - `ContentView.swift`: `.onChange(of: cloudKitMonitor.remoteChangeCount)` mit 200ms Delay + `modelContext.save()` Cache-Invalidierung
  - `CloudKitSyncMonitor.swift`: `save()` vor `fetch()` in `checkForChanges()` (Bug 38 Pattern)
- **Tests:** 8 Unit Tests gruen (CloudKitSyncMonitorTests), Build OK (iOS + macOS)
- **Analyse:** `docs/artifacts/bug-sync-slow/analysis.md`

---

## ERLEDIGT: Bug — macOS Arithmetic Overflow in addToNextUp

- **Symptom:** Crash `Thread 1: Swift runtime failure: arithmetic overflow` beim Swipe → "Next Up" auf macOS
- **Root Cause:** macOS `addToNextUp()` machte `max() + 1` auf `nextUpSortOrder`, aber SyncEngine setzt `Int.max` als Sentinel → `Int.max + 1` = Overflow
- **Fix:** macOS `addToNextUp()` und `removeFromNextUp()` nutzen jetzt `SyncEngine.updateNextUp()` statt lokaler Logik — beseitigt Plattform-Divergenz (BACKLOG-001 teilweise)
- **Bonus:** `removeFromNextUp` raeumt jetzt auch `assignedFocusBlockID` auf (Bug 52 Regression-Schutz)
- **Tests:** 4 Unit Tests (NextUpOverflowTests), Build OK (iOS + macOS)

---

## ERLEDIGT: ITB-G macOS Build Fix

- Intent Donations in Shared-Services (SyncEngine, FocusBlockActionService) mit `#if !os(macOS)` guarded
- CompleteTaskIntent/TaskEntity existieren nur im iOS-Target
- Build: Erfolgreich (iOS + macOS)

---

## ERLEDIGT: TD-02 Paket 1 — Shared Badge Components (iOS + macOS)

- **Ziel:** 5 Badge-Views aus iOS BacklogRow + macOS MacBacklogRow in Shared-Code extrahieren (Code-Sharing statt Duplikation)
- **Shared Badges:** ImportanceBadge, UrgencyBadge, RecurrenceBadge, TagsBadge, PriorityScoreBadge
- **Nicht geteilt (by Design):** CategoryBadge + DurationBadge (iOS=Button, macOS=Menu — fundamentale UX-Differenz)
- **Aenderungen:**
  - `Sources/Views/Components/TaskBadges.swift`: NEU — 5 Shared Badge Views mit `#if os(iOS)/#else` Platform-Sizing (+199 LoC)
  - `Sources/Views/BacklogRow.swift`: Inline-Badges durch Shared Components ersetzt (-100 LoC netto)
  - `FocusBloxMac/MacBacklogRow.swift`: Inline-Badges durch Shared Components ersetzt (-80 LoC netto)
  - `FocusBlox.xcodeproj/project.pbxproj`: Neue Dateien in iOS + macOS Targets registriert
- **Tests:** 13 Unit Tests (TaskBadgesTests) + 4 UI Tests (SharedBadgesUITests), alle gruen
- **Spec:** `docs/specs/features/td-02-shared-badges.md`

---

## ERLEDIGT: TD-02 Paket 2 — Shared Sheet Components (iOS + macOS)

- **Ziel:** CreateFocusBlockSheet + EventCategorySheet aus Duplikat-Code in Shared-Code mit Platform-Branching
- **Aenderungen:**
  - `Sources/Views/Components/SharedSheets.swift`: NEU — 2 Shared Sheet Views mit `#if os(iOS)/#else` (+196 LoC)
  - `Sources/Views/BlockPlanningView.swift`: Sheets entfernt (jetzt in SharedSheets.swift) (-165 LoC)
  - `FocusBloxMac/MacPlanningView.swift`: MacCreateFocusBlockSheet + MacEventCategorySheet entfernt, Call-Sites nutzen Shared Sheets (-138 LoC)
  - `FocusBlox.xcodeproj/project.pbxproj`: SharedSheets.swift in iOS + macOS Targets registriert
- **Tests:** Build erfolgreich (iOS + macOS), Full Unit Suite gruen, keine Regressionen
- **Spec:** `docs/specs/features/td-02-shared-sheets.md`
---

## ERLEDIGT: TD-02 Paket 3 — Shared FocusBlockCardHeader (iOS + macOS)

- **Ziel:** Header der FocusBlockCard (Titel, Zeitraum, Dauer-Anzeige) in Shared View extrahieren
- **Aenderungen:**
  - `Sources/Views/Components/SharedSheets.swift`: FocusBlockCardHeader hinzugefuegt (+30 LoC)
  - `Sources/Views/TaskAssignmentView.swift`: Inline-Header durch Shared Component ersetzt (-15 LoC)
  - `FocusBloxMac/MacAssignView.swift`: Inline-Header durch Shared Component ersetzt (-12 LoC)
- **Tests:** Build erfolgreich (iOS + macOS), Full Unit Suite gruen
- **Spec:** `docs/specs/features/td-02-shared-header.md`

---

## ERLEDIGT: CTC-3 — macOS Share Extension

- **Was:** Share Extension fuer macOS (Safari, Mail, Notes etc.)
- **Scope:** Neues Target `FocusBloxMacShareExtension` mit 3 Dateien + pbxproj
- **Architektur:** NSViewController + NSHostingView, gleiche Shared-Logik (LocalTask, sourceURL, needsTitleImprovement)
- **Entitlements:** App Group + CloudKit (identisch zu iOS)
- **Build:** Erfolgreich (macOS + iOS)

---

## ERLEDIGT: Bug 62 — Share Extension Fixes

**Bug 62: Share Extension CloudKit Crash + API-Fixes**

- **Status:** ERLEDIGT
- **Fixes:**
  1. CloudKit Entitlements in Extension hinzugefuegt (iCloud Container + Services)
  2. MARKETING_VERSION 1.0 → 1.0.0 angeglichen (Debug + Release)
  3. NSItemProvider: Whitespace-Trimming + Max-Titel-Laenge (500 Zeichen)
  4. Fallback-Logik bei fehlendem App Group Container
- **Build:** Erfolgreich (iOS)

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

## Aufwand-Uebersicht (nur offene Items)

| # | Item | Prio | Kompl. | Tokens | Dateien | LoC |
|---|------|------|--------|--------|---------|-----|
| 0 | ~~Settings UX: Build-Info + Vorwarnungs-Labels~~ | ERLEDIGT | XS | ~10-15k | 5 | ~50 |
| 1 | ~~Einheitliche Symbole Tab-Bar/Sidebar~~ | ERLEDIGT | XS | — | — | — |
| 2 | ~~NextUp Wischgesten (Edit+Delete)~~ | ERLEDIGT | XS | ~15-20k | 3 | ~80 |
| 3 | ~~NextUp Long Press Vorschau~~ | ERLEDIGT | XS | ~15-20k | 3 | ~120 |
| 4 | ~~Generische Suche (iOS+macOS)~~ | ERLEDIGT | S | ~15-20k | 2-3 | ~25 |
| 4b | ~~List-Views Cleanup (ViewModes 9→5)~~ | ERLEDIGT | M | ~50-70k | 6 | ~-270 |
| 5 | ~~MAC-022 Spotlight Integration~~ | ERLEDIGT | S | ~15-25k | 4 | ~20 |
| 6 | ~~Recurring Tasks Phase 1B/2 (inkl. Sichtbarkeit + Edit/Delete Dialog)~~ | ERLEDIGT | M-L | ~60-100k | 5-6 | ~200 |
| 7 | ~~Kalender-App Deep Link (iOS+macOS)~~ | ERLEDIGT | S | ~10k | 6 | ~40 |
| 8 | ~~Push Notifications bei Frist~~ | ERLEDIGT | M | ~60-80k | 9 | ~180 |
| 9 | MAC-031 Focus Mode Integration | P3 | M | ~50-70k | 2-3 | ~100 |
| 10 | MAC-030 Shortcuts.app | P3 | L | ~60-80k | 2-3 | ~150 |
| 11 | Emotionales Aufladen (Report) | MITTEL | L | ~80-100k | 3-4 | ~200 |
| 12 | MAC-026 Enhanced Quick Capture | P2 | L | ~80-120k | 4 | ~200 |
| 13 | ~~MAC-020 Drag & Drop Planung~~ → siehe Bug 70 (iOS+macOS) | P2 | XL | ~100-150k | 3-4 | ~250 |
| 14 | MAC-032 NC Widget | P3 | XL | ~80-120k | neues Target | ~200 |
| 15 | ~~ITB-A: FocusBlockEntity (AppEntity)~~ | ERLEDIGT | S | ~30-40k | 2 | ~60 |
| 16 | ~~ITB-B: Smart Priority (AI-Enrichment + Hybrid-Scoring)~~ | ERLEDIGT | L | ~80-120k | 12 | ~250 |
| 17 | ITB-C: OrganizeMyDay Intent | MITTEL | XL | ~100-150k | 4-5 | ~250 |
| 18 | ~~ITB-D: Enhanced Liquid Glass (aktive Blocks)~~ | ERLEDIGT | S | ~20-30k | 2 | ~40 |
| 19 | ~~ITB-E: Share Extension~~ | ERLEDIGT (Bug 62 gefixt) | L | ~30k | 3 + Target | ~80 |
| 20 | ITB-F: CaptureContextIntent (Siri On-Screen) | WARTEND | M | ~40-60k | 3-4 | ~80 |
| 21 | ~~ITB-G: Proaktive System-Vorschlaege~~ | ERLEDIGT | M | ~40k | 12 | ~115 |
| 22 | ~~CTC-1: TaskTitleEngine (intelligente Titel-KI)~~ | ERLEDIGT | M | ~40-60k | 6 | ~210 |
| 23 | ~~CTC-2: Share Extension sourceURL~~ | ERLEDIGT | S | ~20-30k | 3 | ~79 |
| 24 | ~~CTC-3: macOS Share Extension~~ | ERLEDIGT | M | ~40k | neues Target | ~170 |
| 25 | ~~CTC-4: Clipboard → Task Flow~~ | ERLEDIGT | S | ~15-25k | 2 | ~50 |
| 26 | ~~CTC-5: Watch-Diktat Titel-Verbesserung~~ | ERLEDIGT | S | ~15-20k | 2 | ~6 |
| 27 | ~~CTC-1b: TaskTitleEngine — Konservativ + Metadaten-Extraktion~~ | ERLEDIGT | S | ~20-30k | 2 | ~60 |
| 28 | ~~CTC-6: Smart Task Interpretation + Similar-Task Learning~~ | ERLEDIGT | S | ~20k | 4 | ~70 |
| ~~29~~ | ~~Badge-Zahl (Overdue) + Interaktive Frist-Notifications~~ | ERLEDIGT | M | ~50-70k | 3-4 | ~150-200 |
| ~~Bug 63~~ | ~~Kategorie-Zuweisung bei wiederkehrenden Events~~ | ERLEDIGT | M | ~40k | 6 | ~100 |
| ~~Bug 64~~ | ~~Kategorie-Icon auf Kalender-Events zu klein~~ | ERLEDIGT | XS | ~5k | 1 | ~10 |
| ~~Bug 65~~ | ~~Listendarstellung iOS vs macOS divergiert~~ | ERLEDIGT | M | ~40k | 1 | ~80 |
| ~~Bug 66~~ | ~~macOS FocusBlock MenuBar + Sync-Deadlock~~ | ERLEDIGT | M | ~40k | 4 | ~100 |
| ~~Bug 67~~ | ~~Tab-Labels Deutsch→English~~ | ERLEDIGT | XS | ~5k | 5 | ~10 |
| ~~Bug 68~~ | ~~FocusBlock View-Umbau — Full-Screen Sheet~~ | ERLEDIGT | M | ~40-60k | 4 | ~100 |
| ~~Bug 69~~ | ~~FocusBlock Sync — EKEventStoreChangedNotification~~ | ERLEDIGT | M | ~40k | 5 | ~80 |
| ~~Bug 70~~ | ~~70a-d + 70c-2 Block Resize per Drag~~ | ERLEDIGT | M | ~40-60k | 2-3 | ~100 |
| ~~Bug 71~~ | ~~Urgency-Keywords nicht aus Titel entfernt~~ | ERLEDIGT | S | ~20k | 2 | ~40 |
| ~~Bug 72~~ | ~~macOS — FocusBlock Gear-Icon fehlt~~ | ERLEDIGT | XS | ~5k | 1 | ~12 |
| ~~Bug 74~~ | ~~Sheet dismiss nach Speichern (Create Task)~~ | ERLEDIGT | XS | ~5k | 1 | ~11 |
| Bug 73 | Tasks-Dialog ohne Prioritaets-Info | ERLEDIGT | S | ~5k | 1 | ~30 |
| Bug 75 | macOS App-Icon falsch | ERLEDIGT | XS | ~2k | 1 | ~10 |
| Bug 76 | macOS Task verschwindet nach Anlegen | ERLEDIGT | S | ~2k | 1 | ~10 |
| Bug 77 | macOS Orange Umrandung zu eng | ERLEDIGT | XS | ~2k | 1 | ~10 |
| ~~Bug 78~~ | ~~macOS Crash bei Swipe (SwiftData Fault)~~ | ERLEDIGT | M | ~30-40k | 2 | ~20 |
| ~~Bug 79~~ | ~~Kalender-Event-Badges deutsche Labels~~ | ERLEDIGT | XS | ~2k | 1 | ~5 |
| ~~Bug 80~~ | ~~Kalender-Kategorien iOS↔macOS Sync~~ | ERLEDIGT | S | ~15k | 3 | ~40 |
| 30 | ~~App Icon Liquid Glass (iOS 26) — Two Rings + Dot~~ | ERLEDIGT | M | ~40-60k | 4 | ~100 |
| ~~Bug 81~~ | ~~FocusBlock Task-Zuweisung verliert ersten Task~~ | ERLEDIGT | M | ~40k | 4 | ~290 |
| ~~Bug 82~~ | ~~Erledigte Tasks — Suche funktioniert nicht~~ | ERLEDIGT | XS | ~5k | 1 | ~10 |
| ~~Bug 87~~ | ~~QuickCapture Dialog schliesst nicht nach Speichern~~ | ERLEDIGT | XS | ~5k | 1 | ~15 |
| ~~Bug 88~~ | ~~macOS MenuBar Timer zeigt Block-Dauer statt Task-Dauer~~ | ERLEDIGT | S | ~10k | 3 | ~30 |
| ~~Bug 89~~ | ~~Kategorie-Aenderung erst nach Verschieben sichtbar (iOS)~~ | ERLEDIGT | XS | ~5k | 1 | ~10 |

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**Guenstigster Quick Win:** #10 Background Refresh (S)
**Kritisch:** keine offenen kritischen Bugs
**Teuerste Items:** #17 OrganizeMyDay (~150k), #14 NC Widget (~120k), #12 Enhanced Quick Capture (~120k)
**WARTEND (Apple-Abhaengigkeit):** #20 ITB-F — Developer-APIs verfuegbar, wartet auf Siri On-Screen Awareness (iOS 26.5/27)
**Zuletzt erledigt:** Bug 88 macOS MenuBar Timer zeigt Block-Dauer statt Task-Dauer (S)
**Naechstes:** (offen)

> **Dies ist das EINZIGE Backlog.** macOS-Features (MAC-xxx) stehen hier mit Verweis auf ihre Specs in `docs/specs/macos/`. Kein zweites Backlog.

---

## Bundles (thematische Gruppierung)

### Bundle A: Quick Wins (XS, eine Session)
- ~~Settings UX: Build-Info + Vorwarnungs-Labels~~ ERLEDIGT
- ~~Einheitliche Symbole Tab-Bar/Sidebar~~ ERLEDIGT (Symbole bereits identisch)
- ~~NextUp Wischgesten (Edit+Delete)~~ ERLEDIGT (iOS alle Views + macOS Trackpad-Swipe)
- ~~NextUp Long Press Vorschau~~ ERLEDIGT

### Bundle B: Backlog & Suche
- ~~Generische Suche (iOS+macOS)~~ ERLEDIGT
- ~~MAC-022 Spotlight Integration~~ ERLEDIGT

### Bundle C: Erinnerungen & Verknuepfungen
- ~~Push Notifications bei Frist~~ ERLEDIGT
- ~~Kalender-App Deep Link~~ ERLEDIGT
- ~~**#29 Badge-Zahl (Overdue) + Interaktive Frist-Notifications**~~ ERLEDIGT

### Bundle D: Erfolge feiern
- Emotionales Aufladen im Report

### Bundle E: macOS Native Experience (P2/P3)
- ~~MAC-020 Drag & Drop Planung~~ → Bug 70 (70a-d + 70c-2 KOMPLETT ERLEDIGT)
- MAC-026 Enhanced Quick Capture
- MAC-030 Shortcuts.app
- MAC-031 Focus Mode Integration
- MAC-032 NC Widget

### Bundle F: Recurring Tasks vervollstaendigen
- ~~Phase 1B/2 (macOS Badge, Siri, Delete-Dialog, Filter)~~ ERLEDIGT
- ~~Dedup-Logik (gleichzeitiges Completion auf 2 Geraeten)~~ ERLEDIGT
- ~~macOS-Divergenz: Zukunfts-Filter + Wiederkehrend-Sidebar~~ ERLEDIGT
- ~~Quick-Edit Recurrence-Params Fix~~ ERLEDIGT
- ~~Recurrence-Editing Phase 2: Intervalle + Eigene (z.B. "Jeden 3. Tag")~~ ERLEDIGT
- ~~Bug: Attribute-Badges in BacklogRow abgeschnitten (1-zeilig)~~ ERLEDIGT (FlowLayout)
- ~~Template-Architektur (Mutter/Kind): Mutterinstanz als Template, Kinder im Backlog~~ ERLEDIGT

### Bundle G: Intelligent Task Blox (Apple Intelligence + System-Integration)
**Empfohlene Reihenfolge:**
1. ~~ITB-A (FocusBlockEntity)~~ ERLEDIGT - Grundlage fuer Intents
2. ~~ITB-E (Share Extension)~~ ERLEDIGT (inkl. Bug 62 Fix)
3. ~~ITB-D (Liquid Glass)~~ ERLEDIGT - visuelles Polish (FocusGlowModifier iOS+macOS)
4. ~~ITB-B (Smart Priority)~~ ERLEDIGT - AI-Enrichment + deterministischer Score
5. ITB-F (CaptureContextIntent) - WARTEND auf Apple APIs
6. ITB-C (OrganizeMyDay) - Komplexer Intent (XL)
7. ~~ITB-G (Proaktive Vorschlaege)~~ ERLEDIGT — Intent Donations (6 Punkte), Spotlight Indexing, Widget Relevance, SiriTipViews (3 Stellen)

### Bundle H: Contextual Task Capture (Cross-Platform)
> User Story: `docs/project/stories/contextual-task-capture.md`

**Empfohlene Reihenfolge:**
1. ~~CTC-1 (TaskTitleEngine)~~ ERLEDIGT — Zentraler KI-Service fuer intelligente Titel (Foundation Models, Shared Code)
2. ~~CTC-2 (sourceURL)~~ ERLEDIGT — Share Extension speichert Quell-URL (Safari-Link etc.)
3. ~~CTC-3 (macOS Share Extension)~~ ERLEDIGT
4. ~~CTC-4 (Clipboard → Task)~~ ERLEDIGT — Paste-Button in QuickCaptureView (iOS+macOS)
5. ~~CTC-5 (Watch-Diktat)~~ ERLEDIGT — needsTitleImprovement Flag im Watch-Model + saveTask()
6. ~~CTC-6 (Smart Interpretation)~~ ERLEDIGT — Floskel-Erkennung ("Erinnere mich...") + Similar-Task-Lernen (Attribute von aehnlichen Tasks uebernehmen)

**Kernidee:** Aus jedem Kontext (Mail, Safari, Clipboard, Diktat) mit einem Tap eine Task erstellen. KI generiert actionable Titel im Hintergrund, Original bleibt in Beschreibung erhalten.

---

## ERLEDIGT: Feature #28 — App Icon (alle Plattformen)

- **Spec:** `docs/specs/design/app-icon-liquid-glass.md`
- **Design:** Two Rings + Dot — Zwei konzentrische Cyan-Ringe (aussen halbtransparent, innen voll) + dunklerer Mittelpunkt auf weissem Hintergrund
- **Layer-Strategie:** Design in Background baken (Farben bleiben erhalten), Foreground nur als Glass-Shape fuer Tiefe/Parallax
- **Deployed:** iOS 26 (layered .icon), watchOS, Widgets, macOS (alle Groessen)
- **Dateien:** `AppIcon.icon/`, `scripts/ExportIconLayers.swift`, alle Platform-AppIcon.png
- **Key Learning:** Liquid Glass entfernt alle Farbe aus dem Foreground-Layer — farbige Elemente muessen in den Background

---

## Bugs (offen)

### ~~Bug 67: Tab-Labels Deutsch→English~~ (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Fix:** Labels auf beiden Plattformen auf Englisch: Blöcke→Blox, Fokus→Focus, Rückblick→Review (iOS), Planen→Blox, Zuweisen→Assign (macOS)
- **Dateien:** MainTabView.swift, DailyReviewView.swift, SidebarView.swift, MacPlanningView.swift, MacAssignView.swift

### Bug 68: FocusBlock View-Umbau — Full-Screen Sheet mit 3 Sektionen (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Fix:** FocusBlockTasksSheet als Full-Screen Sheet (.large) mit 3 Sektionen: Assigned Tasks, Next Up (immer sichtbar), "Alle Tasks" (expandierbar). iOS: vertikal gestapelt, macOS: side-by-side. macOS MacPlanningView oeffnet jetzt Sheet direkt statt ueber separate View.
- **Geaenderte Dateien:** FocusBlockTasksSheet.swift, BlockPlanningView.swift, MacPlanningView.swift, ContentView.swift (macOS)
- **UI Tests:** 5/5 gruen (Bug68BlockTaskSheetUITests)

### Bug 69: FocusBlock Cross-Platform Sync zu langsam (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS ↔ macOS
- **Symptom:** Neue FocusBlocks erscheinen nicht innerhalb von 10sec auf der anderen Plattform
- **Root Cause:** Fehlender `EKEventStoreChangedNotification` Listener — Views haben nie automatisch neu geladen wenn EventKit-DB sich aenderte (z.B. durch iCloud Calendar Sync)
- **Fix:** EKEventStoreChangedNotification Listener in EventKitRepository + reaktiver .onChange in BlockPlanningView (iOS) und MacPlanningView (macOS)
- **Dateien:** EventKitRepository.swift, EventKitRepositoryProtocol.swift, MockEventKitRepository.swift, BlockPlanningView.swift, MacPlanningView.swift
- **Tests:** 3 Unit Tests (EventStoreChangeNotificationTests), Build OK (iOS + macOS)
- **Analyse:** `docs/artifacts/bug-focusblock-sync-slow/analysis.md`
- **Hinweis:** Refresh-Latenz haengt von Apple iCloud Calendar Sync ab (typisch 5-30s)

### Bug 71: Urgency-Keywords nicht aus Titel entfernt (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Task "Flüge für Retreat buchen (dringend)" — Priorität wird korrekt auf Dringend gesetzt, aber "(dringend)" bleibt im Titel
- **Root Cause:** TaskTitleEngine lief nur beim App-Start (nicht nach Task-Erstellung). Kein deterministisches Keyword-Stripping vorhanden.
- **Fix:** `stripKeywords()` entfernt Urgency-Keywords synchron vor dem Speichern. `improveTitleIfNeeded()` wird jetzt direkt nach Task-Erstellung aufgerufen statt erst beim naechsten App-Start.
- **Dateien:** TaskTitleEngine.swift, LocalTaskSource.swift
- **Tests:** 7 neue Unit Tests (alle GREEN), 23 Gesamt-Tests GREEN
- **Analyse:** `docs/artifacts/bug-title-keyword-not-stripped/analysis.md`
- **Nebenfix:** workflow_state_multi.py — Override-Token nur noch bei Phasen-Spruengen noetig

### Bug 70a: 15-Min-Snapping bei FocusBlock-Erstellung (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (Shared)
- **Symptom:** FocusBlock-Zeiten konnten auf beliebige Minuten gesetzt werden (09:13, 09:47 etc.)
- **Fix:** `FocusBlock.snapToQuarterHour()` rundet zur naechsten Viertelstunde (round-to-nearest). Angewendet in init (Initialwerte) + save (Speichern) aller 3 Sheets.
- **Dateien:** FocusBlock.swift, BlockPlanningView.swift, EditFocusBlockSheet.swift, MacPlanningView.swift
- **Tests:** 14 Unit Tests (FocusBlockSnapTests), alle GREEN, Build OK (iOS + macOS)
- **Analyse:** `docs/artifacts/bug-70a-15min-snapping/analysis.md`

### Bug 70b: FocusBlock verschieben per Drag & Drop auf Timeline (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Blocks konnten nicht per Drag & Drop auf der Timeline verschoben werden (Zeitslot aendern)
- **Root Cause:** iOS BlockPlanningView und macOS MacTimelineView hatten keine `.draggable()` / `.dropDestination()` fuer FocusBlocks
- **Fix:** CalendarEventTransfer(from: FocusBlock) init, `.draggable()` auf FocusBlockRows, `.dropDestination(for: CalendarEventTransfer.self)` auf TimelineHourRows, 15-Min-Snapping via `FocusBlock.snapToQuarterHour()`. Nur Future-Blocks draggable.
- **Nebenfix:** macOS `updateBlockTime()` persistierte nicht zu EventKit — jetzt behoben
- **Dateien:** CalendarEventTransfer.swift, BlockPlanningView.swift, MacTimelineView.swift, MacPlanningView.swift, MockEventKitRepository.swift
- **Tests:** 10 Unit Tests (FocusBlockDragTests), 4 UI Tests (FocusBlockDragDropUITests), alle GREEN
- **Naechster Schritt:** Bug 70c (Block resizen per Drag)

### Bug 70c-1a: Shared Timeline Layout Extraction (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** beide (iOS + macOS)
- **Ziel:** TimelineLayout + Collision Detection aus FocusBloxMac/ nach Sources/ extrahieren fuer Cross-Platform Sharing
- **Dateien:** Sources/Layouts/TimelineLayout.swift (NEU), Sources/Models/TimelineItem.swift (NEU), FocusBloxMac/TimelineLayout.swift (GELOESCHT), FocusBloxMac/MacTimelineView.swift (private Typen entfernt)
- **Tests:** 14 Unit Tests (TimelineCollisionTests) — 8 Collision Detection + 6 Layout Math, alle GREEN
- **Naechster Schritt:** keiner (Bug 70 komplett)

### Bug 70c-1b: iOS Timeline Canvas Rebuild (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS
- **Ziel:** List-basierte Timeline (TimelineHourRow per Stunde) durch Canvas-basierte Timeline (TimelineLayout + Collision Detection) ersetzen — Paritaet mit macOS
- **Dateien:** Sources/Models/TimelineItem.swift (PositionedFocusBlock + TimelineLocationCalculator als Shared-Types), Sources/Views/BlockPlanningView.swift (Canvas-Rendering), FocusBloxMac/MacTimelineView.swift (private Duplikat entfernt)
- **Tests:** 8 Unit (IOSTimelineCanvasTests) + 5 UI (IOSTimelineCanvasUITests) — alle GREEN

### Bug 70c-2: Block Resize per Drag (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** beide (iOS + macOS)
- **Ziel:** User kann Block-Dauer aendern per Drag am unteren Rand — 15-Min-Snapping, Min-Dauer 15 Min
- **Dateien:** Sources/Models/FocusBlock.swift (resizedEndDate + minDurationMinutes), Sources/Views/BlockPlanningView.swift (iOS Resize Handle + Gesture), FocusBloxMac/MacTimelineView.swift (macOS Resize Handle + Gesture + Cursor), FocusBloxMac/MacPlanningView.swift (resizeFocusBlock Handler)
- **Tests:** 8 Unit Tests (FocusBlockResizeTests) — alle GREEN

### Bug 70d: FocusBlock Drag-Indicator + Titel-Update bei Verschieben (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** beide (iOS + macOS)
- **Symptom:** (A) Kein visueller Indicator wohin ein Block beim Drag landet. (B) Block-Name ("FocusBlox HH:MM") aendert sich nicht bei Verschieben auf neue Uhrzeit.
- **Root Cause:**
  - (A) iOS hatte kein `DropPreviewIndicator` (macOS hatte eins)
  - (B) `EventKitRepository.updateFocusBlockTime()` aktualisierte nur startDate/endDate, NICHT event.title
- **Fix:**
  - `FocusBlock.generateTitle(for:)` als Single Source of Truth fuer Block-Titel
  - `EventKitRepository.updateFocusBlockTime()` setzt jetzt auch `event.title`
  - iOS: `DropPreviewIndicator` + `TimelineDropDelegate` mit live Position
  - macOS: Optimistic UI verwendet neuen Titel
  - iOS: Notification-Text verwendet neuen Titel
- **Dateien:** FocusBlock.swift, EventKitRepository.swift, MockEventKitRepository.swift, BlockPlanningView.swift, MacPlanningView.swift
- **Tests:** 4 Unit Tests (FocusBlockTitleUpdateTests), 2 UI Tests (FocusBlockDropIndicatorUITests), alle GREEN

### Bug 72: macOS — FocusBlock Gear-Icon fehlt (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Kein Button um EditFocusBlockSheet auf macOS zu oeffnen (iOS hatte Gear-Icon, macOS nicht)
- **Root Cause:** `FocusBlockView` hatte `onTapEdit`-Callback definiert und verdrahtet, aber kein UI-Element zum Ausloesen
- **Fix:** Gear-Icon Button ("gearshape") in FocusBlockView HStack eingefuegt. Immer sichtbar, bei Hover hervorgehoben (opacity 0.6 → 1.0). accessibilityIdentifier: `focusBlockEditButton_{blockID}`
- **Dateien:** FocusBloxMac/MacTimelineView.swift (1 Datei, ~12 LoC)
- **Tests:** 25 macOS Unit Tests GREEN, Build OK (iOS + macOS)

### Bug 66: macOS FocusBlock nicht sichtbar in MenuBar + Sync-Deadlock (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** MenuBar-Icon zeigte immer nur statisches `cube.fill` — kein Timer, kein Checkmark bei aktivem FocusBlock. Ausserdem: Erledigte Tasks sync'ten nicht waehrend eines aktiven Blocks.
- **Root Cause (2 Bugs):**
  1. **Bug A (Statisches Icon):** Bug-58-Migration (MenuBarExtra → NSStatusItem) hat dynamisches Label nie reimplementiert. `button.image` wurde einmal auf `cube.fill` gesetzt, nie aktualisiert.
  2. **Bug B (Timer Deadlock):** `activeTimer` (1s) aktualisierte nur `currentTime`, `pollingTimer` (60s) war durch `guard activeBlock == nil` blockiert — `loadFocusBlock()` wurde waehrend aktiver Blocks NIE automatisch aufgerufen.
- **Fix:**
  - Bug A: `MenuBarController` mit `updateIcon()` Methode (1s Timer), `MenuBarIconState` Pure-Logic-Enum (idle/active/allDone), `variableLength` statt `squareLength`
  - Bug B: `refreshCounter` in `MenuBarView` — alle 15 Ticks `loadFocusBlock()` waehrend aktiver Blocks
- **Dateien:** MenuBarIconState.swift (NEU), FocusBloxMacApp.swift, MenuBarView.swift, project.pbxproj
- **Tests:** 10 Unit Tests (MenuBarIconStateTests), UI Test nicht anwendbar (NSStatusItem = SystemUIServer)
- **Analyse:** `docs/artifacts/bug-mac-focusblock-menubar/analysis.md`

### Bug 88: macOS MenuBar Timer zeigt Block-Dauer statt Task-Dauer (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS (nur MenuBar StatusItem)
- **Symptom:** Timer in der Menuleiste zeigte die Restzeit des gesamten FocusBlocks (z.B. 40:00) statt der Restzeit des aktuellen Tasks (z.B. 5:00). iOS LiveActivity und macOS Popover zeigten bereits korrekt die Task-Restzeit.
- **Root Cause:** `MenuBarIconState.from()` berechnete `block.endDate - now` (Block-Restzeit). `MenuBarController` hatte keinen SwiftData-Zugriff fuer Task-Dauern.
- **Fix:**
  - `MenuBarIconState.from()` erweitert um optionalen `taskEndDate: Date?` Parameter
  - `MenuBarController` speichert `ModelContainer`, cached Task-Dauern alle 15s, berechnet Task-Endzeit via `TimerCalculator.plannedTaskEndDate()`
- **Dateien:** MenuBarIconState.swift, FocusBloxMacApp.swift, MenuBarIconStateTests.swift (3 Dateien, ~30 LoC)
- **Tests:** 13/13 gruen (3 neue Tests fuer taskEndDate-Parameter)
- **Analyse:** `docs/artifacts/bug-menubar-timer-wrong/analysis.md`

### Bug 91: macOS Menuleisten-Icon zeigt App-Icon statt cube.fill (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Menuleisten-Icon war generisches SF Symbol (cube.fill) statt dem eigenen App-Icon
- **Fix:** App-Icon wird geladen, Hintergrund weggeschnitten (innere 60%), kreisfoermig maskiert und als Graustufen gerendert
- **Dateien:** FocusBloxMacApp.swift (1 Datei geaendert), MenuBarIdleIconTests.swift (neu)
- **Tests:** 2/2 gruen + alle bestehenden MenuBar-Tests gruen
- **Analyse:** `docs/artifacts/bug-menubar-icon-template/analysis.md`

### Bug 64: Kategorie-Icon auf Kalender-Events zu klein (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (Shared Component)
- **Symptom:** CategoryIconBadge war ein winziger 18x18 Kreis mit 9pt Icon — kaum erkennbar
- **Fix:** Zweizeilige Capsule-Badge mit Icon (11pt) + Kategorie-Label (localizedName)
- **Dateien:** CategoryIconBadge.swift (1 Datei geaendert), CategoryIconBadgeTests.swift (+2 Tests)
- **Tests:** 5/5 gruen

### Bug 63: Kategorie-Zuweisung bei wiederkehrenden Kalender-Events mit Gaesten (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Wiederkehrende Events mit Gaesten konnten nicht kategorisiert werden (3 gescheiterte Versuche)
- **Root Cause:** Architektur-Problem — Notes read-only bei Gaesten, `eventIdentifier` instabil fuer recurring Occurrences, KV Store Key mismatch
- **Fix:** Komplett neuer Ansatz — lokales UserDefaults-Mapping mit `calendarItemIdentifier` als Key (stabil ueber alle Occurrences). Kein EventKit-Schreibzugriff, keine Notes-Manipulation, keine read-only-Unterscheidung noetig.
- **Dateien:** CalendarEvent.swift, EventKitRepository.swift, EventKitRepositoryProtocol.swift, MockEventKitRepository.swift, BlockPlanningView.swift, MacPlanningView.swift
- **Tests:** 21/21 gruen (8 neue CalendarCategoryMappingTests + 7 aktualisierte CalendarEventCategoryTests + 6 CalendarEventReadOnlyTests)
- **Analyse:** `docs/artifacts/bug-recurring-calendar-category/analysis.md`

### ~~Bug 62: Share Extension - CloudKit Entitlements fehlen~~ (ERLEDIGT)
- **Status:** ERLEDIGT (siehe oben: "ERLEDIGT: Bug 62 — Share Extension Fixes")
- **Fixes:** CloudKit Entitlements, MARKETING_VERSION, NSItemProvider API, Fallback-Logik

### Bug 65: Listendarstellung iOS vs macOS divergiert (Sektionen) (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** macOS zeigte nur 2 Sektionen (Next Up + Backlog), iOS hatte 6 (Next Up, Ueberfaellig, Sofort erledigen, Bald einplanen, Bei Gelegenheit, Irgendwann)
- **Root Cause:** Priority-Tier-Sektionen wurden nie auf macOS uebertragen (BACKLOG-004 Divergenz)
- **Fix:** macOS ContentView.swift: Neue `priorityBacklogView` mit Overdue-Section + 4 Priority-Tier-Sections (analog iOS). Flat-List bleibt fuer andere Filter (recent, overdue, completed, recurring). `taskRowWithSwipe` Helper reduziert Code-Duplikation.
- **Dateien:** FocusBloxMac/ContentView.swift (1 Datei)
- **Tests:** 8 Unit Tests (MacBacklogSectionsTests), 3 UI Tests (MacBacklogSectionsUITests)
- **Analyse:** `docs/artifacts/bug-65-mac-sections/analysis.md`

### Bug 73: "Tasks hinzufuegen"-Dialog — keine Prioritaets-Info, schlechte Sortierung (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (Shared View)
- **Symptom:** "Alle Tasks"-Sektion zeigte nur Titel+Dauer, keine Priority-Badges, unsortiert.
- **Root Cause:** `SheetNextUpRow` nutzte keine der vorhandenen Shared Badge Components. `allTasks` wurde unsortiert uebergeben.
- **Fix:** (1) Shared Badges (`ImportanceBadge`, `UrgencyBadge`, `PriorityScoreBadge`) in `SheetNextUpRow` eingebaut (read-only). (2) `allTasksSortedByPriority` sortiert nach `priorityScore` absteigend.
- **Geaenderte Dateien:** `FocusBlockTasksSheet.swift` (1 Datei, Shared = beide Plattformen)
- **Tests:** 3 Unit Tests (`FocusBlockTasksSheetTests`)
- **Spec:** `docs/specs/bugs/bug-73-task-dialog-priority.md`

### Bug 87: QuickCapture Dialog schliesst nicht nach Speichern (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS
- **Symptom:** Schnellspeichern-Dialog (QuickCaptureView) schliesst nicht wenn man auf "Speichern" klickt.
- **Root Cause:** Exakt dasselbe Problem wie Bug 74: `dismiss()` wurde innerhalb eines async `Task {}` aufgerufen, nach 600ms `Task.sleep()` fuer Success-Animation. Auf iOS 26 wird die `@Environment(\.dismiss)` Referenz ungueltig wenn die View durch `showSuccess = true` re-rendert.
- **Fix:** `dismiss()` synchron VOR dem async Task-Block aufrufen. View-Properties vorher in lokale Variablen capturen. Success-Animation entfernt (haptisches Feedback bleibt).
- **Geaenderte Dateien:** `Sources/Views/QuickCaptureView.swift`, `FocusBloxUITests/QuickCaptureUITests.swift`
- **Tests:** 12 UI Tests (QuickCaptureUITests) — alle gruen
- **Analyse:** `docs/artifacts/bug-quick-save-dialog-close/analysis.md`

### Bug 74: Sheet dismiss nach Speichern — Create Task (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS
- **Symptom:** Beim Erstellen eines neuen Tasks schliesst sich das Sheet nicht nach Tippen auf "Speichern".
- **Root Cause:** `dismiss()` wurde im Create-Mode innerhalb eines async `Task { await MainActor.run { dismiss() } }` aufgerufen. Auf iOS 26 funktioniert async dismiss in Sheets mit NavigationStack nicht zuverlaessig.
- **Fix:** `dismiss()` synchron VOR dem async Task-Block aufrufen (wie im funktionierenden Edit-Mode). Alle benoetigten View-Properties vorher in lokale Variablen capturen.
- **Geaenderte Datei:** `Sources/Views/TaskFormSheet.swift`
- **Tests:** 5 UI Tests (SheetDismissUITests) — Create+Edit+Cancel+FocusBlock
- **Analyse:** `docs/artifacts/bug-sheet-dismiss/analysis.md`

### Bug 75: macOS — App-Icon wird nicht korrekt angezeigt (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Im Dock wird ein blasses/unsichtbares Icon angezeigt statt des FocusBlox App-Icons
- **Root Cause:** Alle 10 macOS Icon-PNGs hatten doppelte Pixelmasse (DPI 144 statt 72, hasAlpha statt opak). `scripts/render-icon.swift` erzeugte auf Retina-Mac 2x-Pixel trotz `scale=1.0`.
- **Fix:** Alle 10 Icons aus iOS-Quelle (1024x1024, korrekt) per `sips` in korrekte Groessen resized. DPI 72, kein Alpha.
- **Screenshot:** `docs/artifacts/bug-75-78-mac-bugs/icon-screenshot.png`

### Bug 76: macOS — Neuer Task verschwindet nach Anlegen (Fokus fehlt) (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Task ueber Eingabeschlitz anlegen → Task nicht selektiert, scheint zu verschwinden.
- **Root Cause:** `addTask()` verwarf den Rueckgabewert von `createTask()` (`_ = try?`). `selectedTasks` wurde nie auf die UUID des neuen Tasks gesetzt.
- **Fix:** Rueckgabewert nutzen und `selectedTasks = [newTask.uuid]` setzen (1 Zeile).
- **Betroffene Views:** `ContentView.swift:767` (macOS)

### Bug 77: macOS — Orange Umrandung bei geaendertem Task zu eng am Inhalt (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Die orangene Umrandung (pendingResort-Indikator) war optisch zu knapp am Inhalt.
- **Root Cause:** `MacBacklogRow` hatte nur `.padding(.vertical, 4)` ohne horizontales Padding (iOS BacklogRow hat `.padding(12)` auf allen Seiten).
- **Fix:** Padding auf `.padding(.vertical, 6).padding(.horizontal, 8)` erweitert.
- **Screenshot:** `docs/artifacts/bug-75-78-mac-bugs/border-screenshot.png`

### Bug 78: macOS — Crash bei Swipe-Aktionen (SwiftData Fault) (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** App stuerzt ab bei Swipe-Aktion (editieren/loeschen) auf einer Task-Row
- **Fehlermeldung:** `Fatal error: This backing data was detached from a context without resolving attribute faults: PersistentIdentifier(...) - \LocalTask.tags`
- **Root Cause:** macOS nutzt `@Query` (direkte SwiftData-Referenzen), iOS nutzt `PlanItem` (value-type Kopien). Wenn ein Task-Objekt detached wird (Delete, CloudKit-Sync), halten Views stale Referenzen. Beim naechsten State-Change (Edit- oder Delete-Swipe) werden computed properties re-evaluiert → `.tags`-Zugriff auf detachtem Objekt → Crash.
- **Fix:** `task.modelContext != nil` Guard an 7 Stellen: `matchesSearch()`, `visibleTasks`, `filteredTasks` (2x), `regularFilteredTasks` (2x), `MacBacklogRow.tags`-Zugriff
- **Dateien:** ContentView.swift (macOS, 6 Guards), MacBacklogRow.swift (1 Guard + SwiftData import)
- **Tests:** 5 Unit Tests (DetachedTaskGuardTests), Build OK (iOS + macOS)
- **iOS:** NICHT betroffen (PlanItem value-type Kopien)
- **Analyse:** `docs/artifacts/bug-78-swiftdata-crash/analysis.md`

### Bug 79: Kalender-Event-Badges zeigen falsche (deutsche) Kategorie-Labels (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (Shared Code)
- **Symptom:** CategoryIconBadge im Kalender-View zeigte deutsche Labels ("Pflege", "Energie", "Geld") statt der korrekten englischen Labels ("Essentials", "Self Care", "Earn")
- **Root Cause:** `CategoryIconBadge.swift:10` nutzte `category.localizedName` (Deutsch) statt `category.displayName` (Englisch)
- **Fix:** Eine Zeile: `localizedName` → `displayName` in `CategoryIconBadge.swift:10`
- **Tests:** 6/6 gruen (CategoryIconBadgeTests: testBadge_labelText_returnsDisplayName, testBadge_labelText_allCategoriesShowEnglishDisplayName + 4 bestehende)
- **Analyse:** `docs/artifacts/bug-calendar-category-labels/analysis.md`

### Bug 80: Kalender-Event-Kategorien synchen nicht zwischen iOS und macOS (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS ↔ macOS (Shared Code)
- **Symptom:** Auf iOS gesetzte Kategorien fuer Kalender-Events waren auf macOS nicht sichtbar (und umgekehrt)
- **Root Cause:** Event-Kategorien in `UserDefaults.standard` gespeichert (device-lokal, kein iCloud-Sync)
- **Fix:** `SyncedSettings` um Event-Category-Sync erweitert:
  - Push: `pushToCloud()` kopiert Category-Dictionary in `NSUbiquitousKeyValueStore`
  - Pull: `pullFromCloud()` mergt Remote-Categories in lokale UserDefaults (Remote gewinnt bei Konflikten)
  - `EventKitRepository.updateEventCategory()` triggert automatisch Push zu iCloud
- **Betroffene Dateien:** SyncedSettings.swift, EventKitRepository.swift, SyncedSettingsTests.swift, CategoryIconBadgeTests.swift
- **Tests:** 10/10 gruen (SyncedSettingsTests: 4 neue Merge-Tests + 6 bestehende)
- **Analyse:** `docs/artifacts/bug-calendar-category-labels/analysis.md`

### Bug 81: FocusBlock Task-Zuweisung verliert ersten Task (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (beide gefixt)
- **Symptom:** Im FocusBlock-Edit-Sheet: Task zuweisen → zweiten Task zuweisen → erster Task verschwindet. Tasks werden unsichtbar (nicht mehr im Backlog, nicht mehr im Block).
- **Root Cause:** `.sheet(item: $blockForTasks) { block in ... }` fängt `FocusBlock` (value-type struct) als Snapshot. Jede Zuweisung liest `block.taskIDs` vom Snapshot statt vom aktuellen State. Zweite Zuweisung überschreibt erste. Tasks landen im LIMBO (assignedFocusBlockID gesetzt, aber nicht in block.taskIDs).
- **Fix (3 Teile):**
  1. `assignTaskToBlock` liest von `focusBlocks.first { $0.id == block.id }` statt stale `block`
  2. Nach `loadData()`: `blockForTasks = refreshedBlock` damit Sheet neu rendert
  3. `FocusBlockTasksSheet`: `.onChange(of: tasks.map(\.id))` aktualisiert `taskOrder`
- **Recovery:** `SyncEngine.cleanOrphanedBlockAssignments()` findet Tasks mit assignedFocusBlockID die in keinem Block gelistet sind und setzt sie frei
- **Dateien:** BlockPlanningView.swift, MacPlanningView.swift, FocusBlockTasksSheet.swift, SyncEngine.swift
- **Tests:** 3 Unit Tests (FocusBlockAssignmentTests), 1 UI Test (Bug81StaleBlockAssignmentUITests)
- **Analyse:** `docs/artifacts/bug-81-82-focusblock-search/analysis.md`

### Bug 85-A: Uhrzeit bei Faelligkeitsdatum ueberall anzeigen (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (beide gefixt)
- **Symptom:** Uhrzeit wird im DatePicker gespeichert aber nirgendwo angezeigt. Alle Frist-Anzeigen zeigen nur "Heute", "Morgen" oder Datum ohne Uhrzeit. macOS TaskInspector erlaubt keine Uhrzeit-Eingabe.
- **Root Cause:** `Date+DueDate.swift` nutzte `timeStyle = .none` im Datum-Pfad, und Early-Returns fuer "Heute"/"Morgen" gaben pure Strings ohne Uhrzeit zurueck. TaskInspector hatte `displayedComponents: .date` (ohne Uhrzeit).
- **Fix (2 Dateien):**
  1. `Date+DueDate.swift`: Neue `dueDateTimeSuffix` Property — appended ", HH:mm" wenn Uhrzeit != 00:00. Alle 4 Code-Pfade (Heute/Morgen/Wochentag/Datum) nutzen den Suffix.
  2. `TaskInspector.swift`: DatePicker von `.date` auf `[.date, .hourAndMinute]` geaendert.
- **Logik:** 00:00 = "keine Uhrzeit gesetzt" (keine Anzeige). Alle anderen Uhrzeiten werden als ", HH:mm" angehaengt.
- **Dateien:** Date+DueDate.swift, TaskInspector.swift (2 Dateien, ~15 LoC)
- **Tests:** 10 neue Unit Tests (DueDateTimeDisplayTests) + 12 bestehende (DueDateFormattingTests) — alle gruen
- **Analyse:** `docs/artifacts/bug-85-reminder-time-display/analysis.md`

### Bug 85-D: Postpone falsches Ursprungsdatum (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS + watchOS (alle gefixt)
- **Symptom:** "Verschieben auf morgen" rechnete ab Original-Faelligkeitsdatum statt ab heute. Ueberfaellige Tasks blieben ueberfaellig.
- **Root Cause:** `LocalTask.postpone()` addierte Tage zu `task.dueDate` statt zu `Date()`.
- **Fix (2 Dateien, +1 Tests):**
  1. `LocalTask.swift`: Basis auf `startOfDay(for: Date())` geaendert, Uhrzeit aus Original-Datum erhalten
  2. `WatchNotificationDelegate.swift`: Gleicher Fix fuer Watch-Inline-Implementation
  3. `TaskPostponeTests.swift`: 3 neue Overdue-Testcases (vorher nur Today-Tests)
- **Tests:** 9 Unit Tests (TaskPostponeTests) — alle gruen
- **Analyse:** `docs/artifacts/bug-postpone-wrong-date/analysis.md`

### Bug 85-C: Kontextmenue Verschieben-Optionen (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS (beide gefixt)
- **Symptom:** Kein "Verschieben"-Menue in Kontextmenues. User konnten Fristen nur ueber Edit-Sheet aendern.
- **Fix (4 Dateien):**
  1. `LocalTask.swift`: Shared `postpone(_:byDays:context:)` Extension — dueDate + N Tage, modifiedAt, rescheduleCount++, save()
  2. `BacklogView.swift`: `.contextMenu` mit "Verschieben"-Menu (Morgen/Naechste Woche) fuer Next Up + Backlog Rows
  3. `ContentView.swift` (macOS): "Verschieben"-Menu im `.contextMenu(forSelectionType:)` (nur Einzelselektion + dueDate)
  4. `NotificationActionDelegate.swift`: Refactored auf shared `LocalTask.postpone()` (alter private Helper entfernt)
- **Tests:** 6 Unit Tests (TaskPostponeTests) — alle gruen
- **Analyse:** `docs/artifacts/bug-85c-context-menu-postpone/analysis.md`

### Bug 85-B: Notification Snooze-Optionen (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS + watchOS (alle gefixt)
- **Symptom:** Notification-Aktionen bieten nur "Morgen" (+1 Tag) an. Apple Reminders bietet multiple Snooze-Optionen (Morgen, Naechste Woche).
- **Root Cause:** NotificationService registrierte nur 3 Aktionen (Next Up, Morgen, Erledigt). Kein +7-Tage-Handler existierte.
- **Fix (3 Dateien):**
  1. `NotificationService.swift`: `actionPostponeTomorrow` + `actionPostponeNextWeek` Konstanten, `registerDueDateActions()` mit 4 Aktionen
  2. `NotificationActionDelegate.swift`: Neue Cases fuer Tomorrow (+1) und NextWeek (+7), `postponeTask` Helper mit Notification-Rescheduling. Predicate-Fix: `$0.uuid == taskUUID` statt computed `$0.id` (SwiftData-Bug)
  3. `WatchNotificationDelegate.swift`: Gleiche Konstanten + Handler + 4 Aktionen
- **Bonus-Fix:** NotificationActionDelegate nutzte `$0.id == taskID` in #Predicate — `id` ist computed Property, SwiftData kann das nicht querien. Auf stored `uuid` Property gewechselt (wie Watch-Delegate).
- **Dateien:** NotificationService.swift, NotificationActionDelegate.swift, WatchNotificationDelegate.swift (3 Dateien, ~20 LoC)
- **Tests:** 5 Unit Tests (NotificationSnoozeTests) — alle gruen
- **Analyse:** `docs/artifacts/bug-85-reminder-time-display/analysis.md`

### Bug 86: macOS Text-Truncation in Backlog + Sidebar (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Task-Titel werden mit "..." abgeschnitten obwohl Platz vorhanden. Sidebar-Labels ("Ueberf...", "Wiede...", "Erle...") ebenso.
- **Root Cause:** (1) MacBacklogRow VStack ohne `.frame(maxWidth: .infinity)` — iOS hat das, macOS fehlte es. (2) NavigationSplitView Sidebar ohne explizite Spaltenbreite — Default ~200px zu schmal fuer Labels + Badge.
- **Fix (2 Dateien):**
  1. `MacBacklogRow.swift`: `.frame(maxWidth: .infinity, alignment: .leading)` auf VStack, `.lineLimit(2)` + `.truncationMode(.tail)` auf Titel, `Spacer()` entfernt
  2. `ContentView.swift`: `.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)` auf SidebarView
- **Blast Radius:** 7 weitere macOS Views mit identischem Pattern → BACKLOG-013
- **Dateien:** MacBacklogRow.swift, ContentView.swift (2 Dateien, ~5 LoC)
- **Tests:** 2 macOS UI Tests (MacTextTruncationUITests) — alle gruen
- **Analyse:** `docs/artifacts/bug-mac-text-truncation/analysis.md`

### Bug 84: App-Icon Badge zaehlt NextUp/FocusBlock-Tasks mit (ERLEDIGT)
- **Status:** ERLEDIGT
- **Plattform:** iOS (Badge) + macOS (Sidebar-Badge)
- **Symptom:** Badge zeigte (8) obwohl nur 4 ueberfaellige Tasks in "Ueberfaellig"-Ansicht sichtbar. 4 weitere waren in NextUp oder FocusBlocks zugewiesen.
- **Root Cause:** `NotificationService.updateOverdueBadge()` filterte `!isNextUp` und `assignedFocusBlockID == nil` NICHT — zahlte alle ueberfaelligen Tasks inkl. NextUp + FocusBlock-zugewiesener. BacklogView filtert diese korrekt aus.
- **Fix:** (1) Testbare `countOverdueBadgeTasks(context:)` Funktion extrahiert mit korrekten Filtern. (2) macOS `ContentView.overdueCount` analog angepasst.
- **Geaenderte Dateien:** `NotificationService.swift`, `ContentView.swift` (2 Dateien, ~10 LoC)
- **Tests:** 6 Unit Tests (BadgeCountFilterTests) — alle gruen
- **Analyse:** `docs/artifacts/bug-badge-count/analysis.md`

---

## ERLEDIGT: Feature — Blocker-Picker mit Suchfunktion

- **Anforderung:** Der Auswahldialog fuer abhaengige Tasks (Blocker) soll statt eines langen Dropdown-Menues ein Searchable Sheet mit alphabetischer Sortierung zeigen.
- **Plattformen:** iOS + macOS
- **Status:** DONE — 4/4 UI Tests GRUEN

### Implementierte Dateien:
- `Sources/Views/BlockerPickerSheet.swift` — Shared Komponente (Searchable List + "Keine"-Option + Checkmarks)
- `Sources/Views/TaskFormSheet.swift` — Picker durch Button + Sheet ersetzt (iOS)
- `FocusBloxMac/TaskInspector.swift` — Picker durch Button + Sheet ersetzt (macOS)
- `FocusBloxUITests/BlockerPickerSearchUITests.swift` — 4 UI Tests

### Behobene Test-Probleme (Learnings):
- Native `TabView`-Buttons haben keine custom IDs → `app.tabBars.buttons["Backlog"]` statt `app.buttons["tab-backlog"]`
- `glassCardSection` ID ueberschreibt Kind-IDs (SwiftUI-Gotcha) → `app.buttons["taskFormSection_dependency"]` statt `app.buttons["blockerPickerButton"]`
- Sheet-Suchfeld vs. Backlog-Suchfeld → spezifisch per Prompt-Text matchen

---

### Bug 92: Dependency-Sync iOS → macOS pruefen
- **Status:** OFFEN (Backlog)
- **Plattform:** iOS → macOS
- **Symptom:** Unklar ob Tasks mit Abhaengigkeiten (Blocker), die auf iOS erstellt werden, korrekt auf macOS synchronisiert werden inkl. der Dependency-Beziehung.
- **Pruefung noetig:** Task auf iOS erstellen, Blocker setzen, auf macOS pruefen ob (a) der Task ankommt und (b) die Abhaengigkeit korrekt angezeigt wird.
- **Risiko:** Falls Dependency-Felder nicht im CloudKit-Schema synchronisiert werden, gehen Abhaengigkeiten beim Sync verloren.

### Bug 93: Swipe-Gesten bei eingerueckten Tasks funktionieren nicht (iOS)
- **Status:** OFFEN (Backlog)
- **Plattform:** iOS (mindestens), macOS ggf. auch betroffen
- **Symptom:** Tasks die als Abhaengigkeit eingerueckt dargestellt werden, reagieren nicht auf Swipe-Gesten. Dadurch koennen eingerueckte Tasks weder bearbeitet, geloescht noch ihre Abhaengigkeit entfernt werden.
- **Auswirkung:** Eine einmal gesetzte Abhaengigkeit kann nicht mehr rueckgaengig gemacht werden. Der Task ist effektiv "gefangen" — kein Edit, kein Delete, kein Dependency-Remove moeglich.
- **Erwartetes Verhalten:** Eingerueckte Tasks muessen mindestens diese Swipe-Aktionen unterstuetzen: (1) Abhaengigkeit entfernen, (2) Bearbeiten, (3) Loeschen.
- **Vermutung:** Die Einrueckung (Indent) via `.padding(.leading)` oder aehnlichem koennte den Swipe-Gesture-Recognizer blockieren, oder `.swipeActions` fehlt auf der eingerueckten Row-Variante.

---

## Backlog (Technical Debt)

### ~~BACKLOG-001: Task Complete/Skip Divergenz~~ ERLEDIGT
- Beide Plattformen nutzen jetzt shared `SyncEngine.updateNextUp()` — keine duplizierte Completion-Logik mehr

### ~~BACKLOG-002: EventKitRepository Injection fehlt auf macOS~~ ERLEDIGT
- ContentView.swift + MacAssignView.swift nutzen jetzt `@Environment(\.eventKitRepository)` statt eigener Instanz — alle 8 macOS-Views konsistent

### ~~BACKLOG-003: NextUp Toolbar Divergenz~~ ERLEDIGT
- Dateien geloescht, ersetzt durch shared `NextUpSection.swift`

### ~~BACKLOG-004: BacklogView/BacklogRow~~ ERLEDIGT
- `BacklogView` nicht mehr dupliziert; `MacBacklogRow` ist bewusst eigene Datei (anderes Model/Actions)

### ~~BACKLOG-005: RecurrenceRuleView Divergenz~~ ERLEDIGT
- Dateien geloescht, ersetzt durch shared `TaskFormSheet.swift`

### ~~BACKLOG-006: TaskEditView Divergenz~~ ERLEDIGT
- Dateien geloescht, ersetzt durch shared `TaskFormSheet.swift`

### ~~BACKLOG-007: SidebarView macOS-only~~ Kein Debt
- macOS-Sidebar ist plattform-spezifisch by Design (NavigationSplitView)

### ~~BACKLOG-008: Workflow-System — Echte Parallelitaet~~ ERLEDIGT
- **Status:** DONE
- **Commit:** `699a715`
- **Loesung:** File-basierte Workflow-Zuordnung statt blindem `active_workflow`
  - `find_workflow_for_file()` sucht Workflows anhand `affected_files`
  - Code-Gate + TDD-Hook nutzen file-basierte Suche als primaeren Pfad
  - Fallback auf `active_workflow` fuer alte Workflows ohne `affected_files`
  - `complete_workflow()` setzt `active_workflow = None` statt zufaelligem Workflow
  - Override-Token: `"override [workflow-name]"` fuer explizite Zuweisung
  - Overlap-Detection: Warnung wenn Datei von mehreren aktiven Workflows beansprucht wird
- **Betroffene Dateien:** `.claude/hooks/workflow_state_multi.py`, `.claude/hooks/strict_code_gate.py`, `.claude/hooks/tdd_enforcement.py`, `.claude/hooks/override_token_listener.py`

### BACKLOG-009: Tech-Debt Quick Wins (ERLEDIGT)
- **SwiftData Indizes:** `#Index<LocalTask>` auf isCompleted, isNextUp, dueDate, isTemplate — Performance bei >500 Tasks
- **recurrenceDisplayName macOS:** Private Funktion in MacBacklogRow geloescht, nutzt jetzt shared `RecurrencePattern.displayName` (behebt Text-Mismatch "Zweiwoechentlich" → "Alle 2 Wochen")
- **Dead Code:** ~130 LoC ungenutzter Code + Debug-Prints in BlockPlanningView entfernt
- **macOS Mock Data:** seedUITestData fuer FocusBloxMacApp hinzugefuegt (identisch zu iOS, mit in-memory Store)
- **Tests:** 6 Unit Tests (TechDebtQuickWinsTests) + 2 macOS UI Tests (MacRecurrenceDisplayUITests)
- **Analyse:** `docs/context/tech-debt-analysis.md` (gewichtete Gesamtliste aller Tech-Debts)

### Verbleibende Tech-Debts (dokumentiert in `docs/context/tech-debt-analysis.md`)
- **TD-01:** God-Views (BlockPlanningView 1400 LoC, BacklogView 1181 LoC) — Aufwand: L
- **TD-02:** iOS/macOS View-Duplikation — Paket 1-3 ERLEDIGT (Badges, Sheets, Header: ~412 LoC eliminiert). Verbleibend: ~7500 LoC, Aufwand: XL
- **TD-03:** 3 Services ohne Unit Tests (NotificationService, FocusBlockActionService, GapFinder) — Aufwand: M *(TaskPriorityScoringService: 30 Tests, vollstaendige Abdeckung)*

### ~~BACKLOG-010: Deferred Sort Logik dupliziert (iOS vs macOS)~~ ERLEDIGT
- **Loesung:** Shared `DeferredSortController` in `Sources/Services/` extrahiert. Beide Plattformen nutzen `@Environment(DeferredSortController.self)`. Duplizierter Code entfernt. Bonus: fehlender `freeze()`-Call bei Kategorie-Aenderung (iOS) gefixt.

### ~~BACKLOG-011: MacBacklogRow berechnet Score direkt (umgeht frozen Scores)~~ ERLEDIGT
- **Loesung:** `MacBacklogRow` bekommt `effectiveScore`/`effectiveTier` als Parameter vom Parent (`ContentView.makeBacklogRow`). Parent berechnet via `scoreFor()` → `deferredSort.effectiveScore()`. Badge zeigt jetzt frozen Score waehrend Deferred Sort. Fallback auf `calculateScore()` wenn kein effectiveScore uebergeben (Preview).

### ~~BACKLOG-012: displayedRegularTasks ist toter Wrapper (macOS)~~ ERLEDIGT
- Bereits entfernt in Commit `cdad7c9` (2026-03-05) als Teil von BACKLOG-010 (Shared DeferredSortController)

### ~~BACKLOG-013: macOS Text-Truncation in 7 weiteren Views (Blast Radius Bug 86)~~ ERLEDIGT
- **Loesung:** `.frame(maxWidth: .infinity, alignment: .leading)` auf 9 Stellen in 5 Dateien angewandt (identisches Pattern wie Bug 86 Fix).
- **Geaenderte Dateien:** MacPlanningView, MacAssignView, MacFocusView, MenuBarView, MacTimelineView (5 Dateien, +9 LoC)
- **Tests:** 3 macOS UI Tests (MacTextTruncationBlastRadiusUITests) — alle gruen

### ~~BACKLOG-014: calculateScore() wird mit 8 identischen Parametern an 6+ Stellen aufgerufen~~ ERLEDIGT
- `PlanItem.priorityScore` existiert als Computed Property (PlanItem.swift:75-86) und wird in 15+ Stellen genutzt. Die 2 verbliebenen direkten Aufrufe in macOS Views (ContentView.scoreFor, MacBacklogRow) sind architekturbedingt (LocalTask vs PlanItem).

---

### Bug 89: Kategorie-Aenderung erst nach Verschieben sichtbar (iOS) — ERLEDIGT

- **Symptom:** Kategorie im Quick-Edit (CategoryPicker) aendern → BacklogRow zeigt weiterhin alte Kategorie bis Task per Drag verschoben wird
- **Root Cause:** `BacklogView.updateCategory()` speicherte via SyncEngine in die DB, aktualisierte aber NICHT das in-memory `planItems`-Array. `updateImportance()` und `updateUrgency()` hatten `planItems[index] = PlanItem(localTask: task)` — `updateCategory()` nicht.
- **Fix:** `updateCategory()` analog zu `updateImportance()` umgeschrieben: Fetch LocalTask → Property setzen → save → planItems-Array aktualisieren. 1 Datei, ~10 LoC.
- **Geaenderte Datei:** `Sources/Views/BacklogView.swift` (Zeile 571-585)
- **macOS:** Nicht betroffen (nutzt @Query + direkte Mutation)
- **Tests:** `CategoryUpdateRefreshTests` (4 Tests, alle gruen)

---

## Erledigte Features & Bugs (Archiv)

### 2026-03-12: XP/Evolution-System entfernt (widersprach User Story)
- Commit: `refactor: XP/Evolution-System entfernt — widerspricht User Story Anti-Pattern "keine XP, Levels, Achievements"`
- Geloescht: MonsterCoach.swift, MonsterStatusView.swift, MonsterCoachTests.swift, MonsterCoachUITests.swift
- Behalten: Discipline.swift (Task-Klassifizierung), Coach-Modus Toggle, Morning Intention
- Extrahiert: DisciplineTests.swift (4 Classify-Tests aus MonsterCoachTests)
- Files: 4 geloescht + 1 neu + 3 modifiziert
- Tests: 4 Discipline + 16 MorningIntention + 6 UI = 26 Tests, alle GREEN

### 2026-03-12: Monster Coach Phase 2 — Morning Intention Screen
- Commit: `feat: Monster Coach Phase 2 — Morning Intention Screen mit 6 Tages-Intentionen`
- DailyIntention Model + IntentionOption Enum (survival, fokus, bhag, balance, growth, connection)
- MorningIntentionView: Selection Grid (6 Chips) → kompakte Zusammenfassung nach Setzen
- Review-Tab → "Mein Tag" Rename bei aktivem Coach
- Konfigurierbare Push-Notification Morgen-Erinnerung in Settings
- Files: 2 neue + 6 geaenderte Dateien (~250 LoC)
- Tests: 16 Unit Tests + 6 UI Tests, alle GREEN

### 2026-03-04: Stop-Lock + API-Guard
- Stop-Lock: User tippt "stopp" → alle Edit/Write/Bash gesperrt bis "weiter"
- API-Guard: advance_phase/set_phase/mark_*_test_done brauchen Override-Token
- Files: stop_lock_guard.py (NEU), stop_lock_listener.py (NEU), workflow_state_multi.py, settings.json
- Tests: Isolierte Tests (Guard blockt, API-Funktionen blockiert ohne Token)

### 2026-03-04: Tech-Debt Quick Wins Bundle
- Commit: (pending)
- SwiftData Indizes + Recurrence-Text-Fix macOS + Dead-Code-Cleanup + macOS Mock Data
- Files: LocalTask.swift, MacBacklogRow.swift, BlockPlanningView.swift, FocusBloxMacApp.swift, FocusBloxApp.swift
- Tests: 6 Unit + 2 macOS UI = 8 Tests, alle GREEN

### 2026-03-03: Deferred List Sorting — 3 Bugfixes
- Commit: `fix: Deferred List Sorting — 3 Bugs (Urgency-Nil-Zyklus, onChange Guard, Orange Puls-Border)`
- **Bug 1 (iOS springt sofort):** `.onChange(of: remoteChangeCount)` Guard — Refresh wird uebersprungen wenn `pendingResortIDs` nicht leer ist
- **Bug 2 (Urgency haengt bei Dringend):** `updateUrgency()`/`updateImportance()` umgehen jetzt SyncEngine und setzen LocalTask direkt (nil funktioniert korrekt) + lokales PlanItem-Update nach Save
- **Bug 3 (Blauer Rahmen = Selektion):** Orange pulsierender Rahmen statt statischem Blau (iOS + macOS)
- Files: BacklogView.swift, BacklogRow.swift, MacBacklogRow.swift, LocalTaskTests.swift, DeferredSortUITests.swift, MacDeferredSortUITests.swift (NEU)
- Tests: 1 Unit Test + 5 iOS UI Tests + 3 macOS UI Tests = 9 Tests, alle GREEN

### 2026-02-22: Undo Task Completion (Shake to Undo iOS + Cmd+Z macOS)
- Commit: `feat: Undo Task Completion — Shake (iOS) + Cmd+Z (macOS)`
- Files: AppStateManager.swift, NextUpFullView.swift, FocusBloxMacApp.swift
- Tests: Unit Tests + UI Tests (iOS Shake Gesture + macOS Keyboard)

### 2026-02-21: ITB-F-lite — NSUserActivity fuer Siri/Spotlight Discovery
- Commit: `feat: ITB-F-lite — NSUserActivity fuer Siri/Spotlight Discovery`
- Files: TaskEntity.swift, ContentView.swift, BacklogRow.swift, TaskListView.swift
- Tests: Unit Tests fuer NSUserActivity Properties

### 2026-02-20: ITB-D — Pulsierender Glow-Effekt bei aktiven Focus-Sessions
- Commit: `feat: ITB-D — Pulsierender Glow-Effekt bei aktiven Focus-Sessions`
- Files: FocusGlowModifier.swift, NextUpFullView.swift
- Tests: Unit Tests fuer FocusGlowModifier

### 2026-02-19: ITB-A — FocusBlockEntity als AppEntity fuer Siri/Shortcuts
- Commit: `feat: ITB-A — FocusBlockEntity als AppEntity fuer Siri/Shortcuts`
- Files: FocusBlockEntity.swift, FocusBlockEntityQuery.swift
- Tests: Unit Tests fuer Entity + Query

### 2026-02-18: Bug 38 - CloudKit Sync funktioniert nicht zwischen iOS Geraeten (GELOEST)
- Commit: `fix: CloudKit Sync - modelContext.save() vor Fetch nach Remote Change`
- Root Cause: NSPersistentStoreRemoteChange feuert BEVOR Daten im Context verfuegbar sind
- Fix: `modelContext.save()` ohne pending Changes = Cache-Invalidierung + Store-Merge
- Files: TaskListViewModel.swift
- Tests: Manuell auf 2 iOS Devices (CloudKit Sync verifiziert)

### 2026-02-17: Bug 57 - Safe Setter fuer importance/urgency/duration (GELOEST)
- Root Cause: EventKit Tasks haben importance=nil → SwiftData Crash bei save()
- Fix: Safe Setter in LocalTask (clamp auf [1,3] bei importance, nie nil)
- Files: LocalTask.swift, LocalTaskExtensions.swift
- Tests: Unit Tests fuer Safe Setter Logic
- LESSON LEARNED: Dead Code Detection - Tests fuer Code der nie aufgerufen wird sind wertlos

### 2026-02-16: Bug 56 - AI Enrichment fehlte bei EventKit Import (GELOEST)
- Commit: `fix: AI-Enrichment in alle Task-Creation-Paths eingebaut`
- Root Cause: EventKit Import umging AIEnrichment komplett
- Fix: Enrichment in TaskService + EventKitRepository.createLocalTask eingebaut
- Files: TaskService.swift, EventKitRepository.swift
- Tests: Unit Tests fuer Enrichment Coverage

### 2026-02-15: Bug 55 - Recurring Tasks divergierten iOS/macOS (GELOEST)
- Root Cause: iOS TemplateManager vs macOS RecurrenceService (2 Implementierungen)
- Fix: TemplateManager geloescht, RecurrenceService fuer BEIDE Plattformen
- Files: 12 Files (Sources/ shared, macOS Views updated)
- Tests: Unit Tests + UI Tests fuer Template-Architektur

### 2026-02-14: Feature - Recurrence Editing Phase 2 (Intervalle + Custom)
- Commit: `feat: Recurrence Editing Phase 2 — Intervalle + Eigene (z.B. "Jeden 3. Tag")`
- Files: RecurrenceRuleView.swift (iOS+macOS), LocalTask Model
- Tests: UI Tests fuer Interval-Picker

### 2026-02-13: Bug 54 - Recurring Tasks noch sichtbar nach Completion
- Root Cause: RecurrenceService markierte Templates statt Instanzen
- Fix: Predicate `isRecurringTemplate == false` bei Fetches
- Tests: Unit Tests fuer Template/Instance Filtering

### 2026-02-12: Bug 53 - macOS Swipe Actions (Trackpad) nicht funktionsfaehig
- Root Cause: macOS hat keine .swipeActions() Modifier
- Fix: onTapGesture mit Modifiers (.option = Edit, .control = Delete)
- Tests: UI Tests fuer macOS Keyboard Modifiers

### 2026-02-11: Bug 52 - Import aus Erinnerungen markiert Tasks nicht als "complete"
- Root Cause: Completion-Handler fehlte in EventKitRepository
- Fix: .completeReminder() nach .createLocalTask() eingebaut
- Tests: Unit Tests fuer Import Completion

### 2026-02-10: Settings UX - Build-Info + Vorwarnungs-Labels
- Commit: `feat: Settings UX — Build-Info + Vorwarnungs-Labels`
- Files: SettingsView.swift (iOS), MacSettingsView.swift (macOS)
- Tests: UI Tests fuer Label-Sichtbarkeit

### 2026-02-09: NextUp Long Press Vorschau
- Commit: `feat: NextUp Long Press Vorschau (iOS)`
- Files: NextUpFullView.swift, BacklogRow.swift
- Tests: UI Tests fuer contextMenu (Long Press Gesture nicht simulierbar)

### 2026-02-08: NextUp Wischgesten (Edit+Delete)
- Commit: `feat: NextUp Wischgesten — Edit+Delete (iOS alle Views + macOS Trackpad-Swipe)`
- Files: NextUpFullView.swift, BacklogRow.swift, NextUpCompactView+Mac.swift
- Tests: UI Tests (iOS Swipe + macOS Keyboard Modifiers)

### 2026-02-07: List-Views Cleanup (ViewModes 9→5)
- Commit: `refactor: List-Views Cleanup — ViewModes 9→5 (-270 LoC)`
- Files: TaskListView.swift, TaskListViewModel.swift, ContentView.swift
- Tests: Unit Tests + UI Tests (alle View Modes)

### 2026-02-06: Generische Suche (iOS+macOS)
- Commit: `feat: Generische Suche (iOS+macOS) — Filter nach Titel+Tags`
- Files: TaskListView.swift (iOS), MacBacklogRow.swift
- Tests: UI Tests fuer Search Field

### 2026-02-05: Push Notifications bei Frist
- Commit: `feat: Push Notifications bei Frist (iOS+macOS)`
- Files: NotificationService.swift, AppDelegate.swift, TaskService.swift
- Tests: Unit Tests fuer Notification Scheduling

### 2026-02-04: Recurring Tasks Phase 1B/2 (macOS Badge, Siri, Delete-Dialog)
- Commit: `feat: Recurring Tasks Phase 1B/2 — macOS Badge + Siri + Delete-Dialog`
- Files: RecurrenceService.swift, BacklogRow.swift, MacBacklogRow.swift
- Tests: Unit Tests + UI Tests (Badge Sichtbarkeit + Delete Dialog)

### 2026-02-03: ITB-B — Smart Priority (AI-Enrichment + Hybrid-Scoring)
- Commit: `feat: ITB-B — Smart Priority (AI-Enrichment + Hybrid-Scoring)`
- Files: AIEnrichmentService.swift, TaskScorer.swift, TaskService.swift
- Tests: Unit Tests fuer AI-Enrichment + Scorer
