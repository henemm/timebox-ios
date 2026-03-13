# Bug Analysis: FocusBlock Drag Indicator + Title Update

**Datum:** 2026-03-05
**Plattform:** iOS (macOS teilweise betroffen bei Bug B)
**View:** BlockPlanningView (Blox Timeline)
**Workflow:** bug-blox-drag-indicator-time

## Symptome

**Bug A:** Kein visueller Indicator beim Drag & Drop von FocusBlocks auf der iOS Timeline. User sieht nicht, wohin der Block verschoben wird.

**Bug B:** Block-Name ("FocusBlox 09:00") aktualisiert sich nicht auf die neue Uhrzeit nach Verschieben (Drag oder Dialog-Edit).

---

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- Bug 70b (Drag & Drop Move) wurde am 2026-03-04 implementiert (commit `6a3b54a`)
- macOS hat bereits einen `DropPreviewIndicator` (blaue Linie + Zeitanzeige)
- iOS hat keinen — nutzt nur SwiftUI-Default Drag-Verhalten
- Kein früherer Bug zu "Title aktualisiert sich nicht"
- `timeRangeText` ist computed property auf FocusBlock, aber `title` ist gespeichert

### Agent 2 (Datenfluss-Trace)
- Block-Titel wird bei Erstellung generiert: `"FocusBlox \(formatter.string(from: startDate))"`
- `FocusBlock.title` ist `let String` — unveränderlich nach Init
- `updateFocusBlockTime()` aktualisiert NUR `startDate`/`endDate`, NICHT `event.title`
- iOS hat KEINEN Drop-Preview-Indicator
- `TimelineFocusBlockRow` zeigt `block.title` (stale) + separate Zeitanzeige (korrekt)

### Agent 3 (Alle Schreiber)
- Titel geschrieben bei: `EventKitRepository.swift:287` (`createFocusBlock`)
- Zeit geschrieben bei: `EventKitRepository.swift:343-344` (`updateFocusBlockTime`)
- macOS optimistisches UI in `MacPlanningView:473` preserviert ebenfalls alten Titel
- 9 Write-Sites identifiziert, keine aktualisiert den Titel bei Zeitänderung

### Agent 4 (Alle Szenarien)
- Drag to new time: Zeit updated, Titel nicht
- Edit via Dialog: Zeit updated, Titel nicht
- Create: Titel korrekt gesetzt
- macOS hat DropPreviewIndicator, iOS nicht

### Agent 5 (Blast Radius)
- `block.title` wird in 14+ Dateien referenziert (iOS, macOS, Widgets, Notifications)
- Live Activity zeigt `blockTitle` an
- Notifications nutzen `blockTitle`
- CalendarEventTransfer kopiert `block.title` beim Drag

---

## Hypothesen

### Hypothese 1: Title-Update fehlt in `updateFocusBlockTime()` (HOCH)

**Beschreibung:** `EventKitRepository.updateFocusBlockTime()` (Zeile 336-346) aktualisiert nur `event.startDate` und `event.endDate`. Der `event.title` wird nicht angefasst. Da der Titel das Pattern "FocusBlox HH:MM" hat (generiert bei Erstellung), bleibt er auf der alten Uhrzeit stehen.

**Beweis DAFÜR:**
- Code in `EventKitRepository.swift:343-344` zeigt nur `startDate`/`endDate` Updates
- `createFocusBlock()` in Zeile 287 setzt `event.title = "FocusBlox \(formatter.string(from: startDate))"`
- Kein anderer Code-Pfad aktualisiert den Titel bei Zeitänderung

**Beweis DAGEGEN:**
- Könnte sein, dass der Titel absichtlich beibehalten wird (falls User ihn manuell geändert hat)

**Wahrscheinlichkeit:** HOCH — der Code fehlt schlicht

### Hypothese 2: iOS Drop-Indicator wurde nie implementiert (HOCH)

