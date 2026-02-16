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

### Bug 54: Wiederkehrende iCloud Termine - Kategorie-Zuordnung fehlgeschlagen
**Status:** ERLEDIGT (2026-02-15)
**Prioritaet:** MITTEL
**Gemeldet:** 2026-02-15
**Platform:** iOS + macOS (betrifft alle Plattformen)

**Symptom:** Ein wiederkehrender iCloud-Termin laesst sich keine Kategorie zuordnen. Normale (einmalige) iCloud-Termine funktionieren.

**Location:**
- `Sources/Services/EventKitRepository.swift:245-275` - `updateEventCategory()`
- `Sources/Models/CalendarEvent.swift:16` - `init(from:)` verwendet `eventIdentifier`

**Problem:**
- User tippt auf wiederkehrenden Termin, waehlt Kategorie
- Kategorie wird gespeichert (keine Fehlermeldung)
- ABER: Am naechsten Tag hat dieselbe Terminserie KEINE Kategorie mehr

**Root Cause:** EventKit verhält sich bei wiederkehrenden Events anders als bei normalen Events:

1. **eventIdentifier bei wiederkehrenden Events:**
   - MASTER Event: Hat eine ID
   - Jede OCCURRENCE (taegliche Instanz): Hat UNTERSCHIEDLICHE eventIdentifier
   - Heute 15.02.: `eventID_ABC123`
   - Morgen 16.02.: `eventID_XYZ789` (anderer Identifier!)

2. **Aktueller Code (Zeile 264):**
   ```swift
   try eventStore.save(event, span: .thisEvent)
   ```
   - `.thisEvent` speichert NUR diese EINE Occurrence
   - Notes mit Kategorie werden nur fuer 15.02. gespeichert
   - 16.02. Occurrence hat andere ID → andere Notes → keine Kategorie

3. **CalendarEvent.init (Zeile 16):**
   ```swift
   self.id = event.eventIdentifier ?? UUID().uuidString
   ```
   - Verwendet occurrence-spezifische ID (nicht stabil ueber Zeit)

**Expected vs Actual:**
- **Expected:** Kategorie gilt fuer ALLE Occurrences (taegliche Wiederholungen)
- **Actual:** Kategorie gilt NUR fuer EINE Occurrence (heute)

**Warum normale Events funktionieren:**
- Einmalige Events: eventIdentifier ist stabil, aendert sich nie
- Wiederkehrende Events: eventIdentifier wechselt bei jeder Occurrence

**Loesung:** Bei wiederkehrenden Events `.futureEvents` statt `.thisEvent` verwenden:
```swift
let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
try eventStore.save(event, span: span)
```

**Alternative (falls .futureEvents Probleme macht):**
- `calendarItemIdentifier` verwenden (stabil fuer alle Occurrences)
- ODER: iCloud Key-Value Store fuer alle wiederkehrenden Events (wie bei read-only)

**Test Plan:**
1. Wiederkehrenden Termin erstellen (taeglich, naechste 7 Tage)
2. Heute auf Termin tippen → Kategorie "income" zuordnen
3. EXPECTED: Morgen zeigt Termin AUCH "income" Badge
4. ACTUAL (Bug): Morgen zeigt Termin KEIN Badge

**Geschaetzter Aufwand:** KLEIN (~15-20k Tokens, 2-3 Dateien, ~15 LoC)
- EventKitRepository.swift: hasRecurrenceRules pruefen + span anpassen
- CalendarEvent.swift: evtl. `isRecurring` Property hinzufuegen
- Tests: Unit Test + UI Test fuer wiederkehrende Events

---

### Aufwand-Uebersicht (geschaetzte Tokens)

