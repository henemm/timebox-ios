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

## 🔴 OFFEN - Neue Bugs/Features

### Bug 20: QuickCapture Metadaten-Buttons nicht sichtbar (Tastatur verdeckt)
**Status:** ✅ ERLEDIGT (2026-02-02)
**Gemeldet:** 2026-02-02
**Location:** `Sources/Views/QuickCaptureView.swift`

**Problem:**
- Metadaten-Buttons wurden von Tastatur verdeckt
- Sheet-Höhe `.fraction(0.4)` zu klein

**Fix:**
1. VStack in ScrollView gewrappt mit `.scrollDismissesKeyboard(.interactively)`
2. Sheet-Detent von `.fraction(0.4)` auf `.medium` erhöht
3. UI Test-Koordinaten angepasst

**Priorität:** HOCH (Feature existiert aber unsichtbar) - GEFIXT

---

### Bug 19: Wiederkehrende Aufgaben Feature fehlt in TaskFormSheet
**Status:** OFFEN
**Gemeldet:** 2026-02-02
**Location:** `Sources/Views/TaskFormSheet.swift`

**Problem:**
- Das Feature "Wiederkehrende Aufgaben" ist im TaskFormSheet nicht vorhanden
- Screenshot zeigt: Tags-Feld mit "Wiederkehrend" als Workaround, aber keine echte Recurrence-UI
- Das Feature existiert in `CreateTaskView.swift` (Zeile 138-174), wurde aber nicht in TaskFormSheet übernommen

**Bestehende Komponenten (ungenutzt):**
- `RecurrencePattern.swift` - Enum: none, daily, weekly, biweekly, monthly
- `WeekdayButton.swift` - UI für Wochentag-Auswahl (Mo-So Kreise)
- `LocalTask` hat Felder: `recurrencePattern`, `recurrenceWeekdays`, `recurrenceMonthDay`

**Was fehlt in TaskFormSheet:**
1. State-Variablen: `recurrencePattern`, `selectedWeekdays`, `monthDay`
2. UI-Section für Wiederholung (Picker + Wochentag-Buttons)
3. Übergabe an `createTask()` - aktuell hardcoded `"none"` (Zeile 392)
4. Edit-Mode: Recurrence-Werte aus PlanItem laden

**Best Practice Verbesserung (zusätzlich):**
- "Werktags"-Preset (Mo-Fr) als Schnellauswahl hinzufügen
- Wie Apple Reminders: Picker + optionale Wochentage

**Betroffene Dateien für Fix:**
- `Sources/Views/TaskFormSheet.swift` (~50 LoC)

**Priorität:** MITTEL (Feature existiert, nur UI fehlt)

---

### Bug 18: Reminders-Tasks - Dringlichkeit/Wichtigkeit nicht speicherbar
**Status:** ✅ TEILWEISE GEFIXT (2026-02-02)
**Gemeldet:** 2026-02-01
**Location:**
- `RemindersSyncService.swift:116-124`
- `BacklogView.swift:380-400`
- `BacklogRow.swift:245`

**Problem:**
1. Bei Tasks aus Apple Reminders: Tippen auf Dringlichkeit/Wichtigkeit Badge setzt Wert nicht
2. View springt nach oben nach jedem Tap
3. In Full Edit: Dringlichkeit setzen + Speichern - Wert wird nicht persistiert

**Root Cause Analyse:**

| RC | Problem | Status |
|----|---------|--------|
| RC1 | RemindersSyncService überschreibt importance | ✅ War bereits gefixt (prüft auf nil) |
| RC2 | loadTasks() triggert Re-Import | ✅ War bereits gefixt (refreshLocalTasks() wird verwendet) |
| RC3 | isLoading resettet Scroll | ✅ Nur bei loadTasks(), nicht refreshLocalTasks() |
| RC4 | nil urgency → "" String | ✅ **GEFIXT** |

**Fix RC4 (2026-02-02):**
- BacklogRow: `onUrgencyToggle: ((String?) -> Void)?` statt `((String) -> Void)?`
- BacklogRow: `onUrgencyToggle?(newUrgency)` statt `onUrgencyToggle?(newUrgency ?? "")`
- BacklogView: `updateUrgency(for:urgency:)` nimmt jetzt `String?`
- QuadrantSection: Callback-Signatur angepasst

