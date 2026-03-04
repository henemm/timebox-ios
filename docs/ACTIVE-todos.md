# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!

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
| 7 | Kalender-App Deep Link (iOS+macOS) | MITTEL | M | ~40-50k | 3-4 | ~100 |
| 8 | ~~Push Notifications bei Frist~~ | ERLEDIGT | M | ~60-80k | 9 | ~180 |
| 9 | MAC-031 Focus Mode Integration | P3 | M | ~50-70k | 2-3 | ~100 |
| 10 | MAC-030 Shortcuts.app | P3 | L | ~60-80k | 2-3 | ~150 |
| 11 | Emotionales Aufladen (Report) | MITTEL | L | ~80-100k | 3-4 | ~200 |
| 12 | MAC-026 Enhanced Quick Capture | P2 | L | ~80-120k | 4 | ~200 |
| 13 | MAC-020 Drag & Drop Planung | P2 | XL | ~100-150k | 3-4 | ~250 |
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

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**Guenstigster Quick Win:** ~~Shake to Undo (XS)~~ ERLEDIGT
**Teuerste Items:** #17 OrganizeMyDay (~150k), #13 Drag & Drop (~150k), #14 NC Widget (~120k)
**WARTEND (Apple-Abhaengigkeit):** #20 ITB-F — Developer-APIs verfuegbar, wartet auf Siri On-Screen Awareness (iOS 26.5/27)
**Zuletzt erledigt:** Stop-Lock + API-Guard (Schutzmechanismen gegen Workflow-Manipulation)
**Naechstes:** #7 Kalender-App Deep Link
**Neu (User Story):** #22-26 Contextual Task Capture — siehe `docs/project/stories/contextual-task-capture.md`

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
- Push Notifications bei Frist
- Kalender-App Deep Link

### Bundle D: Erfolge feiern
- Emotionales Aufladen im Report

### Bundle E: macOS Native Experience (P2/P3)
- MAC-020 Drag & Drop Planung
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
3. CTC-3 (macOS Share Extension) — Neues Target, gleiche Funktionalitaet wie iOS
4. ~~CTC-4 (Clipboard → Task)~~ ERLEDIGT — Paste-Button in QuickCaptureView (iOS+macOS)
5. ~~CTC-5 (Watch-Diktat)~~ ERLEDIGT — needsTitleImprovement Flag im Watch-Model + saveTask()

**Kernidee:** Aus jedem Kontext (Mail, Safari, Clipboard, Diktat) mit einem Tap eine Task erstellen. KI generiert actionable Titel im Hintergrund, Original bleibt in Beschreibung erhalten.

---

## Bugs (offen)

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
- **TD-02:** iOS/macOS View-Duplikation (~9000 LoC) — Aufwand: XL, strategische Entscheidung
- **TD-03:** 4 Services ohne Unit Tests (NotificationService, TaskPriorityScoringService, FocusBlockActionService, GapFinder) — Aufwand: M

---

## Erledigte Features & Bugs (Archiv)

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