| # | Item | Prio | Tokens | Dateien | LoC |
|---|------|------|--------|---------|-----|
| Bug 52 | Tasks unsichtbar nach Next Up entfernen | ✅ ERLEDIGT | ~5k | 5 | ~6 |
| Bug 48 | Erweiterte Attribute geloescht | ✅ ERLEDIGT | ~80-120k | 9 | ~35 |
| Bug 50 | Kalender-Events mit Gaesten | HOCH | ~40-60k | 4 | ~80 |
| Bug 51 | Backlog-Sortierung iOS vs macOS | MITTEL | ~15-20k | 2 | ~4 |
| Bug 49 | Matrix View Layout + Gesten | MITTEL | ~25-35k | 2 | ~45 |
| Bug 22 | Edit-Button ohne Funktion | MITTEL | ~30-50k | 1-2 | ~40 |
| Feature | Next Up Long Press Preview (iOS) | MITTEL | ~10-15k | 1 | ~50 |
| Feature | Einheitliche Navigation Labels+Icons | MITTEL | ~10k | 3 | ~8 |
| Feature | Generische Suche (iOS+macOS) | MITTEL | ~15-20k | 2-3 | ~25 |
| Feature | MenuBar FocusBlock Status | HOCH | ~50-70k | 2 | ~120 |
| Feature | QuickAdd Next Up Checkbox | MITTEL | ~20-30k | 3 | ~30 |
| MAC-026 | Enhanced Quick Capture (macOS) | P2 | ~80-120k | 4 | ~200 |
| MAC-020 | Drag & Drop Planung (macOS) | P2 | ~100-150k | 3-4 | ~250 |
| MAC-021 | Review Dashboard (macOS) | P2 | ~120-180k | 4-5 | ~300 |
| MAC-022 | Spotlight Integration (macOS) | P2 | ~15-25k | 1-2 | ~30 |
| MAC-030 | Shortcuts.app (macOS) | P3 | ~60-80k | 2-3 | ~150 |
| MAC-031 | Focus Mode Integration (macOS) | P3 | ~50-70k | 2-3 | ~100 |
| MAC-032 | NC Widget (macOS) | P3 | ~80-120k | neues Target | ~200 |
| Feature | Report: Tasks ausserhalb Sprints | MITTEL | ~20-30k | 1-2 | ~40 |

> **Dies ist das EINZIGE Backlog.** macOS-Features (MAC-xxx) stehen hier mit Verweis auf ihre Specs in `docs/specs/macos/`. Kein zweites Backlog.

**Token-Logik:** Context laden + Analyse + TDD RED (Tests schreiben) + Implementation (GREEN) + Validation. Externe Dependencies und neue Targets erhoehen den Aufwand deutlich.

**Guenstigste Quick Wins:** MAC-022 (~15k), QuickAdd Next Up (~20k), Bug 49 (~25k)
**Teuerste Items:** MAC-021 Review Dashboard (~180k), MAC-020 Drag & Drop (~150k)

---

### Bug 52: Tasks verschwinden aus iOS Backlog nach Entfernen aus Next Up
**Status:** ✅ ERLEDIGT (2026-02-14)
**Prioritaet:** KRITISCH (Datenverlust - Tasks unsichtbar)
**Gemeldet:** 2026-02-14
**Platform:** iOS (macOS nicht betroffen wegen anderem Filter)

**Symptom:** Tasks die aus Next Up entfernt werden, erscheinen unter iOS nicht im Backlog. Unter macOS sichtbar.

**Root Cause:** `assignedFocusBlockID` wird nie aufgeraeumt wenn Tasks aus FocusBlocks zurueckkehren oder aus Next Up entfernt werden. iOS Backlog-Filter prueft `assignedFocusBlockID == nil`, macOS nicht.

**Fix:** `assignedFocusBlockID = nil` an 4 Stellen hinzugefuegt + einmalige Datenbereinigung beim App-Start.

---