**Beschreibung:** Bei Bug 70b wurde Drag & Drop implementiert, aber nur mit SwiftUI `.dropDestination()` — ohne visuellen Indicator. macOS hat einen `DropPreviewIndicator` (blaue Linie + Zeitlabel), iOS nicht.

**Beweis DAFÜR:**
- Kein `DropPreviewIndicator` in `BlockPlanningView.swift`
- macOS hat `DropPreviewIndicator` Struct in `MacTimelineView.swift:524-572`
- Bug 70b Commit enthält keinen Indicator für iOS

**Beweis DAGEGEN:** Keiner — Feature fehlt eindeutig

**Wahrscheinlichkeit:** HOCH — Feature wurde auf macOS gebaut aber nicht auf iOS portiert

### Hypothese 3: Title ist absichtlich statisch (NIEDRIG)

**Beschreibung:** Der Titel könnte bewusst als fester Name gedacht sein (wie ein Projekt-Name), nicht als Zeit-basierter Name.

**Beweis DAFÜR:**
- `FocusBlock.title` ist `let` (immutable)
- Es gibt ein `isEventNameOverridden` Pattern
- `timeRangeText` existiert als separate computed property

**Beweis DAGEGEN:**
- Der Default-Titel enthält die Uhrzeit ("FocusBlox 09:00")
- Wenn der Titel statisch sein soll, sollte er keine Uhrzeit enthalten
- User-Erwartung: Name mit Uhrzeit = Uhrzeit aktualisiert sich

**Wahrscheinlichkeit:** NIEDRIG — der Uhrzeit-Inhalt im Namen erzeugt die Erwartung einer Aktualisierung

---

## Wahrscheinlichste Ursachen

**Bug A:** Feature (Drop-Indicator) existiert auf macOS aber wurde nie auf iOS portiert. Keine Code-Lücke, sondern fehlendes Feature.

**Bug B:** `EventKitRepository.updateFocusBlockTime()` aktualisiert den EKEvent-Titel nicht bei Zeitänderung. Der Titel wird nur bei Erstellung gesetzt.

---

## Debugging-Plan

### Bug B (Title Update):
- **Bestätigung:** In `updateFocusBlockTime()` nach dem Save prüfen: `print("Title after save: \(event.title), startDate: \(event.startDate)")` → Titel enthält noch alte Uhrzeit
- **Widerlegung:** Falls Titel sich doch ändert, liegt das Problem in der FocusBlock-Init oder im Reload

### Bug A (Drop Indicator):
- Kein Debugging nötig — Feature fehlt nachweislich (Grep nach `DropPreviewIndicator` in iOS-Code liefert 0 Treffer)

---

## Blast Radius

### Bug B (Title Update):
- **Betroffene Stellen bei Title-Änderung:**
  - Live Activity Widget (`FocusBlockLiveActivity.swift`) — zeigt blockTitle
  - Notifications (`NotificationService.swift`) — nutzt blockTitle
  - Siri Shortcuts (`FocusBlockEntity.swift`) — exportiert block.title
  - macOS Views (MacFocusView, MenuBarView, MacReviewView)
- **Risiko:** Wenn wir den Titel in `updateFocusBlockTime()` updaten, ändert sich der Name überall — das ist das gewünschte Verhalten
- **Sonderfall:** User-überschriebene Namen (`isEventNameOverridden`) dürfen NICHT überschrieben werden

### Bug A (Drop Indicator):
- **Nur iOS betroffen** — macOS hat bereits einen Indicator
- **Kein Blast Radius** — rein additives Feature

---

## Fix-Vorschlag (Kurzfassung)

**Bug A:** `DropPreviewIndicator` von macOS auf iOS portieren (mit `@State var dropTargetTime: Date?` + visuellem Feedback)

**Bug B:** In `updateFocusBlockTime()` den Titel aktualisieren, ABER nur wenn der aktuelle Titel dem Default-Pattern entspricht ("FocusBlox HH:MM"). User-überschriebene Namen beibehalten.
