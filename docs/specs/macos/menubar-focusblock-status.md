---
entity_id: menubar-focusblock-status
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.0"
tags: [macos, menubar, focusblock, timer, ui]
---

# MenuBar FocusBlock Status

## Approval

- [ ] Approved

## Purpose

Erweitert die bestehende MenuBarView um einen FocusBlock-Status mit Timer, aktuellem Task und Complete/Skip Actions - als macOS-Aequivalent zur iOS Live Activity. Nutzer sehen jederzeit den aktuellen Task und die verbleibende Zeit, ohne das Hauptfenster oeffnen zu muessen.

## Source

- **File:** `FocusBloxMac/MenuBarView.swift`
- **Identifier:** `struct MenuBarView: View` (MODIFY)
- **File:** `FocusBloxMac/FocusBloxMacApp.swift`
- **Identifier:** `MenuBarExtra` (MODIFY - Environment + dynamisches Label)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| TimerCalculator | service | Berechnung der Restzeit (remainingSeconds, plannedTaskEndDate) |
| FocusBlockActionService | service | Complete/Skip Actions fuer Tasks |
| EventKitRepositoryProtocol | protocol | Laden aktiver FocusBlocks (fetchFocusBlocks) |
| FocusBlock | model | Block-Status (isActive, isPast, taskIDs, completedTaskIDs) |
| LocalTask | model | Task-Details (title, estimatedDuration) |

## Implementation Details

### 1. Menu Bar Label (dynamisch)

Das MenuBarExtra Label wird dynamisch basierend auf dem aktiven Block:

```swift
// FocusBloxMacApp.swift
MenuBarExtra {
    MenuBarView()
        .environment(\.eventKitRepository, eventKitRepo)
} label: {
    if let activeBlock = currentBlock, activeBlock.isActive {
        if let remainingSeconds = remainingTaskSeconds, remainingSeconds > 0 {
            Label {
                Text(formatTime(remainingSeconds))
            } icon: {
                Image(systemName: "cube.fill")
            }
        } else {
            Label("", systemImage: "checkmark.circle.fill")
        }
    } else {
        Image(systemName: "cube.fill")
    }
}
.menuBarExtraStyle(.window)
```

**Zeitformat:** mm:ss (z.B. "12:34")

### 2. Focus Section im Popover

Neue Section OBERHALB des bestehenden Headers:

```swift
// MenuBarView.swift
var body: some View {
    VStack(spacing: 0) {
        // NEU: Focus Section (nur wenn activeBlock existiert)
        if let block = activeBlock {
            focusSection(for: block)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()
        } else {
            // Fallback: Idle State
            Text("☽ Kein aktiver Focus Block")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()

            Divider()
        }

        // Bestehender Header, Quick Add, Next Up, etc.
        // ...
    }
}
```

### 3. Focus Section Layout

```swift
@ViewBuilder
private func focusSection(for block: FocusBlock) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        // Block Header (Name + Restzeit)
        HStack {
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
            Text(block.title ?? "Focus Block")
                .font(.headline)
            Spacer()
            Text(formatBlockTime(block))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        // Progress Bar
        HStack {
            ProgressView(value: Double(block.completedTaskIDs.count),
                        total: Double(block.taskIDs.count))
                .progressViewStyle(.linear)
            Text("\(block.completedTaskIDs.count)/\(block.taskIDs.count) Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Current Task (nur wenn Tasks vorhanden)
        if let currentTask = getCurrentTask(from: block) {
            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "play.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTask.title)
                        .font(.subheadline)

                    HStack {
                        if let remaining = calculateRemainingTime(for: currentTask, in: block) {
                            Text(formatTime(remaining))
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(Int(currentTask.estimatedDuration)) min geschaetzt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    completeCurrentTask(in: block)
                } label: {
                    Label("Erledigt", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    skipCurrentTask(in: block)
                } label: {
                    Label("Weiter", systemImage: "arrow.right")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
    }
}
```

### 4. Timer & State Management