**Prioritaet:** HOCH - Teilweise gefixt, manueller Test auf Device empfohlen

---

### Bug 22: Edit-Button in Backlog Toolbar ohne Funktion
**Status:** OFFEN
**Gemeldet:** 2026-02-02
**Location:** `Sources/Views/BacklogView.swift:218`

**Problem:**
- Der `EditButton()` in der Backlog-Toolbar ist sichtbar, hat aber keine Funktion
- Tap auf "Bearbeiten" zeigt "Fertig" an, aber nichts passiert
- Keine Drag-Handles erscheinen, Tasks können nicht verschoben werden

**Root Cause:**
- `EditButton()` existiert (Zeile 218), aber `List` hat keinen `.onMove` Handler
- Ohne `.onMove` kann SwiftUI keine Drag-Reorder-Funktion aktivieren
- Der Edit-Mode wird zwar umgeschaltet, aber es gibt keine sichtbare Änderung

**Spec-Anforderung (timebox-project-spec.md):**
> "Manual Reordering: Users must be able to drag rows up/down. On move, update TaskMetadata.sortOrder"

**Fix erfordert:**
1. `.onMove(perform:)` Handler zu List hinzufügen
2. `reorderTasks(_:)` Funktion implementieren
3. `TaskMetadata.sortOrder` bei Move aktualisieren
4. Optional: Drag-Handles für bessere UX

**Betroffene Dateien:**
- `Sources/Views/BacklogView.swift` (~30 LoC)
- `Sources/Services/SyncEngine.swift` (neue Methode `updateSortOrder`)

**Priorität:** MITTEL (Feature existiert in UI, tut aber nichts)

---

### Bug 21: Tags-Eingabe ohne Autocomplete und Vorschläge
**Status:** OFFEN
**Gemeldet:** 2026-02-02
**Location:** `Sources/Views/EditTaskSheet.swift:70`, `Sources/Views/TaskFormSheet.swift`

**Problem:**
- Tags-Feld ist ein einfaches `TextField` mit Komma-Trennung
- Bestehende/häufig verwendete Tags werden nicht vorgeschlagen
- Keine Autocomplete-Funktion bei Eingabe
- Kein schneller Zugriff auf bereits verwendete Tags

**Expected:**
1. Häufig verwendete Tags als auswählbare Chips über dem Textfeld anzeigen
2. Autocomplete bei Eingabe (bestehende Tags vorschlagen)
3. Eingegebene Tags als Chips darstellen (statt Komma-getrennter Text)
4. Tap auf Chip → Tag entfernen

**Betroffene Dateien:**
- `Sources/Views/EditTaskSheet.swift` (~100 LoC)
- `Sources/Views/TaskFormSheet.swift` (~50 LoC)
- Neuer View: `Sources/Views/TagInputView.swift` (~150 LoC)

**Scope:** Mittel (neuer Component + 2 Integrationen)

**Priorität:** NIEDRIG

---

### Bug 17: BacklogRow - Touchbare Elemente nicht als Chips (Spec-Abweichung)
**Status:** OFFEN
**Gemeldet:** 2026-01-29
**Location:** `BacklogRow.swift`
**Spec:** `docs/specs/features/backlog-row-redesign.md`

**Problem:**
- Spec definiert Badges in Metadaten-Zeile für: Wichtigkeit, Dringlichkeit, Kategorie, Tags, Duration, Due
- "Dauer" ist als Chip mit klarer Touch-Zone implementiert
- Andere touchbare Elemente (Wichtigkeit, Dringlichkeit, Kategorie) sind NICHT als Chips
- Inkonsistentes UI, Touch-Zonen unklar

**Expected (gemäß Spec):**
- Alle touchbaren Badges einheitlich als Chips
- Klare visuelle Affordance für Touch-Interaktion

**Priorität:** MITTEL

---

### Bug 16: Focus Tab - Weitere Tasks nicht sichtbar / kein "keine weiteren Tasks" Hinweis
**Status:** OFFEN
**Gemeldet:** 2026-01-29
**Location:** `FocusLiveView.swift`

**Problem:**
- Während Focus Modus: Weitere Tasks im Block nicht sichtbar
- Oder: Kein Hinweis wenn keine weiteren Tasks vorhanden sind