### Bug 48: Erweiterte Attribute werden wiederholt geloescht (iOS + macOS)
**Status:** ✅ ERLEDIGT (2026-02-14)
**Commits:** `27522e8` (RC1+RC2), `16749b7` (RC3+Bug 53)
**Fix RC1:** SyncEngine.updateTask() - optionale Felder nur bei nicht-nil setzen (if let guards)
**Fix RC2:** TaskFormSheet/EditTaskSheet/TaskDetailSheet/BacklogView - Int? statt TaskPriority, .medium Fallback entfernt
**Fix RC3:** macOS Quick Capture auf LocalTaskSource.createTask() umgestellt
**Bug 53:** TaskInspector.durationChip fehlendes modelContext.save() ergaenzt

**Symptom:** Wichtigkeit, Dringlichkeit und andere erweiterte Attribute werden geloescht wenn ein Task bearbeitet wird, obwohl diese Felder NICHT geaendert werden sollten.

**Root Cause:**
- **Location:** `Sources/Services/SyncEngine.swift:72+75`
- **Problem:** `updateTask()` unterscheidet NICHT zwischen "Wert auf nil setzen" und "Wert nicht aendern"
- **Code:** `task.importance = importance` und `task.urgency = urgency` ueberschreiben IMMER, auch wenn nil
- **Trigger:** Wenn Caller `nil` fuer ein optionales Feld uebergibt (weil nicht geaendert), wird existierender Wert GELOESCHT

**Callsites (BacklogView.swift):**
- Zeile 459-469: `saveTitleEdit()` - User aendert nur Titel, uebergibt `task.importance` (kann bereits nil sein!)
- Zeile 391-395: `updateTask()` - Full Edit Dialog uebergibt Parameter-Werte (koennen nil sein)
- Zeile 407, 421, 434: `updateImportance()`, `updateUrgency()`, `updateCategory()` - gleiche Logik

**Expected vs Actual:**
- **Expected:** `updateTask(urgency: nil)` = "Feld nicht aendern"
- **Actual:** `updateTask(urgency: nil)` = "Feld auf nil setzen (loeschen)"

**Test Plan:**
1. Task mit Importance=3, Urgency="urgent" erstellen
2. Inline-Titel aendern (Quick Edit) → Expected: Attribute bleiben / Actual: Geloescht
3. Full-Edit nur Due Date aendern → Expected: Attribute bleiben / Actual: Geloescht
4. Category via Picker aendern → Expected: Attribute bleiben / Actual: Geloescht

**Fix-Strategie:**
- Option A: Optional-Felder nur setzen wenn nicht-nil (preserve-Logik in SyncEngine)
- Option B: Separate Update-Methoden fuer einzelne Felder (granularer)
- Option C: Explicitly pass "keep current value" flag oder sentinel value

**ZUSAETZLICH: VERDACHT 4 (macOS direktes SwiftData-Writing) - BESTAETIGT**

**3x GEFUNDEN: Direktes `LocalTask(title:)` ohne erweiterte Attribute**

**KRITISCH 1: QuickCapturePanel.swift:175-176**
```swift
let task = LocalTask(title: taskTitle)
modelContext.insert(task)
```
- Quick Capture (⌘⇧Space) erstellt Tasks OHNE importance/urgency/duration
- KEIN Service genutzt - direktes SwiftData-Insert
- Betroffene Attribute: importance/urgency/estimatedDuration/taskType = nil/empty

**KRITISCH 2: MenuBarView.swift:182-183**
```swift
let task = LocalTask(title: newTaskTitle)
modelContext.insert(task)
```
- Menu Bar "Task hinzufuegen" verwendet dieselbe Minimal-Initialisierung

**KRITISCH 3: ContentView.swift:486-488**
```swift
let task = LocalTask(title: newTaskTitle)
modelContext.insert(task)
try? modelContext.save()
```
- macOS ContentView "Quick Add" Funktion (3x identisches Anti-Pattern)

