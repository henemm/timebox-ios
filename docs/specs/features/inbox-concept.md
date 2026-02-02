---
entity_id: inbox-concept
type: feature
created: 2026-01-25
status: superseded
superseded_by: tbd-tasks
workflow: inbox-concept
user_story: docs/project/stories/quick-capture.md
---

# Inbox-Konzept

> **SUPERSEDED:** Dieses Konzept wurde ersetzt durch `tbd-tasks.md`
> Die "Inbox" Metapher wurde verworfen zugunsten von `tbd` (to be defined).

## Approval

- [ ] Approved for implementation

## Purpose

Quick Captures (von Watch, Widget, Spotlight) landen als "unverarbeitete" Items in einer **Inbox**. Der User sieht auf einen Blick, welche Tasks noch Details brauchen, und kann sie später anreichern.

**Prinzip:** Capture first, organize later.

## User Story Reference

> **When** mir unterwegs ein Gedanke einfällt,
> **I want to** ihn mit minimalem Aufwand festhalten,
> **So that** ich ihn später in Ruhe anreichern kann.

## Scope

| Datei | Änderung |
|-------|----------|
| `Sources/Models/LocalTask.swift` | +`isInbox: Bool` Feld |
| `Sources/Models/PlanItem.swift` | +`isInbox` Property |
| `Sources/Views/BacklogView.swift` | +ViewMode `.inbox`, +Badge im Toggle |
| `Sources/Views/TaskDetailSheet.swift` | "Aus Inbox entfernen" beim Speichern |

**Estimated:** +50 / -5 LoC

## Konzept

### Was ist "Inbox"?

Ein Task ist in der Inbox wenn:
- Er via Quick Capture erstellt wurde (Watch, Widget, Spotlight)
- Er noch nicht vom User "verarbeitet" wurde

### Wann verlässt ein Task die Inbox?

Ein Task verlässt die Inbox (`isInbox = false`) wenn:
1. User öffnet TaskDetailSheet und tippt "Speichern"
2. User verschiebt Task nach "Next Up"
3. User markiert Task als erledigt

**Rationale:** Jede bewusste Interaktion mit dem Task zeigt, dass er "verarbeitet" wurde.

### Inbox als ViewMode (nicht als Section)

**Warum ViewMode statt Section?**
- Vermeidet Überladung (Inbox + Next Up + Backlog = zu viel)
- Bewusster Wechsel in "Verarbeitungsmodus"
- Inbox-Ansicht kann eigene Optimierungen haben

**ViewMode Toggle:**
```
Liste | Matrix | Kategorie | Dauer | Fälligkeit | Inbox
                                                   ↑
                                              Badge (3)
```

### Visuelle Darstellung

**Inbox ViewMode aktiv:**
```
┌─────────────────────────────────────┐
│ [Liste] [Matrix] [...] [Inbox (3)] │  ← Badge zeigt Anzahl
├─────────────────────────────────────┤
│ 📥 Unverarbeitete Captures          │
├─────────────────────────────────────┤
│ ○ Steuererklärung                   │
│     Erfasst: Heute, 14:32           │
│ ○ Zahnarzt anrufen                  │
│     Erfasst: Gestern                │
│ ○ Idee: App für...                  │
│     Erfasst: Mo, 13:15              │
└─────────────────────────────────────┘
```

**Andere ViewModes:** Inbox-Tasks werden NICHT angezeigt (erst nach Verarbeitung)

### Inbox Badge im Toggle

- Zeigt Anzahl unverarbeiteter Items: "Inbox (3)"
- Rot/Orange wenn > 0 (Aufmerksamkeit)
- Kein Badge wenn Inbox leer

### Quick Capture Defaults

Wenn ein Task via Quick Capture erstellt wird:

```swift
LocalTask(
    title: capturedText,
    isInbox: true,           // NEU
    priority: 2,             // Mittel (später: "Wichtigkeit")
    urgency: "not_urgent",   // Default
    taskType: "maintenance", // Default
    manualDuration: nil      // Default (15 min)
)
```

## Implementation Details

### 1. LocalTask.swift - Neues Feld

```swift
/// Marks task as unprocessed Quick Capture (needs review)
var isInbox: Bool = false
```

### 2. PlanItem.swift - Property durchreichen

```swift
let isInbox: Bool

init(localTask: LocalTask) {
    // ...existing...
    self.isInbox = localTask.isInbox
}
```

### 3. BacklogView.swift - Inbox ViewMode