**Expected:**
- Liste der kommenden Tasks sichtbar (z.B. "Nächste: Task A, Task B")
- Oder: "Keine weiteren Tasks" Hinweis wenn Block leer/fertig

**Priorität:** MITTEL

---

### Bug 15: Focus Tab - "Überspringen" startet gleichen Task erneut
**Status:** ✅ ERLEDIGT (2026-01-30)
**Gemeldet:** 2026-01-29
**Location:** `FocusLiveView.swift` - `skipTask()` Funktion

**Problem:**
- Focus Blox mit nur 1 verbleibendem Task
- "Überspringen" tappen → gleicher Task startet erneut (Endlosschleife)

**Root Cause:**
- `skipTask()` verschiebt Task ans Array-Ende
- Bei nur 1 verbleibendem Task: Array bleibt identisch → Loop

**Fix (2026-01-30):**
- Prüfung auf `remainingTaskIDs.count == 1`
- Wenn letzter Task: Als "completed" markieren statt verschieben
- → "Alle Tasks erledigt!" erscheint korrekt

**UI Tests:** `SkipTaskLoopUITests.swift` (2 Tests bestanden)

**Priorität:** HOCH (Core Feature - GEFIXT)

---

### Bug 14: Assign Tab - Next Up nicht sichtbar bei mehreren Blox
**Status:** OFFEN
**Gemeldet:** 2026-01-29
**Location:** `TaskAssignmentView.swift`
**Screenshot:** Downloads/Bildschirmfoto 2026-01-29 um 23.03.21.png

**Problem:**
- Bei mehreren Focus Blox füllen die Karten den ganzen Screen
- "Next Up" Section ist kaum/nicht sichtbar (abgeschnitten)
- Screen ist nicht scrollbar

**Expected:**
- Gesamter Screen scrollbar ODER
- Focus Blox Karten sind expandierbar/collapsible (besser)

**Zusätzlich:** "Focus Block" → "Focus Blox" umbenennen (Branding)

**Priorität:** HOCH

---

### Bug 13: Blox Tab zeigt keine Block-Details
**Status:** ✅ ERLEDIGT (2026-01-29)
**Gemeldet:** 2026-01-29
**Location:** `BlockPlanningView.swift` - `existingBlocksSection`

**Problem:**
- "Today's Blox" zeigt nur Header + Zähler (z.B. "3")
- Die einzelnen Focus Blocks werden NICHT angezeigt

**Root Cause:**
- `List` innerhalb eines `ScrollView` funktioniert nicht in SwiftUI - die List-Items werden nicht gerendert

**Fix:**
- `List` → `LazyVStack(spacing: 8)` ersetzt
- `swipeActions` → `contextMenu` ersetzt (LazyVStack unterstützt keine Swipe Actions)

**Verifikation:** Visuell auf Device bestätigen

**Priorität:** HOCH (Core Feature kaputt)

---

## Themengruppe A: Next Up Layout (Horizontal → Vertikal)

> **3 Stellen mit gleichem Bug:** ScrollView horizontal statt VStack vertikal

| ID | Location | Status |
|----|----------|--------|
| Bug 2 | `NextUpSection.swift:38` | ERLEDIGT (bereits VStack) |
| Bug 4 | `TaskAssignmentView.swift:108` | ERLEDIGT (bereits VStack) |
| Task 5 | `FocusLiveView.swift:370` (upcomingTasksView) | ERLEDIGT (2026-01-25) |

**Gemeinsamer Fix:** `ScrollView(.horizontal)` → `VStack` mit Task-Rows
**Status:** ✅ Alle 3 Stellen gefixt

---

## Themengruppe B: Next Up State Management

> **Tasks erscheinen/verschwinden falsch**

**Bug 1: Tasks bleiben in Quadranten sichtbar wenn in Next Up** ✅
- Location: `BacklogView.swift:70-84, 88, 99, 115, 130+`
- Problem: Filter pruefen nur `!isCompleted`, nicht `!isNextUp`
- Fix: `&& !$0.isNextUp` zu allen Filtern hinzugefuegt
- Status: ERLEDIGT (bereits implementiert)

**Bug 5: Tasks erscheinen nicht im Focus Block nach Zuordnung** ✅
- Location: `TaskAssignmentView.swift:157, 170-175`
- Problem: Nach Zuordnung `isNextUp=false` → Task aus `unscheduledTasks` raus → `tasksForBlock()` findet ihn nicht
- Fix: Separate `allTasks` State-Variable fuer Block-Anzeige implementiert
- Status: ERLEDIGT (bereits implementiert)