**UNTERSCHIED iOS vs macOS:**
- iOS: TaskFormSheet.swift:368 nutzt `LocalTaskSource.createTask()` Service
  - Uebergibt ALLE Parameter: importance, urgency, duration, taskType, tags, etc.
- macOS: 3x direktes `LocalTask(title:)` Init (nur Titel)
- **macOS nutzt NICHT die Shared Services aus `Sources/`**

**KONSEQUENZ:**
- macOS Quick Capture Tasks haben IMMER leere erweiterte Attribute
- User muss nachtraeglich in TaskInspector alle Felder ausfuellen
- Bei CloudKit-Sync: Leere Attribute ueberschreiben Werte von anderen Geraeten

**TaskInspector auf macOS: KORREKT**
- TaskInspector.swift nutzt `@Bindable var task` - editiert existierende Tasks
- Zeilen 213, 239: `task.importance =` / `task.urgency =` mit `modelContext.save()`
- Attribute werden korrekt persistiert

**Geschaetzter Aufwand:** MITTEL (~100-150 LoC, 5-6 Dateien - SyncEngine + 3x macOS Views)

---

### Bug 50: Kalender-Events mit Gaesten funktionieren nicht (iOS + macOS)
**Status:** SPEC READY
**Prioritaet:** HOCH (wiederkehrender Bug, frueherer Teilfix unvollstaendig)
**Geschaetzter Aufwand:** ~40-60k Tokens
**Gemeldet:** 2026-02-13
**Vorgeschichte:** Commit `4a5eafe` (2026-02-12) hat nur Kategorie-Zuweisung per iCloud KV Store Fallback gefixed
**Spec:** [`docs/specs/bugs/bug-50-calendar-events-with-guests.md`](../specs/bugs/bug-50-calendar-events-with-guests.md)

**Symptom:** Events mit Gaesten lassen sich nicht verschieben (Drag & Drop scheitert), keine visuelle Unterscheidung von read-only Events.

**Root Cause:** `CalendarEvent` Model kennt keinen Read-Only Status. Events mit Attendees sind in EventKit schreibgeschuetzt, aber die App behandelt alle Events als editierbar.

**Betroffene Stellen:**
- `CalendarEvent.swift:13-21` - Model fehlt `hasAttendees`/`isReadOnly`
- `EventKitRepository.swift:221-238` - `moveCalendarEvent()` hat kein Error-Handling fuer read-only
- `EventBlock.swift:48` - `.draggable()` auf ALLEN Events (auch read-only)
- `MacTimelineView.swift:96-107` - Gleiche Problematik auf macOS

**Fix:** Model erweitern, Drag nur fuer editierbare Events, spezifische Fehlermeldungen, Schloss-Icon fuer read-only Events.

---

### BACKLOG-003: defaultTaskDuration synct nicht
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** MITTEL
**Dateien:** `AppSettings.swift`, `SettingsView.swift`, `SyncedSettings.swift`
**Fix:** Property in `AppSettings`, Picker auf iOS, iCloud KV Store Sync. Commit `0d0b0e2`.

---

### BACKLOG-004: Timer-Berechnungen dupliziert
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** `TimerCalculator` enum in `Sources/Services/` extrahiert. Beide Views delegieren jetzt an Shared-Logik.

---

### BACKLOG-005: Date-Formatter dupliziert (4x)
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** `timeRangeText` als computed property auf `FocusBlock` Extension. 4 private Duplikate entfernt.

---

### BACKLOG-006: Color Hex Extension dupliziert
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** `Color.init(hex:)` Extension nach `Sources/Extensions/Color+Hex.swift` extrahiert. Duplikate aus SettingsView + MacSettingsView entfernt.

---

### BACKLOG-007: Review-Komponenten dupliziert (StatItem, CategoryBar, AccuracyPill)
**Status:** ✅ ERLEDIGT (2026-02-13)
**Fix:** `ReviewComponents.swift` ins Xcode-Projekt registriert. 8 Duplikate in 5 Dateien entfernt (DailyReviewView, SprintReviewSheet, MacFocusView, MacReviewView, BlockPlanningView). macOS auf shared CategoryStat/CategoryBar umgestellt.

