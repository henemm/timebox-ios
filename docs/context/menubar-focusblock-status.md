# Context: MenuBar FocusBlock Status

## Request Summary
Menu Bar soll den aktiven FocusBlock-Status anzeigen: Timer (mm:ss), aktueller Task, Fortschritt und Complete/Skip Buttons - als macOS-Aequivalent zur iOS Live Activity.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/MenuBarView.swift` | **Hauptdatei** - hier kommt die Focus Section rein (~250 LoC aktuell) |
| `FocusBloxMac/FocusBloxMacApp.swift` | MenuBarExtra Label (Z.129-135) - muss dynamisch werden + EventKit Environment durchreichen |
| `FocusBloxMac/MacFocusView.swift` | **Referenz-Implementierung** - hat Timer, Block-Loading, Task-Actions bereits |
| `Sources/Services/TimerCalculator.swift` | Shared: `remainingSeconds()`, `plannedTaskEndDate()` |
| `Sources/Services/FocusBlockActionService.swift` | Shared: `completeTask()`, `skipTask()` |
| `Sources/Models/FocusBlock.swift` | Model: `isActive`, `isPast`, `taskIDs`, `completedTaskIDs`, `taskTimes` |
| `Sources/Models/LocalTask.swift` | Model: `estimatedDuration`, `title` |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | `fetchFocusBlocks(for:)` |

## Existing Patterns

### Timer-Pattern (MacFocusView.swift)
```swift
@State private var currentTime = Date()
@State private var taskStartTime: Date?
@State private var lastTaskID: String?
private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
// .onReceive(timer) { currentTime = $0 }
```

### Block-Loading Pattern (MacFocusView.swift:410-434)
```swift
let blocks = try eventKitRepo.fetchFocusBlocks(for: Date())
activeBlock = blocks.first { $0.isActive }
```

### Task Resolution Pattern (MacFocusView.swift:438-441)
```swift
block.taskIDs.compactMap { taskID in
    allTasks.first { $0.id == taskID }
}
// remaining = tasks.filter { !block.completedTaskIDs.contains($0.id) }
// currentTask = remainingTasks.first
```

### FocusBlockActionService Pattern (MacFocusView.swift:453-468)
```swift
_ = try FocusBlockActionService.completeTask(
    taskID: taskID, block: block,
    taskStartTime: taskStartTime,
    eventKitRepo: eventKitRepo, modelContext: modelContext
)
taskStartTime = nil
await loadData()
```

### EventKit Environment Injection (FocusBloxMacApp.swift)
- ContentView: `.environment(\.eventKitRepository, eventKitRepository)` (Z.62)
- MacSettingsView: `.environment(\.eventKitRepository, eventKitRepository)` (Z.140)
- MenuBarView: **FEHLT** - muss hinzugefuegt werden (Z.130-131)

## Dependencies
- **Upstream:** `EventKitRepository.fetchFocusBlocks()`, `TimerCalculator`, `FocusBlockActionService`
- **SwiftData:** `@Query` fuer `LocalTask` (Task-Titel + Duration aus allTasks)
- **Environment:** `\.eventKitRepository`, `\.modelContext`

## Downstream
- Keine - MenuBarView hat keine Dependents

## Existing Specs
- `openspec/changes/menubar-focusblock-status/proposal.md` - Detaillierte Spec vorhanden

## Risks & Considerations
1. **EventKit Environment fehlt** im MenuBarExtra - muss explizit durchgereicht werden
2. **Timer-Effizienz:** 1s Timer nur bei aktivem Block, sonst 60s Polling
3. **State-Sync:** Nach Complete/Skip muss `loadData()` aufgerufen werden
4. **Doppelte Timer** wenn Hauptfenster + Popover offen - akzeptabel laut Spec
5. **MenuBarExtra Label** muss dynamisch werden (statisches `cube.fill` → Timer-Anzeige)

---

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/MenuBarView.swift` | MODIFY | Focus Section + Timer-State + Block-Loading + Complete/Skip Actions |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | EventKit Environment an MenuBarView durchreichen + dynamisches Label |

### Scope Assessment
- Files: **2** (nur macOS Views)
- Estimated LoC: **~120 netto** (+120/-5)
- Risk Level: **LOW** - Alle Shared Services existieren, Pattern aus MacFocusView 1:1 uebertragbar

### Technical Approach
1. `FocusBloxMacApp.swift`: `.environment(\.eventKitRepository, eventKitRepository)` an MenuBarView + dynamisches Label
2. `MenuBarView.swift`: `import Combine` + Timer/Block-State + Focus Section (UI) + Complete/Skip Actions
3. Alle Berechnungen via `TimerCalculator` (Shared), alle Actions via `FocusBlockActionService` (Shared)
4. Timer-Strategie: 1s bei aktivem Block, 60s Polling ohne Block
5. Pattern 1:1 von MacFocusView uebernommen (kein neues Pattern)

### Dependencies
- **Upstream (Shared, unveraendert):** TimerCalculator, FocusBlockActionService, EventKitRepositoryProtocol, FocusBlock, LocalTask
- **Neuer Import:** `Combine` (fuer Timer.publish)
- **Environment-Fix:** `\.eventKitRepository` muss in FocusBloxMacApp an MenuBarExtra durchgereicht werden
- **Bereits vorhanden:** `.modelContainer(container)`, `@Query`, `.if()` ViewModifier

### Open Questions
- Keine - Spec ist vollstaendig, alle Patterns bekannt