```swift
// ViewMode enum erweitern:
enum ViewMode: String, CaseIterable, Identifiable {
    case list = "Liste"
    case eisenhowerMatrix = "Matrix"
    case category = "Kategorie"
    case duration = "Dauer"
    case dueDate = "Fälligkeit"
    case inbox = "Inbox"           // NEU

    var icon: String {
        switch self {
        // ...existing...
        case .inbox: return "tray.and.arrow.down"
        }
    }
}

// Inbox Tasks Filter:
private var inboxTasks: [PlanItem] {
    planItems.filter { $0.isInbox && !$0.isCompleted }
}

// Inbox Badge für Toggle:
private var inboxBadgeCount: Int {
    inboxTasks.count
}

// In body - ViewMode Switch:
case .inbox:
    inboxListView

// Inbox View:
@ViewBuilder
private var inboxListView: some View {
    if inboxTasks.isEmpty {
        ContentUnavailableView(
            "Inbox leer",
            systemImage: "tray",
            description: Text("Keine unverarbeiteten Captures")
        )
    } else {
        List {
            ForEach(inboxTasks) { item in
                InboxRow(item: item, onProcess: { processInboxItem(item) })
            }
        }
    }
}
```

### WICHTIG: Inbox-Tasks in anderen Views ausblenden

```swift
// Alle anderen Views filtern Inbox-Tasks RAUS:
private var backlogTasks: [PlanItem] {
    planItems.filter { !$0.isCompleted && !$0.isNextUp && !$0.isInbox }
    //                                                    ^^^^^^^^^^^
}
```

### 4. TaskDetailSheet - Inbox verlassen

```swift
// Beim Speichern:
func saveTask() {
    // ... existing save logic ...

    // Mark as processed (leaves Inbox)
    if let localTask = findLocalTask(id: task.id) {
        localTask.isInbox = false
    }
}
```

### 5. Next Up - Inbox verlassen

```swift
func moveToNextUp(task: PlanItem) {
    // ... existing logic ...

    // Also mark as processed
    if let localTask = findLocalTask(id: task.id) {
        localTask.isInbox = false
    }
}
```

## Data Flow

```
Quick Capture (Watch/Widget/Spotlight)
    ↓
LocalTask.create(title: "...", isInbox: true)
    ↓
Task erscheint in Inbox Section
    ↓
User tippt auf Task → TaskDetailSheet
    ↓
User ergänzt Details + Speichern
    ↓
isInbox = false
    ↓
Task erscheint in normalem Backlog
```

## Test Plan

### Unit Tests

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testInboxTaskCreation` | - | Quick Capture Task erstellt | `isInbox == true` |
| `testInboxToBacklogOnSave` | Inbox Task | TaskDetailSheet speichern | `isInbox == false` |
| `testInboxToBacklogOnNextUp` | Inbox Task | Nach Next Up verschieben | `isInbox == false` |
| `testInboxFilteredCorrectly` | 3 Inbox, 2 normale Tasks | `inboxTasks` abfragen | Count == 3 |

### UI Tests

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testInboxViewModeExists` | BacklogView | ViewMode Toggle sichtbar | "Inbox" Option vorhanden |
| `testInboxBadgeShowsCount` | 3 Inbox Tasks | BacklogView öffnen | Badge zeigt "(3)" |
| `testInboxBadgeHiddenWhenEmpty` | 0 Inbox Tasks | BacklogView öffnen | Kein Badge |
| `testInboxViewShowsTasks` | 2 Inbox Tasks | Inbox ViewMode wählen | 2 Tasks sichtbar |
| `testInboxTaskNotInListView` | 1 Inbox Task | Liste ViewMode | Task NICHT sichtbar |
| `testInboxTaskProcessing` | Inbox Task | Öffnen + Speichern | Task in Liste, nicht mehr Inbox |

## Acceptance Criteria

- [ ] Neues `isInbox` Feld in LocalTask
- [ ] "Inbox" als neuer ViewMode im Toggle
- [ ] Badge im Toggle zeigt Anzahl unverarbeiteter Items (wenn > 0)
- [ ] Inbox-Tasks werden in anderen ViewModes NICHT angezeigt
- [ ] Task verlässt Inbox bei: Speichern, Next Up, Erledigt
- [ ] Inbox ViewMode zeigt "createdAt" Timestamp pro Task

## Edge Cases

1. **Migration:** Bestehende Tasks haben `isInbox = false` (default)
2. **Sync:** Wenn Task von Reminders kommt → `isInbox = false` (nicht Quick Capture)
3. **Manuell erstellt:** Tasks via "+" Button → `isInbox = false` (volles Formular)

## Future Considerations

- "Inbox Zero" Achievement/Motivation
- Bulk-Processing von Inbox Items
- Inbox Reminder ("Du hast 5 unverarbeitete Items")

## Changelog

- 2026-01-25: Initial spec