```swift
// State Properties (NEU)
@State private var activeBlock: FocusBlock?
@State private var currentTime = Date()
@State private var taskStartTime: Date?
@State private var lastTaskID: String?
@Environment(\.eventKitRepository) private var eventKitRepo

// Timer (1s bei aktivem Block, sonst 60s Polling)
private var timerInterval: TimeInterval {
    activeBlock?.isActive == true ? 1.0 : 60.0
}

// Timer.publish wird dynamisch angepasst
.onReceive(Timer.publish(every: timerInterval, on: .main, in: .common).autoconnect()) { _ in
    currentTime = Date()
    loadActiveBlock()
}

.task {
    loadActiveBlock()
}

private func loadActiveBlock() {
    Task {
        let blocks = await eventKitRepo.fetchFocusBlocks()
        activeBlock = blocks.first { $0.isActive && !$0.isPast }
    }
}
```

### 5. Actions via Shared Service

```swift
private func completeCurrentTask(in block: FocusBlock) {
    guard let currentTask = getCurrentTask(from: block) else { return }

    Task {
        await FocusBlockActionService.shared.completeTask(
            taskID: currentTask.id,
            in: block,
            using: eventKitRepo
        )
        loadActiveBlock()
    }
}

private func skipCurrentTask(in block: FocusBlock) {
    guard let currentTask = getCurrentTask(from: block) else { return }

    Task {
        await FocusBlockActionService.shared.skipTask(
            taskID: currentTask.id,
            in: block,
            using: eventKitRepo
        )
        loadActiveBlock()
    }
}
```

### 6. Helper Methods

```swift
private func getCurrentTask(from block: FocusBlock) -> LocalTask? {
    let pendingTaskIDs = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
    guard let firstTaskID = pendingTaskIDs.first else { return nil }

    // Fetch task from ModelContext
    // (existing pattern from MacFocusView)
    return modelContext.model(for: firstTaskID)
}

private func calculateRemainingTime(for task: LocalTask, in block: FocusBlock) -> Int? {
    guard let endDate = TimerCalculator.shared.plannedTaskEndDate(
        block: block,
        taskID: task.id,
        startTime: taskStartTime ?? block.startDate ?? Date()
    ) else { return nil }

    return TimerCalculator.shared.remainingSeconds(until: endDate, now: currentTime)
}

private func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d", minutes, secs)
}

private func formatBlockTime(_ block: FocusBlock) -> String {
    guard let endDate = block.endDate else { return "" }
    let remaining = TimerCalculator.shared.remainingSeconds(until: endDate, now: currentTime)
    return formatTime(remaining)
}
```

## Expected Behavior

### Input
- FocusBlock existiert in EventKit mit `isActive == true`
- Task aus `taskIDs` ist noch nicht in `completedTaskIDs`
- User klickt auf "Erledigt" oder "Weiter" Button

### Output
- Menu Bar Label zeigt Restzeit (mm:ss) des aktuellen Tasks
- Popover zeigt Block-Name, Fortschritt, aktuellen Task mit Restzeit
- Nach Complete/Skip Action: Block wird neu geladen, UI updated

### Side Effects
- Timer laeuft jede Sekunde bei aktivem Block (resourcen-intensiv, aber akzeptabel)
- Bei fehlendem aktiven Block: 60s Polling (gering)
- FocusBlockActionService veraendert Block in EventKit (markiert Task als completed/skipped)

## Known Limitations

1. **Kein Sprint Review im Popover** - bleibt im Hauptfenster (MacFocusView)
2. **Keine Vorwarnung/Sound** - MacFocusView haendelt bereits Notifications
3. **Keine Task-Queue** - nur aktueller Task sichtbar
4. **Kein Drag & Drop** - zu komplex fuer MenuBar Popover
5. **Doppelte Timer** - Popover + Hauptfenster haben beide eigene Timer (akzeptabel, leichtgewichtig)
6. **Task Start Time** - wird bei App-Neustart zurueckgesetzt (keine Persistierung)

## Acceptance Criteria

1. Menu Bar Label zeigt Restzeit (mm:ss) wenn ein Block aktiv ist
2. Menu Bar Label zeigt Checkmark wenn alle Tasks im Block erledigt sind
3. Popover zeigt Block-Namen, Restzeit und Fortschrittsbalken
4. Popover zeigt aktuellen Task-Namen mit Restzeit und geschaetzter Dauer
5. "Erledigt" Button markiert Task als erledigt via FocusBlockActionService
6. "Weiter" Button ueberspringt Task via FocusBlockActionService
7. Ohne aktiven Block: "☽ Kein aktiver Focus Block" anzeigen
8. Timer aktualisiert sich jede Sekunde bei aktivem Block
9. Ohne aktiven Block: Polling alle 60s, kein 1s-Timer

## Changelog

- 2026-02-16: Initial spec created
