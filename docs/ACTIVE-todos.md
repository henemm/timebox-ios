# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!

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
| 5 | MAC-022 Spotlight Integration | P2 | S | ~15-25k | 1-2 | ~30 |
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
| 23 | CTC-2: Share Extension E-Mail-Support + Deep-Link | HOCH | S | ~20-30k | 2 | ~60 |
| 24 | CTC-3: macOS Share Extension | HOCH | M | ~40-60k | neues Target | ~100 |
| 25 | CTC-4: Clipboard → Task Flow | MITTEL | S | ~15-25k | 2-3 | ~50 |
| 26 | CTC-5: Watch-Diktat Titel-Verbesserung | NICE | S | ~15-20k | 1-2 | ~30 |

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**Guenstigster Quick Win:** ~~Shake to Undo (XS)~~ ERLEDIGT
**Teuerste Items:** #17 OrganizeMyDay (~150k), #13 Drag & Drop (~150k), #14 NC Widget (~120k)
**WARTEND (Apple-Abhaengigkeit):** #20 ITB-F — Developer-APIs verfuegbar, wartet auf Siri On-Screen Awareness (iOS 26.5/27)
**Zuletzt erledigt:** #21 ITB-G — Intent Donations, Spotlight, Widget Relevance, SiriTipViews
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
- MAC-022 Spotlight Integration

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
2. CTC-2 (E-Mail-Support) — Share Extension: E-Mail Subject + Deep-Link zurueck zur Mail
3. CTC-3 (macOS Share Extension) — Neues Target, gleiche Funktionalitaet wie iOS
4. CTC-4 (Clipboard → Task) — Clipboard-Inhalt als Task-Quelle
5. CTC-5 (Watch-Diktat) — Diktierte Tasks profitieren von TaskTitleEngine

**Kernidee:** Aus jedem Kontext (Mail, Safari, Clipboard, Diktat) mit einem Tap eine Task erstellen. KI generiert actionable Titel im Hintergrund, Original bleibt in Beschreibung erhalten.

---

## Bugs (offen)

*Keine offenen Bugs.*

### ~~Bug 62: Share Extension - CloudKit Entitlements fehlen~~ (ERLEDIGT)
- **Status:** ERLEDIGT (siehe oben: "ERLEDIGT: Bug 62 — Share Extension Fixes")
- **Fixes:** CloudKit Entitlements, MARKETING_VERSION, NSItemProvider API, Fallback-Logik

---

## Backlog (Technical Debt)

### BACKLOG-001: Task Complete/Skip Divergenz (iOS vs macOS)
- **File iOS:** `Sources/Components/NextUp/NextUpFullView.swift` (markAsCompleteAndAdvance)
- **File macOS:** `FocusBloxMac/NextUpFullView+Mac.swift` (markAsCompleteAndAdvance)
- **Groesse:** ~300 LoC dupliziert
- **Risiko:** HOCH (Core-Funktionalitaet - unterschiedliche Logik = unterschiedliches Verhalten)

### BACKLOG-002: EventKitRepository Injection fehlt auf macOS
- **File iOS:** `Sources/FocusBloxApp.swift` (@State eventKitRepository injected)
- **File macOS:** `FocusBloxMac/FocusBloxMacApp.swift` (nutzt .shared statt Injection)
- **Groesse:** ~100 LoC
- **Risiko:** MITTEL (Test-Flakiness durch Singleton-State)

### BACKLOG-003: NextUp Toolbar Divergenz (iOS vs macOS)
- **File iOS:** `Sources/Components/NextUp/NextUpCompactView.swift` (Toolbar-Setup)
- **File macOS:** `FocusBloxMac/NextUpCompactView+Mac.swift` (eigene Toolbar-Logik)
- **Groesse:** ~80 LoC
- **Risiko:** NIEDRIG (UI-Anpassung plattform-spezifisch erwartet)

### BACKLOG-004: BacklogView/BacklogRow komplett dupliziert
- **File iOS:** `Sources/Components/Backlog/BacklogView.swift`, `BacklogRow.swift`
- **File macOS:** `FocusBloxMac/BacklogView+Mac.swift`, `MacBacklogRow.swift`
- **Groesse:** ~400 LoC dupliziert
- **Risiko:** MITTEL (Features landen nur auf iOS, macOS vergessen)

### BACKLOG-005: RecurrenceRuleView Divergenz
- **File iOS:** `Sources/Components/TaskEdit/Recurrence/RecurrenceRuleView.swift`
- **File macOS:** `FocusBloxMac/RecurrenceRuleView+Mac.swift`
- **Groesse:** ~150 LoC
- **Risiko:** NIEDRIG (UI-Komponente, kleine Unterschiede plausibel)

### BACKLOG-006: TaskEditView Divergenz
- **File iOS:** `Sources/Components/TaskEdit/TaskEditView.swift`
- **File macOS:** `FocusBloxMac/TaskEditView+Mac.swift`
- **Groesse:** ~200 LoC
- **Risiko:** MITTEL (Edit-Logik unterschiedlich = Inkonsistenzen)

### BACKLOG-007: SidebarView macOS-only (kein iOS Equivalent)
- **File macOS:** `FocusBloxMac/SidebarView.swift` (~400 LoC)
- **Risiko:** NIEDRIG (macOS NavigationSplitView ist plattform-spezifisch)

---

## Erledigte Features & Bugs (Archiv)

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
