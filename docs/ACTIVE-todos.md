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

**Bug 10: Dynamic Island Layout falsch** ✅
- Problem: Zu breit, falsches Layout-Pattern
- Fix implementiert:
  1. **Overlay-Trick** in compactTrailing (hidden "00:00" placeholder)
  2. Explizite frame sizes für Icons (20x20 compact, 18x18 minimal, 52x52 expanded)
  3. ZStack mit Circle-Background für konsistentes Icon-Styling
  4. Proper padding (.leading, .trailing, .vertical)
- Location: `FocusBloxWidgets/FocusBlockLiveActivity.swift`
- Status: **ERLEDIGT** (2026-01-26) - Manueller Test auf Device empfohlen

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

**Bug 12: Kategorie-System inkonsistent** 🔧
- Location: `TaskFormSheet.swift:76-87`, `EditTaskSheet.swift:25-36`, `BacklogView.swift:83-89`, `TaskDetailSheet.swift:42-56`
- Problem: UI zeigt 10 Kategorien, Spec definiert 5+1, BacklogView Gruppierung nutzt nur 6 Work-Types
- Root Cause: Zwei Konzepte vermischt (Lebensarbeit vs Work-Type)
- Entscheidung: **Option A - Spec folgen** (nur 5+1 Lebensarbeit-Kategorien)
- Fix:
  1. `TaskFormSheet.swift` - taskTypeOptions auf 5 reduzieren
  2. `EditTaskSheet.swift` - taskTypeOptions auf 5 reduzieren + Icons hinzufuegen
  3. `BacklogView.swift` - categories Array und Lokalisierung anpassen
  4. `TaskDetailSheet.swift` - categoryText anpassen
- Scope: 4 Dateien, ~-50 LoC
- Status: OFFEN

**Bug 11: Pull-to-Refresh bewegt nicht den kompletten Inhalt (nur Backlog)**
- Location: `BacklogView.swift:168-192`
- Problem: NextUpSection und ggf. Section-Header bleiben beim Pull-to-Refresh stehen, nur der Listen-Inhalt bewegt sich
- Expected: Beim Pull-to-Refresh soll sich der KOMPLETTE Fensterinhalt nach unten bewegen (normales iOS-Verhalten)
- Root Cause: Die `NextUpSection` ist in einem aeusseren `VStack` platziert (Zeile 168), waehrend die scrollenden Container (`List`, `ScrollView`) nur den restlichen Inhalt enthalten. Die `NextUpSection` gehoert nicht zum scrollenden Container.
- Zusaetzliches Problem: Doppelte `.refreshable` Modifier (Zeile 246-248 auf Group + nochmal auf jedem View-Mode)
- Fix-Ansatz: Den gesamten Inhalt (NextUpSection + Content) in EINEN scrollenden Container packen, z.B. als Sections einer `List` oder als Content in einer gemeinsamen `ScrollView`
- Test: Pull-to-Refresh im Backlog-Tab ausfuehren → Gesamter Inhalt inkl. blauer Next-Up-Box muss sich nach unten bewegen
- Scope: Mittel (~50-80 LoC) - Umstrukturierung der View-Hierarchie
- Status: OFFEN

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
| ~~**1. Quick Wins**~~ | ~~Bug 9 (Zeitslots)~~ ✅, ~~Task 7 (Control Center)~~ ✅ |
| ~~**2. Next Up Fixes**~~ | ~~Gruppe A (Layout)~~ ✅, ~~Gruppe B (State)~~ ✅ |
| **3. Core UX** | Task 11 (Overdue), Task 12 (Sprint Review) |
| **4. Nice to Have** | ~~Task 7b (Compact QuickCapture)~~ ✅, Task 8-10 (Widgets/Siri), Gruppe E (Live Activity) |