**Bug 6: Task kehrt nicht zu Next Up zurueck nach Block-Entfernung** ✅
- Location: `TaskAssignmentView.swift:216-219`
- Problem: `removeTaskFromBlock()` setzte `isNextUp` nicht zurueck auf `true`
- Fix: `try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)` hinzugefuegt
- Commit: `d0fdcf1` (2026-01-18)
- Status: ERLEDIGT

**Status:** ✅ Alle Bugs gefixt

---

## Themengruppe C: Drag & Drop Sortierung

> **Voraussetzung:** ✅ Datenmodell-Erweiterung (`nextUpSortOrder` Property) - ERLEDIGT (2026-01-26)

**Task 1: Drag & Drop in Next Up Section** ✅
- User soll Tasks in Next Up per Drag & Drop sortieren
- Datenmodell: `LocalTask.nextUpSortOrder: Int?` + `PlanItem.nextUpSortOrder`
- SyncEngine: `updateNextUpSortOrder(for:)` Methode hinzugefuegt
- UI: `NextUpSection` mit `.draggable()` + `.dropDestination()` erweitert
- Drag Handle Icon hinzugefuegt, visuelles Feedback bei Drag
- Status: **ERLEDIGT** (2026-01-26)

**Task 2: Task-Sortierung in Focus Block** ✅
- User soll Tasks innerhalb eines Focus Blocks sortieren
- `taskIDs` Array existiert bereits → Reihenfolge = Array-Index
- Implementation: `FocusBlockCard` nutzt `List` + `.onMove` + `.editMode(.active)`
- Status: **BEREITS IMPLEMENTIERT** (Code existiert in TaskAssignmentView.swift)

---

## Themengruppe D: Quick Task Capture

> **4 Wege zur schnellen Task-Erfassung**

| ID | Feature | Status | Prioritaet |
|----|---------|--------|------------|
| Task 7 | Control Center Fix (OpenURLIntent kaputt) | ERLEDIGT | **HOCH** |
| Task 7b | Compact QuickCaptureView | ERLEDIGT | Mittel |
| Task 8 | Home Screen Widget | OFFEN | Mittel |
| Task 9 | Control Center Inline-Eingabe (iOS 26+) | OFFEN | Niedrig |
| Task 10 | Siri Shortcut funktionsfaehig | OFFEN | Mittel |

**Task 7 (Control Center Fix)** ✅ ERLEDIGT (2026-01-25)
- Root Cause: `OpenURLIntent` blockiert custom URL schemes
- Fix: `openAppWhenRun = true` + NotificationCenter
- Commit: `a84bfa8`
- Status: ERLEDIGT (manueller Test auf Device erforderlich)

**Task 7b (Compact QuickCaptureView)** ✅ ERLEDIGT (2026-01-25)
- Ziel: Minimales UI fuer schnellere Task-Erfassung
- Aenderungen:
  - NavigationStack + Toolbar entfernt
  - Half-Sheet statt Fullscreen (`.presentationDetents([.medium])`)
  - Swipe-Down zum Schliessen (kein Abbrechen-Button)
  - Nur Textfeld + Speichern-Button
  - Tastatur sofort fokussiert (beibehalten)
- Betroffene Dateien: `QuickCaptureView.swift`, `FocusBloxApp.swift`
- Tests: 10 UI Tests bestanden
- Status: ERLEDIGT

**Task 8 (Home Screen Widget)** ✅ ERLEDIGT (2026-01-26)
- Neues `StaticConfiguration` Widget erstellt
- Tap → App mit QuickCaptureView via `focusblox://create-task`
- Unterstützte Größen: systemSmall, systemMedium
- Neue Datei: `FocusBloxWidgets/QuickCaptureWidget.swift`

**Task 9 (Control Center Inline)**
- Voraussetzung: Task 7 gefixt
- iOS 18+ interaktives Control mit Textfeld
- Scope: Gross + Research

