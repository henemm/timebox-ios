# FEATURE_206: Coach Morning — Freie Lücken mit Call-to-Action

## Status: SPEC

## Problem
Die CoachView morgens zeigt Task-Vorschläge, aber NICHT gruppiert nach freien Zeitlücken. Der User sieht nicht, WANN er welchen Task machen könnte. Freie Lücken werden nur in DayView informativ angezeigt (gelbe Karten ohne Aktion).

## Lösung
Die `morningContent` in CoachView erweitern: Freie Lücken mit je bis zu 3 passenden Tasks darunter anzeigen. Der User wählt Tasks aus und erstellt mit einem Tipp einen FocusBlock für diese Lücke. Die Lücke verschwindet, der Block ist im Kalender.

## User-Erwartung
- User sieht freie Lücken im Coach Morning mit je 3 passenden Task-Vorschlägen
- User wählt 1-3 Tasks aus (Toggle/Haken)
- Tipp auf "Block erstellen" erstellt einen FocusBlock für diesen Zeitslot
- Die Lücke verschwindet, der Block ist sichtbar im Tagesplan
- Wenn gewählte Tasks länger als die Lücke dauern → ehrliche Warnung
- Kein Zwang — Lücken ohne Aktion ignorieren ist einfach

## Technischer Ansatz

### Was bereits existiert
- `GapFinder` → erkennt freie Slots (`TimeSlot`)
- `NextUpSuggestionService.suggestions()` → gibt `[NextUpSuggestion]` zurück (1 Task pro Slot)
- `morningSuggestions` State in CoachView wird bereits geladen (Zeile 769)
- `EventKitRepository.createFocusBlock(startDate:endDate:)` → erstellt Kalender-Event
- `EventKitRepository.updateFocusBlock(eventID:taskIDs:...)` → weist Tasks zu
- `SyncEngine.updateAssignedFocusBlock(itemID:focusBlockID:)` → SwiftData-Sync

### Was geändert wird

**Datei 1: `Sources/Views/CoachView.swift`** (~100 LoC netto)

1. Neuer State: `@State private var selectedTasksPerSlot: [UUID: Set<String>]` — trackt welche Tasks pro Slot ausgewählt sind

2. `morningContent` erweitern:
   - Wenn `freeSlots` nicht leer: neue View `morningSlotSection` VOR den bestehenden Vorschlägen
   - Bestehende `morningTopTasks`-Section bleibt als Fallback

3. Neue View `morningSlotSection`:
   - Iteriert über `freeSlots`
   - Pro Slot: Header mit Uhrzeit + Dauer ("09:00 — 45 Min frei")
   - Darunter: bis zu 3 passende Tasks aus `morningSuggestions` (gefiltert nach `suggestion.slot.id == slot.id`)
   - Jeder Task: Toggle (Haken) zum Auswählen
   - Wenn Gesamtdauer > Slot-Dauer: orangener Hinweis "Tasks dauern länger als die Lücke"
   - Button "Block erstellen" wenn ≥1 Task ausgewählt
   - Button ruft neue Methode `createBlockForSlot(slot:taskIDs:)` auf

4. Neue Methode `createBlockForSlot(slot:taskIDs:)`:
   - Ruft `eventKitRepo.createFocusBlock(startDate: slot.startDate, endDate: slot.endDate)` auf
   - Ruft `eventKitRepo.updateFocusBlock(eventID:taskIDs:...)` auf
   - Aktualisiert SwiftData via `SyncEngine.updateAssignedFocusBlock()` pro Task
   - Entfernt den Slot aus `freeSlots` (Animation)
   - Haptisches Feedback (`.sensoryFeedback(.success)`)

**Datei 2: `Sources/Services/NextUpSuggestionService.swift`** (~25 LoC)

5. `compute()` erweitern: Pro Slot bis zu 3 Kandidaten zurückgeben statt nur den besten
   - Bestehende Filterlogik beibehalten (Dauer-Passung, nicht completed, nicht NextUp)
   - Sortierung nach Score, Top-3 pro Slot

### Nicht geändert
- `GapFinder` — funktioniert wie benötigt
- `DayView` — behält bestehende informative Anzeige
- `EventKitRepository` — bestehende Methoden reichen aus
- `FocusBlock` — Model bleibt unverändert

## Acceptance Criteria

1. **Lücken sichtbar**: Coach Morning zeigt freie Lücken mit Uhrzeit und Dauer
2. **Tasks pro Lücke**: Unter jeder Lücke bis zu 3 passende Tasks (Dauer ≤ Slot-Dauer)
3. **Task-Auswahl**: User kann 1-3 Tasks per Toggle auswählen
4. **Dauer-Warnung**: Wenn Gesamtdauer > Slot-Dauer, orangener Hinweis
5. **Block erstellen**: Button erstellt FocusBlock via EventKit für den Zeitslot
6. **Tasks zugeordnet**: Gewählte Tasks sind dem FocusBlock zugeordnet
7. **Visuelles Feedback**: Slot verschwindet aus der Liste nach Block-Erstellung
8. **Keine Lücken = kein Abschnitt**: Wenn keine freien Slots, wird der Abschnitt nicht angezeigt
9. **Bestehende Vorschläge bleiben**: morningTopTasks-Section bleibt als Fallback

## Betroffene Dateien
- `Sources/Views/CoachView.swift` — morningContent + morningSlotSection + createBlockForSlot
- `Sources/Services/NextUpSuggestionService.swift` — Multi-Candidate pro Slot

## Geschätzt
~125 LoC, 2 Dateien
