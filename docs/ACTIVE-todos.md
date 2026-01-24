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

## Themengruppe A: Next Up Layout (Horizontal → Vertikal)

> **3 Stellen mit gleichem Bug:** ScrollView horizontal statt VStack vertikal

| ID | Location | Status |
|----|----------|--------|
| Bug 2 | `NextUpSection.swift:38` | OFFEN |
| Bug 4 | `TaskAssignmentView.swift:108` | OFFEN |
| Task 5 | `FocusLiveView.swift` (nextUpSection) | OFFEN |

**Gemeinsamer Fix:** `ScrollView(.horizontal)` → `VStack` mit Task-Rows
**Scope:** Klein (3x gleiche Aenderung)

---

## Themengruppe B: Next Up State Management

> **Tasks erscheinen/verschwinden falsch**

**Bug 1: Tasks bleiben in Quadranten sichtbar wenn in Next Up**
- Location: `BacklogView.swift:58-77, 80-143`
- Problem: Filter pruefen nur `!isCompleted`, nicht `!isNextUp`
- Fix: `&& !$0.isNextUp` zu allen Filtern hinzufuegen
- Scope: Klein
- Status: OFFEN

**Bug 5: Tasks erscheinen nicht im Focus Block nach Zuordnung**
- Location: `TaskAssignmentView.swift:141, 152-156, 175`
- Problem: Nach Zuordnung `isNextUp=false` → Task aus `unscheduledTasks` raus → `tasksForBlock()` findet ihn nicht
- Fix: Separate `allTasks` State-Variable fuer Block-Anzeige
- Status: OFFEN

**Bug 6: Task kehrt nicht zu Next Up zurueck nach Block-Entfernung** (ERLEDIGT)
- Location: `TaskAssignmentView.swift:216-219`
- Problem: `removeTaskFromBlock()` setzte `isNextUp` nicht zurueck auf `true`
- Fix: `try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)` hinzugefuegt
- Commit: `d0fdcf1` (2026-01-18)
- Status: ERLEDIGT

---

## Themengruppe C: Drag & Drop Sortierung

> **Voraussetzung:** Datenmodell-Erweiterung (`nextUpSortOrder` Property)

**Task 1: Drag & Drop in Next Up Section**
- User soll Tasks in Next Up per Drag & Drop sortieren
- Status: BLOCKIERT (benoetigt Datenmodell)

**Task 2: Task-Sortierung in Focus Block**
- User soll Tasks innerhalb eines Focus Blocks sortieren
- `taskIDs` Array existiert bereits → Reihenfolge = Array-Index
- Scope: ~50 LoC
- Status: OFFEN

---

## Themengruppe D: Quick Task Capture

> **4 Wege zur schnellen Task-Erfassung**

| ID | Feature | Status | Prioritaet |
|----|---------|--------|------------|
| Task 7 | Control Center Fix (OpenURLIntent kaputt) | OFFEN | **HOCH** |
| Task 8 | Home Screen Widget | OFFEN | Mittel |
| Task 9 | Control Center Inline-Eingabe (iOS 18+) | OFFEN | Niedrig |
| Task 10 | Siri Shortcut funktionsfaehig | OFFEN | Mittel |

**Task 7 (Control Center Fix)** - MUSS ZUERST
- Root Cause: `OpenURLIntent` blockiert custom URL schemes
- Fix: `openAppWhenRun = true` statt `OpenURLIntent`
- Location: `FocusBloxWidgets/QuickAddTaskControl.swift:11-14`
- Scope: Klein (~5 LoC)

**Task 8 (Home Screen Widget)**
- Neues `StaticConfiguration` Widget
- Tap → App mit QuickCaptureView
- Scope: Mittel (~100 LoC)

**Task 9 (Control Center Inline)**
- Voraussetzung: Task 7 gefixt
- iOS 18+ interaktives Control mit Textfeld
- Scope: Gross + Research

**Task 10 (Siri Shortcut)**
- Intent erstellt aktuell keinen Task (nur Logging)
- Benoetigt: App Group fuer shared ModelContainer
- Scope: Mittel (~80 LoC)

---

## Themengruppe E: Focus Block Ausfuehrung

> **Live Activity, Timer, Notifications waehrend Focus Block**

**Bug 10: Dynamic Island Layout falsch**
- Problem: Zu breit, falsches Layout-Pattern
- Fix: Layout 1:1 von Meditationstimer uebernehmen (explizite frame sizes, padding, overlay-trick)
- Location: `FocusBloxWidgets/FocusBlockLiveActivity.swift`
- Referenz: `Meditationstimer/.../MeditationstimerWidgetLiveActivity.swift`
- Scope: Mittel (~80 LoC)
- Status: OFFEN

**Task 4: Live Activity zeigt Task-Restzeit statt Block-Restzeit**
- Aktuell: Countdown fuer gesamten Block
- Expected: Countdown fuer aktuellen Task
- Scope: Mittel
- Status: OFFEN

**Task 3: Push-Notification bei Focus Block Start**
- X Minuten vor Start oder bei Start
- `UNUserNotificationCenter` fuer lokale Notifications
- Scope: Mittel (~100 LoC)
- Status: OFFEN

**Task 11: Task-Timer Ablauf - Overdue Handling**
- Aktuelle Probleme:
  1. Keine Push-Notification bei Task-Zeitablauf
  2. Nur "erledigt" Button - "nicht erledigt" fehlt
  3. Kein Overdue-Zustand
- Expected:
  1. Push: "Zeit fuer [Task] abgelaufen"
  2. Buttons: "Erledigt" / "Nicht erledigt"
  3. Overdue: Timer rot, regelmaessige Erinnerung
- Scope: Gross (~200 LoC)
- Prioritaet: **HOCH**
- Status: OFFEN

---

## Themengruppe F: Sprint Review

**Task 12: Sprint Review komplett ueberarbeiten**
- Aktuelle Probleme:
  1. Zeigt nicht: geplante Zeit vs. tatsaechliche Zeit
  2. Keine Editiermoeglichkeit fuer Task-Status
  3. Keine Anpassung der Restzeit fuer unerledigte Tasks
- Expected:
  1. Pro Task: geplant X min, gebraucht Y min
  2. Tasks als erledigt/unerledigt markierbar
  3. Bei "unerledigt": Restzeit anpassen
- Voraussetzung: Task-Tracking mit Start/Ende-Zeiten (neues Datenmodell)
- Scope: Gross (~300 LoC + Datenmodell)
- Prioritaet: **HOCH**
- Status: OFFEN

---

## Einzelne Bugs

**Bug 7: Scrolling innerhalb Focus Block nicht moeglich**
- Location: `TaskAssignmentView.swift:313-331`
- Problem: `.scrollDisabled(true)` bei 6+ Tasks
- Fix: Feste `.frame(maxHeight: 250)` mit `.scrollDisabled(false)`
- Scope: Mittel
- Status: OFFEN

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

## Priorisierung Empfehlung

| Prioritaet | Items |
|------------|-------|
| **1. Quick Wins** | ~~Bug 9 (Zeitslots)~~ ✅, Task 7 (Control Center) |
| **2. Next Up Fixes** | Gruppe A (Layout), Gruppe B (State) |
| **3. Core UX** | Task 11 (Overdue), Task 12 (Sprint Review) |
| **4. Nice to Have** | Gruppe D (Quick Capture), Gruppe E (Live Activity) |
