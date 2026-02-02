---
entity_id: MAC-014
type: feature
created: 2026-01-31
status: done
workflow: macos-planning-view
---

# MAC-014: Planning View

- [ ] Approved for implementation

## Purpose

Tagesplanung-Ansicht für macOS mit Kalender-Timeline und Side-by-Side Task-Liste. Ermöglicht schnelle Planung durch Drag & Drop von Tasks in freie Zeitslots.

## Scope

**Files:**
- `FocusBloxMac/MacPlanningView.swift` (CREATE)
- `FocusBloxMac/MacTimelineView.swift` (CREATE)
- `FocusBloxMac/FocusBloxMacApp.swift` (MODIFY - Tab hinzufügen)
- `FocusBloxMac/FocusBloxMac.entitlements` (MODIFY - Kalender-Zugriff)

**Estimated:** +250 / -5 LoC

## Implementation Details

### 1. Entitlements für Kalender-Zugriff

```xml
<key>com.apple.security.personal-information.calendars</key>
<true/>
```

### 2. MacPlanningView (Hauptansicht)

```swift
struct MacPlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var nextUpTasks: [LocalTask] = []

    var body: some View {
        HSplitView {
            // Links: Timeline mit Kalender-Events
            MacTimelineView(
                date: selectedDate,
                events: calendarEvents,
                focusBlocks: focusBlocks
            )
            .frame(minWidth: 400)

            // Rechts: Next Up Tasks zum Einplanen
            NextUpTaskList(
                tasks: nextUpTasks,
                onCreateFocusBlock: createFocusBlock
            )
            .frame(minWidth: 250, maxWidth: 350)
        }
        .toolbar {
            ToolbarItem {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }
}
```

### 3. MacTimelineView (Stunden-Grid)

```swift
struct MacTimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]

    // 6:00 - 22:00 Uhr anzeigen
    private let startHour = 6
    private let endHour = 22
    private let hourHeight: CGFloat = 60

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Hour Grid Lines
                HourGridView(startHour: startHour, endHour: endHour, hourHeight: hourHeight)

                // Calendar Events (readonly, grau)
                ForEach(events.filter { !$0.isFocusBlock }) { event in
                    EventBlock(event: event, hourHeight: hourHeight, startHour: startHour)
                        .opacity(0.6)
                }

                // Focus Blocks (interaktiv, farbig)
                ForEach(focusBlocks) { block in
                    FocusBlockView(block: block, hourHeight: hourHeight, startHour: startHour)
                }

                // Free Slots (Drop Targets)
                FreeSlotOverlay(events: events, focusBlocks: focusBlocks)
            }
        }
    }
}
```

### 4. Next Up Task List (Drag Source)

```swift
struct NextUpTaskList: View {
    let tasks: [LocalTask]
    let onCreateFocusBlock: (LocalTask, Date) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Next Up")
                .font(.headline)
                .padding()

            List(tasks, id: \.uuid) { task in
                TaskDragRow(task: task)
                    .draggable(TaskTransfer(task: task))
            }
        }
    }
}
```

### 5. App-Integration (Tab oder Segment)

```swift
// In FocusBloxMacApp oder ContentView
TabView {
    ContentView()
        .tabItem { Label("Backlog", systemImage: "tray.full") }

    MacPlanningView()
        .tabItem { Label("Planen", systemImage: "calendar") }
}
```

## Test Plan

### Build Verification (TDD RED)

- [ ] Test 1: `MacPlanningView.swift` existiert
- [ ] Test 2: `MacTimelineView.swift` existiert
- [ ] Test 3: Calendar Entitlement vorhanden
- [ ] Test 4: macOS Build kompiliert
- [ ] Test 5: iOS Build keine Regression

### Manual Verification (nach Implementation)

- [ ] Kalender-Permission-Dialog erscheint
- [ ] Timeline zeigt heutige Termine
- [ ] Focus Blocks sind visuell unterscheidbar
- [ ] Next Up Tasks werden angezeigt
- [ ] Freie Zeitslots sind erkennbar

## Acceptance Criteria

- [ ] Kalender zeigt heutige Termine (readonly)
- [ ] Freie Blöcke visuell erkennbar
- [ ] Next Up Tasks in Seitenleiste
- [ ] Tab-Navigation zwischen Backlog und Planen
- [ ] macOS und iOS Builds erfolgreich

## Dependencies

- MAC-001: App Foundation ✅
- MAC-013: Backlog View ✅

## Out of Scope (MAC-020)

- Drag & Drop von Tasks in Timeline
- Focus Block erstellen via Drop
- Tasks zwischen Focus Blocks verschieben

## Notes

Drag & Drop wird in MAC-020 implementiert. Diese View bereitet die UI vor und zeigt die Daten an.