**Task 10 (Siri Shortcut)** ✅ ERLEDIGT (2026-01-26)
- Intent oeffnet jetzt App + zeigt QuickCaptureView
- `openAppWhenRun = true` + NotificationCenter (wie Control Center Widget)
- Siri Phrases: "Erstelle einen Task in FocusBlox", "Neuer Task in FocusBlox"
- Geaenderte Datei: `FocusBloxCore/QuickAddTaskIntent.swift`

---

## Themengruppe E: Focus Block Ausfuehrung

> **Live Activity, Timer, Notifications waehrend Focus Block**

**Bug 10: Dynamic Island Layout falsch** ✅
- Problem: Zu breit, falsches Layout-Pattern
- Fix implementiert:
  1. **Overlay-Trick** in compactTrailing (hidden "00:00" placeholder)
  2. Explizite frame sizes für Icons (20x20 compact, 18x18 minimal, 52x52 expanded)
  3. ZStack mit Circle-Background für konsistentes Icon-Styling
  4. Proper padding (.leading, .trailing, .vertical)
- Location: `FocusBloxWidgets/FocusBlockLiveActivity.swift`
- Status: **ERLEDIGT** (2026-01-26) - Visuell im Simulator verifiziert ✅

**Task 4: Live Activity zeigt Task-Restzeit statt Block-Restzeit** ✅
- Aktuell: Countdown fuer gesamten Block
- Expected: Countdown fuer aktuellen Task
- Implementation (2026-01-26):
  - `FocusBlockActivityAttributes.ContentState.taskEndDate: Date?` hinzugefuegt
  - `LiveActivityManager` berechnet und uebergibt taskEndDate
  - `FocusBlockLiveActivity` nutzt taskEndDate wenn verfuegbar (Fallback: Block-Ende)
  - Timer zeigt jetzt Restzeit fuer aktuellen Task
- Betroffene Dateien: FocusBloxCore/FocusBlockActivityAttributes.swift, LiveActivityManager.swift, FocusLiveView.swift, FocusBlockLiveActivity.swift
- Status: **ERLEDIGT**

**Task 3: Push-Notification bei Focus Block Start** ✅ ERLEDIGT (2026-01-27)
- Notification 5 Min vor Block-Start (oder bei Start wenn < 5 Min)
- `NotificationService.scheduleFocusBlockStartNotification()` + `cancelFocusBlockNotification()`
- Integration: BlockPlanningView (Erstellung, Aenderung, Loeschung)
- Testbar via `buildFocusBlockNotificationRequest()` (5 Unit Tests)
- Status: **ERLEDIGT**

**Task 11: Task-Timer Ablauf - Overdue Handling** ✅ ERLEDIGT (2026-01-25)
- Implementiert:
  1. Push-Notification bei Task-Zeitablauf ("Zeit für [Task] abgelaufen")
  2. Buttons: "Erledigt" (grün) / "Überspringen" (orange)
  3. Overdue: Timer rot, "Zeit abgelaufen" Text, Erinnerung alle 2 Min
- Neue Dateien:
  - `Sources/Services/NotificationService.swift` - Push-Notification Service
- Geänderte Dateien:
  - `Sources/Views/FocusLiveView.swift` - Overdue UI + skipTask()
  - `Sources/FocusBloxApp.swift` - Notification-Permission anfordern
- Status: ERLEDIGT

---

## Themengruppe F: Sprint Review

**Task 12a: Zeit-Tracking Grundlage** ✅
- Implementiert: Datenmodell für tatsaechliche Zeit pro Task
- `FocusBlock.taskTimes: [String: Int]` - Sekunden pro Task
- Zeit wird bei Task-Wechsel automatisch gespeichert
- Notes-Format: `times:taskId=120|taskId2=90`
- Status: **ERLEDIGT** (2026-01-26)

**Task 12b: Sprint Review UI** ✅
- Abhaengigkeit: Task 12a ✅
- Implementiert:
  1. Pro Task: "X min geplant" + "Y min gebraucht" mit Differenz-Indikator
  2. Tasks als erledigt/unerledigt umschaltbar (Tap auf Checkbox)
  3. Stats Header mit "gebraucht" Spalte
- Scope: 1 Datei, ~100 LoC
- Status: **ERLEDIGT** (2026-01-26)

---

## Einzelne Bugs

