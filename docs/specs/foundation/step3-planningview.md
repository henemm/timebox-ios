# Spec: Step 3 - PlanningView

**Status:** Draft
**Workflow:** step3-planningview
**Created:** 2026-01-13

---

## 1. Ziel

Split-View mit Kalender-Timeline und Mini-Backlog. Tasks per Drag & Drop in freie Zeitslots einplanen.

---

## 2. Architektur-Übersicht

```
┌─────────────────────────────────┐
│  TabView                        │
│  ┌───────────┬───────────┐      │
│  │  Backlog  │  Planning │      │
│  └───────────┴───────────┘      │
└─────────────────────────────────┘

PlanningView (wenn Planning Tab aktiv):
┌─────────────────────────────────┐
│  Timeline (ScrollView)          │
│  ┌─────────────────────────────┐│
│  │ 08:00  [████████████]       ││
│  │ 09:00  [    frei    ]       ││
│  │ 10:00  [████ Meeting]       ││
│  │ ...                         ││
│  └─────────────────────────────┘│
├─────────────────────────────────┤
│  Mini-Backlog (kompakt)         │
│  [Task A 15m] [Task B 30m] ...  │
└─────────────────────────────────┘
```

---

## 3. Komponenten

### 3.1 MainTabView (neu)

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            BacklogView()
                .tabItem { Label("Backlog", systemImage: "list.bullet") }

            PlanningView()
                .tabItem { Label("Planen", systemImage: "calendar") }
        }
    }
}
```

---

### 3.2 PlanningView

**Layout:** VStack mit Timeline oben (80%) und Mini-Backlog unten (20%).

```swift
struct PlanningView: View {
    @State private var selectedDate = Date()
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var unscheduledTasks: [PlanItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(
                    date: selectedDate,
                    events: calendarEvents,
                    onDrop: scheduleTask
                )

                Divider()

                MiniBacklogView(
                    tasks: unscheduledTasks
                )
                .frame(height: 120)
            }
            .navigationTitle("Planen")
            .toolbar {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
            }
        }
    }
}
```

---

### 3.3 TimelineView

Zeigt Stunden von 6:00-22:00 mit bestehenden Events.

```swift
struct TimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let onDrop: (PlanItem, Date) -> Void

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Hour grid lines
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HourRow(hour: hour)
                            .frame(height: hourHeight)
                    }
                }

                // Existing events overlay
                ForEach(events) { event in
                    EventBlock(event: event, hourHeight: hourHeight)
                }
            }
        }
        .dropDestination(for: PlanItemTransfer.self) { items, location in
            // Calculate drop time from Y position
            guard let item = items.first else { return false }
            let droppedTime = timeFromPosition(location.y)
            onDrop(item.planItem, droppedTime)
            return true
        }
    }
}
```

---

### 3.4 CalendarEvent (Model)

```swift
struct CalendarEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}
```

---

### 3.5 EventKitRepository Erweiterung

```swift
func fetchCalendarEvents(for date: Date) async throws -> [CalendarEvent] {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        throw EventKitError.notAuthorized
    }

    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

    let predicate = eventStore.predicateForEvents(
        withStart: startOfDay,
        end: endOfDay,
        calendars: nil
    )

    return eventStore.events(matching: predicate).map { CalendarEvent(from: $0) }
}
```

---

### 3.6 MiniBacklogView

Kompakte horizontale Liste der ungeplanten Tasks.

```swift
struct MiniBacklogView: View {
    let tasks: [PlanItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tasks) { task in
                    MiniTaskCard(task: task)
                        .draggable(PlanItemTransfer(planItem: task))
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}
```

---

### 3.7 Drag & Drop Transfer

```swift
struct PlanItemTransfer: Codable, Transferable {
    let id: String
    let title: String
    let duration: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: PlanItemTransfer.self, contentType: .planItem)
    }
}

extension UTType {
    static var planItem = UTType(exportedAs: "com.henning.timebox.planitem")
}
```

---

## 4. Permissions

Info.plist bereits vorhanden:
- `NSCalendarsUsageDescription` ✅

---

## 5. Dateien

| Datei | Aktion | LoC (ca.) |
|-------|--------|-----------|
| Views/MainTabView.swift | Neu | 20 |
| Views/PlanningView.swift | Neu | 80 |
| Views/TimelineView.swift | Neu | 100 |
| Views/MiniBacklogView.swift | Neu | 40 |
| Views/HourRow.swift | Neu | 25 |
| Views/EventBlock.swift | Neu | 35 |
| Views/MiniTaskCard.swift | Neu | 30 |
| Models/CalendarEvent.swift | Neu | 25 |
| Models/PlanItemTransfer.swift | Neu | 20 |
| Services/EventKitRepository.swift | Erweitern | +30 |
| TimeBoxApp.swift | Ändern | +5 |

**Gesamt:** 10 neue/geänderte Dateien, ~410 LoC

⚠️ **Überschreitet Scoping Limit (250 LoC)**

---

## 6. Empfehlung: Aufteilen

**Step 3a:** Tab Navigation + Timeline (ohne Drag & Drop)
- MainTabView, PlanningView, TimelineView, CalendarEvent
- ~200 LoC

**Step 3b:** Drag & Drop Integration
- MiniBacklogView, Transfer, Drop-Logik
- ~200 LoC

---

## 7. Test-Szenario (Step 3a)

1. App starten
2. Zwischen "Backlog" und "Planen" Tabs wechseln
3. Im Planen-Tab: Timeline mit Stunden sichtbar
4. Bestehende Kalender-Events werden angezeigt
