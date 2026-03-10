# BUG-DEP-4: Blockierte Tasks nicht vor Aktionen geschuetzt

## Zusammenfassung

Blockierte Tasks (mit `blockerTaskID != nil`) koennen ueber 3 Wege trotzdem Aktionen erhalten, die erst nach Freigabe des Blockers moeglich sein sollten.

## Gute Nachricht: Backlog-Swipes sind BEREITS geschuetzt

Die DEP-6 Architektur in BacklogView (iOS) und ContentView (macOS) rendert blockierte Tasks ueber separate `blockedRow()` / `makeBacklogRow(isBlocked: true)` Funktionen **OHNE Swipe-Actions**. Das heisst: In der normalen Backlog-Ansicht kann man blockierte Tasks nicht swipen.

## 3 offene Angriffsvektoren

### 1. macOS TaskInspector - Status Chips (HOCH)

**Datei:** `FocusBloxMac/TaskInspector.swift`, Zeilen 201 und 217

```swift
// Zeile 201: Kein isBlocked-Guard!
statusChip("Erledigt", "checkmark.circle.fill", task.isCompleted, .green) {
    task.isCompleted.toggle()  // <- blockierter Task kann als erledigt markiert werden
    ...
}

// Zeile 217: Kein isBlocked-Guard!
statusChip("Next Up", "arrow.up.circle.fill", task.isNextUp, .blue) {
    task.isNextUp.toggle()  // <- blockierter Task kann zu Next Up hinzugefuegt werden
    ...
}
```

**Ursache:** TaskInspector prueft `blockerTaskID` nur fuer Anzeige (Zeile 185-189: Info-Text), aber sperrt die Chips nicht.

### 2. Next Up Section - Blockierte Tasks erscheinen mit Swipes (MITTEL)

**Datei:** `Sources/Views/BacklogView.swift`, Zeile 88-89 + `FocusBloxMac/ContentView.swift`, Zeile 233-234

```swift
// iOS:
private var nextUpTasks: [PlanItem] {
    planItems.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && matchesSearch($0) }
    // FEHLT: && !$0.isBlocked
}

// macOS:
private var nextUpTasks: [LocalTask] {
    tasks.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && matchesSearch($0) }
    // FEHLT: && $0.blockerTaskID == nil
}
```

**Szenario:** Task ist in Next Up. Danach wird via TaskInspector ein Blocker zugewiesen. Task bleibt in Next Up mit vollen Swipe-Actions.

### 3. FocusBlock-Zuweisung (MITTEL)

**Datei:** `Sources/Views/TaskAssignmentView.swift`, Zeile 215

`assignTaskToBlock()` hat keinen isBlocked-Guard. Die verfuegbare Task-Liste filtert blockierte Tasks nicht heraus.

## Fix-Vorschlag

| # | Datei | Aenderung | LoC |
|---|-------|-----------|-----|
| 1 | `TaskInspector.swift` | "Erledigt" + "Next Up" Chips: `.disabled(task.blockerTaskID != nil)` | ~4 |
| 2 | `BacklogView.swift` | `nextUpTasks` Filter: `&& !$0.isBlocked` hinzufuegen | ~1 |
| 3 | `ContentView.swift` | `nextUpTasks` Filter: `&& $0.blockerTaskID == nil` hinzufuegen | ~1 |
| 4 | `TaskAssignmentView.swift` | `assignTaskToBlock()`: Guard `isBlocked` am Anfang | ~3 |

**Geschaetzte Aenderung:** ~4 Dateien, ~10 LoC. Minimal-invasiv.

## Blast Radius

- Keine Breaking Changes in bestehenden Tests (blocked rows haben bereits keine Swipes)
- Bestehendes Guard-Pattern (`BacklogRow.swift` Zeile 31: `!isBlocked`) ist die Vorlage
- Beide Plattformen betroffen und muessen gefixt werden