---

### BACKLOG-008: Hardcoded Category-Switches statt TaskCategory enum
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** HOCH
**Fix:** TaskCategory um `.localizedName` (deutsch) erweitert. 3 Dateien auf Enum-Delegation umgestellt: `TaskFormSheet.swift`, `QuickCaptureSnippetView.swift` (3 Icons + 3 Farben korrigiert), `MacBacklogRow.swift` CategoryBadge (2 Icons korrigiert). 7 Regressions-Tests in `TaskCategoryTests.swift`.

---

### BACKLOG-009: Importance/Urgency Badge-Logik dupliziert
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** MITTEL
**Fix:** `ImportanceUI` + `UrgencyUI` Enums in `Sources/Helpers/TaskMetadataUI.swift` extrahiert. 5 Dateien auf Shared-Helper umgestellt: `BacklogRow.swift`, `MacBacklogRow.swift`, `QuickCaptureView.swift`, `QuickCaptureSnippetView.swift`, `TaskFormSheet.swift`. 12 Regressions-Tests in `TaskMetadataUITests.swift`.

---

### BACKLOG-010: Due Date Formatting dupliziert (3x)
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** MITTEL
**Fix:** `Date.dueDateText(style:)` + `Date.isDueToday` Extension in `Sources/Extensions/Date+DueDate.swift`. Compact-Style (EEE/.short) fuer BacklogRow/MacBacklogRow, Full-Style (EEEE/.medium) fuer TaskDetailSheet. 3 private Duplikate entfernt. 12 Regressions-Tests (vorher + nachher GREEN) in `DueDateFormattingTests.swift`.

---

### BACKLOG-011: Settings-Komponenten dupliziert (CalendarRow, ReminderListRow, Bindings)
**Status:** ✅ ERLEDIGT (2026-02-13)
**Prioritaet:** NIEDRIG
**Fix:** `CalendarRow`, `ReminderListRow` + `setMembershipBinding(for:in:)` in `Sources/Views/Components/SettingsComponents.swift` extrahiert. MacCalendarRow/MacReminderListRow + 2x Binding-Funktionen aus beiden Settings-Views entfernt. 8 Regressions-Tests in `SettingsComponentsTests.swift`.

---

### BACKLOG-012: Settings Load/Save Logik dupliziert
**Status:** WON'T FIX (2026-02-13)
**Prioritaet:** NIEDRIG
**Dateien:** `MacSettingsView.swift`, `SettingsView.swift`
**Analyse:** Trotz aehnlicher Struktur sind die Funktionen NICHT identisch dupliziert:
- iOS `loadCalendars()` ist synchron, macOS `loadData()` ist async mit Permission-Checks
- macOS hat extra `requestCalendarAccess()`/`requestReminderAccess()` Methoden
- Save-Trigger unterschiedlich (Button vs onChange), `.synchronize()` nur auf iOS
- Extrahierbarer Teil (~20 LoC UserDefaults read/write) rechtfertigt keinen Shared Service
**Fazit:** Echte Duplikation war in den Komponenten (BACKLOG-011), nicht in der Load/Save-Logik.

---

### Feature: MenuBar FocusBlock Status (macOS)
**Status:** SPEC READY
**Prioritaet:** HOCH
**Geschaetzter Aufwand:** ~50-70k Tokens
**Spec:** `openspec/changes/menubar-focusblock-status/proposal.md`
**Dateien:** `MenuBarView.swift`, `FocusBloxMacApp.swift`
**Problem:** Auf macOS gibt es kein Aequivalent zur iOS Live Activity. Der Nutzer muss das Hauptfenster oeffnen, um den FocusBlock-Status zu sehen.
**Loesung:** Menu Bar Label zeigt Restzeit (mm:ss), Popover bekommt Focus Section mit aktuellem Task, Timer, Fortschritt und Complete/Skip Buttons.
**Scope:** ~120 LoC, 2 Dateien