**Bug 12: Kategorie-System inkonsistent** ✅
- Location: `TaskFormSheet.swift:76-87`, `EditTaskSheet.swift:25-36`, `BacklogView.swift:83-89`, `TaskDetailSheet.swift:42-56`
- Problem: UI zeigt 10 Kategorien, Spec definiert 5+1, BacklogView Gruppierung nutzt nur 6 Work-Types
- Root Cause: Zwei Konzepte vermischt (Lebensarbeit vs Work-Type)
- Entscheidung: **Option A - Spec folgen** (nur 5+1 Lebensarbeit-Kategorien)
- Fix (2026-01-26):
  1. `TaskFormSheet.swift` - taskTypeOptions auf 5 reduziert
  2. `EditTaskSheet.swift` - taskTypeOptions auf 5 reduziert + Icons hinzugefuegt
  3. `BacklogView.swift` - categories Array und Lokalisierung angepasst
  4. `TaskDetailSheet.swift` - categoryText angepasst
- Scope: 4 Dateien, ~-50 LoC
- Status: **ERLEDIGT**

**Bug 11: Pull-to-Refresh bewegt nicht den kompletten Inhalt (nur Backlog)** ✅
- Location: `BacklogView.swift` (alle View-Modes)
- Problem: NextUpSection war ausserhalb des scrollbaren Containers
- Fix (2026-01-26):
  1. `NextUpSection` aus aeusserem VStack entfernt
  2. `NextUpSection` IN jeden View-Mode verschoben (List-Section bzw. ScrollView-Content)
  3. Redundanten `.refreshable` Modifier entfernt
- Betroffene Views: listView, eisenhowerMatrixView, categoryView, durationView, dueDateView, tbdView
- UI Tests: PullToRefreshUITests.swift erstellt
- Status: **ERLEDIGT**

**Bug 7: Scrolling innerhalb Focus Block nicht moeglich** ✅
- Location: `TaskAssignmentView.swift:316-333`
- Problem: `.scrollDisabled(true)` bei 6+ Tasks
- Fix: `.scrollDisabled(true)` wurde entfernt, Code verwendet jetzt `maxHeight: 264`
- Analyse (2026-01-26): Der Bug scheint bereits gefixt - `.scrollDisabled(true)` existiert nicht mehr im Code
- ScrollingUITests bestehen (Tests mit 7+ Tasks werden wegen fehlender Mock-Daten uebersprungen)
- Status: WAHRSCHEINLICH ERLEDIGT - Verifikation auf Device empfohlen

**Bug 9: Bloecke-Tab zeigt vergangene Zeitslots** ✅
- Location: `BlockPlanningView.swift` (GapFinder)
- Fix: `findFreeSlots()` und `createDefaultSuggestions()` filtern jetzt nach aktueller Zeit
- Status: ERLEDIGT (2026-01-24)

---

## Erledigt

**Task 6: Volle Editierbarkeit fuer importierte Reminders** ✅
- Problem: Importierte Tasks aus Apple Erinnerungen hatten eingeschraenkte Editieroptionen
- Loesung: EditTaskSheet um alle Felder erweitert (Tags, Dringlichkeit, Typ, Faelligkeitsdatum, Beschreibung)
- Files: EditTaskSheet.swift, TaskDetailSheet.swift, BacklogView.swift, SyncEngine.swift, FocusBloxApp.swift
- Status: ERLEDIGT (2026-01-24)

**Bug 8: Kalender-/Erinnerungen-Berechtigung wird nicht abgefragt** ✅
- Fix: `requestPermissionsOnLaunch()` in `FocusBloxApp.onAppear`
- Status: ERLEDIGT (2026-01-24)

---

## Themengruppe G: BacklogRow Redesign (29.01.2026)

> **Glass Card Layout mit neuen Badges und Inline-Edit**

### Erledigte Fixes

| Fix | Beschreibung | Status |
|-----|--------------|--------|
| Dividers entfernen | List → ScrollView+LazyVStack für alle Views | ✅ ERLEDIGT |
| TBD Italic | @ViewBuilder für korrekte Italic-Darstellung | ✅ ERLEDIGT |
| Duration Badge Farben | Grau = nicht gesetzt, Blau = manuell gesetzt | ✅ ERLEDIGT |
| Importance Badge | Immer sichtbar, grauer "?" wenn nil | ✅ ERLEDIGT |
| Navigation Header | Pull-to-Refresh zieht Header nicht mehr mit | ✅ ERLEDIGT |
| Tags ohne Chips | Plain Text mit # statt Chip-Design | ✅ ERLEDIGT |
| Kategorie lesbar | `.primary` statt `.secondary` Farbe | ✅ ERLEDIGT |

