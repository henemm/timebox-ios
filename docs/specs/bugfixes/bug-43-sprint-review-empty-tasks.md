# Bug 43: Sprint Review zeigt keine Tasks

## Problem

Sprint Review auf **beiden Plattformen** (iOS + macOS) zeigt 0 Tasks an, obwohl der FocusBlock Tasks enthielt und diese während der Focus Session bearbeitet wurden.

**Screenshot macOS:** 100% geschafft, 0 Erledigt, 0 Offen, 0m geplant, 28m gebraucht - keine Task-Zeilen sichtbar.

## Root Cause

Beide Plattformen laden Tasks mit einem `!isCompleted` Filter. Sobald ein Task während der Focus Session als erledigt markiert wird (`LocalTask.isCompleted = true`), verschwindet er aus der Task-Liste. Sprint Review kann ihn danach nicht mehr finden.

### macOS (`MacFocusView.swift:15`)

```swift
@Query(filter: #Predicate<LocalTask> { !$0.isCompleted })
private var allTasks: [LocalTask]
```

SwiftData `@Query` aktualisiert sich live → erledigte Tasks verschwinden sofort.

### iOS (`FocusLiveView.swift:467`)

```swift
allTasks = try await syncEngine.sync()
// sync() → fetchIncompleteTasks() → #Predicate { !$0.isCompleted }
```

`SyncEngine.sync()` ruft `fetchIncompleteTasks()` auf → nach `loadData()` in `markTaskComplete()` sind erledigte Tasks weg.

## Fix

### Fix A: macOS - @Query ohne isCompleted Filter

**Datei:** `FocusBloxMac/MacFocusView.swift`

```swift
// VORHER (Zeile 15-16):
@Query(filter: #Predicate<LocalTask> { !$0.isCompleted })
private var allTasks: [LocalTask]

// NACHHER:
@Query
private var allTasks: [LocalTask]
```

Die aktive Focus-Ansicht filtert bereits korrekt über `block.completedTaskIDs` - der `@Query`-Filter ist redundant und schädlich.

### Fix B: iOS - Alle Tasks laden statt nur incomplete

**Datei:** `Sources/Views/FocusLiveView.swift`

In `loadData()` statt `syncEngine.sync()` (das nur incomplete liefert) direkt alle LocalTasks laden:

```swift
// VORHER (Zeile 465-467):
let taskSource = LocalTaskSource(modelContext: modelContext)
let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
allTasks = try await syncEngine.sync()

// NACHHER:
let fetchDescriptor = FetchDescriptor<LocalTask>()
let localTasks = try modelContext.fetch(fetchDescriptor)
allTasks = localTasks.map { PlanItem(localTask: $0) }
```

## Betroffene Dateien

1. `FocusBloxMac/MacFocusView.swift` - @Query Filter entfernen
2. `Sources/Views/FocusLiveView.swift` - loadData() Task-Loading ändern

## Risiko

Minimal. Beide Fixes entfernen nur einen zu aggressiven Filter. Die eigentliche Filterung (welche Tasks zum Block gehören, welche erledigt sind) passiert über `block.taskIDs` und `block.completedTaskIDs` in `tasksForBlock()`.