---

### Feature: Wiederkehrende Tasks - Darstellung + Instanz-Logik (iOS + macOS)
**Status:** OFFEN - ANALYSE FERTIG
**Prioritaet:** HOCH
**Analysiert:** 2026-02-13
**Context:** [`docs/context/bug-48-extended-attributes-deleted.md`](../context/bug-48-extended-attributes-deleted.md)

**Problem:** Recurrence-Pattern wird gespeichert, aber nirgends aktiv genutzt. Keine Instanz-Generierung, keine Filterung nach Faelligkeit, kein visuelles Feedback, keine Instanz-vs-Serie-Logik bei Complete/Delete.

**Geplante Phasen:**
1. Template/Instanz-Modell + Visueller Indikator + Completion-Logik (~200 LoC)
2. Backlog-Filterung (faellig vs. nicht-faellig) + eigener Bereich (~150 LoC)
3. Delete-Logik (Instanz vs. Serie) + Confirmation Dialog (~150 LoC)

**Betroffene Bereiche:** LocalTask Model, SyncEngine, BacklogView, BacklogRow, macOS Views

---

### Feature: QuickAdd "Next Up" Checkbox (iOS + macOS)
**Status:** SPEC READY
**Prioritaet:** MITTEL
**Geschaetzter Aufwand:** ~20-30k Tokens
**Spec:** `openspec/changes/quickadd-nextup-checkbox/proposal.md`
**Dateien:** `QuickCaptureView.swift`, `QuickCapturePanel.swift`, `MenuBarView.swift`
**Problem:** Tasks koennen beim Quick-Add nicht direkt als "Next Up" markiert werden - Umweg ueber Backlog noetig.
**Loesung:** Toggle-Button in allen 3 Quick-Add-Flows (iOS + 2x macOS). ~30 LoC netto.

---

### Feature: Report zeigt Tasks ausserhalb von Sprints (iOS + macOS)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Geschaetzter Aufwand:** ~20-30k Tokens
**Gemeldet:** 2026-02-14
**Dateien:** `DailyReviewView.swift` (+ macOS-Aequivalent falls vorhanden)

**Problem:** Tasks, die ausserhalb eines aktiven FocusBlocks abgehakt werden (z.B. im Backlog), erscheinen nicht im Tagesreport. Der Report zeigt nur Tasks, deren ID in `block.completedTaskIDs` steht.

**Gewuenschtes Verhalten:** Alle am Tag erledigten Tasks sollen im Report sichtbar sein - auch solche, die ohne laufenden Sprint abgehakt wurden.

**Loesung:** Eigene Sektion im Report, z.B. "Ausserhalb von Sprints erledigt". Filtert `allTasks` nach `isCompleted == true` UND `completedAt` am aktuellen Tag, ABER Task-ID NICHT in irgendeinem `block.completedTaskIDs` des Tages enthalten.

**Scope:** ~40 LoC, 1-2 Dateien

---

### Bug 51: Backlog-Liste sortiert unterschiedlich auf iOS und macOS
**Status:** ✅ ERLEDIGT (2026-02-15)
**Prioritaet:** MITTEL
**Geschaetzter Aufwand:** ~15-20k Tokens
**Gemeldet:** 2026-02-13
**Analysiert:** 2026-02-13
**Spec:** [`docs/specs/bugs/bug-51-backlog-list-sorting.md`](../specs/bugs/bug-51-backlog-list-sorting.md)

**Symptom:** Backlog "Liste" zeigt auf iOS aelteste Tasks oben, auf macOS neueste oben. Gewuenscht: Neueste oben auf beiden Plattformen.