### Offene Bugs

**Bug 13: Kategorie-Badge ohne Chip-Hintergrund**
- Location: `BacklogRow.swift:221-237`
- Problem: Kategorie-Badge hat keinen Chip-Hintergrund wie andere Badges
- Fix: `.background(RoundedRectangle.fill(.ultraThinMaterial))` hinzufügen
- Status: **OFFEN**

**Bug 14: Focus Block Zeiteinstellung zeigt "25 Std" statt Minuten**
- Location: Vermutlich `BlockPlanningView.swift` oder `FocusBlockCard.swift`
- Problem: Dauer-Anzeige zeigt "25 Std" statt "25 min"
- Root Cause: Formatierung oder falsche Zeiteinheit
- Status: **OFFEN**

**Bug 15: Neue Task-Erstellung nutzt Default-Werte**
- Location: `TaskFormSheet.swift`, `CreateTaskView.swift`
- Problem: Neue Tasks wurden mit Default-Importance erstellt statt nil (TBD)
- Fix (2026-01-30): `priority: Int? = nil` als Default, TBD-Button hinzugefügt
- UI Tests: `TaskFormTbdUITests.swift` (4 Tests bestanden)
- Status: ✅ **ERLEDIGT**

**Bug 16: Task-Erstellung nutzt Emoji statt SF Symbols**
- Location: `CreateTaskView.swift` (QuickPriorityButton)
- Problem: Importance-Auswahl zeigte Emoji (🟦, 🟨, 🔴) statt SF Symbols
- Fix (2026-01-30): QuickPriorityButton mit SF Symbols (exclamationmark, .2, .3) + Farben
- Status: ✅ **ERLEDIGT**

**Bug 17: Task-Erstellung Design nicht aktualisiert**
- Location: `TaskFormSheet.swift`, `BacklogView.swift`
- Problem: Altes Form Design statt Glass Card
- Fix (2026-01-30):
  - Form → ScrollView + VStack mit Glass Card Sections
  - `.ultraThinMaterial` Hintergründe
  - Kompakteres Layout mit Task Type Grid
  - BacklogView nutzt jetzt TaskFormSheet statt CreateTaskView
- UI Tests: `TaskFormGlassCardUITests.swift` (3 Tests bestanden)
- Status: ✅ **ERLEDIGT**

### UI Test Failures (29.01.2026)

| Test | Fehler | Status |
|------|--------|--------|
| `testActionsMenuOpens()` | Menu öffnet nicht oder Optionen nicht gefunden | ⚠️ UNTERSUCHEN |
| `testBacklogRowShowsTasks()` | 0.000 sec - Crash oder Setup-Problem | ⚠️ UNTERSUCHEN |

### Neue Features

**Feature: Focus Blocks bearbeiten**
- Location: `BlockPlanningView.swift`
- Problem: Erstellte Focus Blocks können nicht bearbeitet werden
- Expected: Tap auf Block → Edit Sheet
- Status: **OFFEN** (Feature Request)

**Feature: Shake to Undo → Zurück zu Backlog**
- Problem: Versehentlich zu Next Up hinzugefügt → Shake soll rückgängig machen
- Implementation: UIResponder.motionEnded + UndoManager
- Status: **OFFEN** (Feature Request)

---

## Priorisierung Empfehlung

| Prioritaet | Items |
|------------|-------|
| ~~**1. Quick Wins**~~ | ~~Bug 9 (Zeitslots)~~ ✅, ~~Task 7 (Control Center)~~ ✅ |
| ~~**2. Next Up Fixes**~~ | ~~Gruppe A (Layout)~~ ✅, ~~Gruppe B (State)~~ ✅ |
| ~~**3. Core UX**~~ | ~~Task 11 (Overdue)~~ ✅, ~~Task 12 (Sprint Review)~~ ✅ |
| **4. BacklogRow Redesign** | Bug 13-17 (Gruppe G), UI Test Fixes |
| **5. Nice to Have** | ~~Task 7b (Compact QuickCapture)~~ ✅, Task 8-10 (Widgets/Siri), ~~Gruppe E (Live Activity)~~ ✅ |