**Root Cause:**
- **iOS:** `LocalTaskSource.swift:38` sortiert nach `sortOrder` aufsteigend (aelteste oben)
- **iOS:** `SyncEngine.swift:18` sortiert nochmal nach `rank` aufsteigend
- **macOS:** `ContentView.swift:36` sortiert nach `createdAt` absteigend (neueste oben, korrekt)
- Plattformen nutzen komplett unterschiedliche Sortierlogik (verschiedene Felder + Richtung)

**Fix:** iOS-Sortierung auf `createdAt` absteigend umstellen (wie macOS). 2 Dateien, ~4 LoC.

---

### Bug 49: Matrix View - Swipe-Gesten + Layout zu breit (iOS)
**Status:** SPEC READY
**Prioritaet:** MITTEL
**Geschaetzter Aufwand:** ~25-35k Tokens
**Gemeldet:** 2026-02-13
**Spec:** [`docs/specs/bugs/bug-49-matrix-view-layout-gestures.md`](../specs/bugs/bug-49-matrix-view-layout-gestures.md)
**Dateien:** `BacklogView.swift`, `BacklogRow.swift`

**Problem 1:** Swipe-Gesten (Next Up, Bearbeiten, Loeschen) funktionieren nicht in der Matrix-Ansicht.
- **Root Cause:** `.swipeActions()` ist List-only Modifier. Matrix nutzt ScrollView/VStack.
- **Fix:** `.contextMenu` auf BacklogRow in QuadrantCards (Long-Press statt Swipe).

**Problem 2:** View zu breit - Inhalt geht ueber Bildschirmrand hinaus.
- **Root Cause:** Metadata-Badges in BacklogRow haben alle `.fixedSize()`. Bei vielen Badges ueberlaeuft die HStack.
- **Fix:** `.fixedSize()` von komprimierbaren Badges entfernen + `.clipped()` als Sicherheitsnetz.

**Geschaetzter Aufwand:** ~45 LoC, 2 Dateien

---

### Bug 22: Edit-Button in Backlog Toolbar ohne Funktion
**Status:** OFFEN
**Geschaetzter Aufwand:** ~30-50k Tokens
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

### Bug 55: FocusBlox-Session zeigt falsche Timer, Notifications und Sprint Review
**Status:** ✅ ERLEDIGT (2026-02-15)
**Commit:** `0de32f1`
**Platform:** iOS + macOS

**5 Sub-Bugs gefixed:**
- **55A:** Timer/Live Activity Countdown ueberschritt Block-Ende (TimerCalculator clamp auf blockEndDate)
- **55B:** End-Notification zeigte "0/0 Tasks erledigt" (Notification bei Task-Complete/Skip neu planen)
- **55C:** Sprint Review zeigte "0m gebraucht" (Task-Zeit in checkBlockEnd() speichern vor Review)
- **55D:** Sprint Review zeigte "120m geplant" statt Block-Dauer (min(taskSum, blockMinutes))
- **55E:** Doppelte Live Activities nach Block-Ende (Orphan-Cleanup in startActivity())

**Betroffene Dateien:** TimerCalculator.swift, FocusLiveView.swift, MacFocusView.swift, SprintReviewSheet.swift, LiveActivityManager.swift

---

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
**Status:** ✅ ERLEDIGT (2026-02-14)
**Fix 1:** FocusBlocks aus ALLEN Kalendern laden (nicht nur sichtbare) - `49f5f9c`
**Fix 2:** SyncedSettings mit iCloud Key-Value Store - `49f5f9c`
**Fix 3:** CloudKitSyncMonitor + Feld-Migration (V2 nur non-nil) - `165a2b1`
**Fix 4:** Race Condition: `modelContext.save()` vor Fetch + 200ms Delay nach RemoteChange - `5946410`
**Root Cause Fix 4:** `eventChangedNotification` feuert bevor Daten im ModelContext verfuegbar. `save()` erzwingt Context-Merge.

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
