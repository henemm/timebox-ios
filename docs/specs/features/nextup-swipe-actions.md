---
entity_id: nextup-swipe-actions
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.0"
tags: [nextup, swipe, backlog, ios]
---

# NextUp Swipe Actions (Edit + Delete)

## Approval

- [ ] Approved

## Purpose

NextUp-Tasks im Backlog sollen per Swipe bearbeitet und geloescht werden koennen - gleiche Trailing-Wischgesten wie bei normalen Backlog-Tasks. Kein Leading-Swipe (kein Next Up Toggle noetig, da Tasks bereits in Next Up sind).

## Source

- **Files:** `Sources/Views/NextUpSection.swift`, `Sources/Views/BacklogView.swift`
- **Identifier:** `NextUpSection`, `NextUpRow`, `BacklogView.listView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| PlanItem | Model | Task-Daten |
| BacklogView | View | Hosting-View mit deleteTask/taskToEditDirectly |
| TaskFormSheet | View | Edit-Sheet fuer Task-Bearbeitung |
| SyncEngine | Service | deleteTask() Logik |

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/NextUpSection.swift | MODIFY | Neue Callbacks onEditTask + onDeleteTask, Swipe Actions auf NextUpRow |
| Sources/Views/BacklogView.swift | MODIFY | Callbacks an NextUpSection durchreichen |

**Estimated LoC:** +25/-5

## Implementation Details

### Ansatz: Swipe Actions direkt auf NextUpRow

Da `.swipeActions` nur auf `List`-Rows funktioniert, wird die innere Darstellung der NextUpSection von `VStack` + `ForEach` auf `List` + `ForEach` umgestellt (nur der Task-Bereich, Header bleibt).

### Aenderungen an NextUpSection

```swift
struct NextUpSection: View {
    let tasks: [PlanItem]
    let onRemoveFromNextUp: (String) -> Void
    let onEditTask: (PlanItem) -> Void      // NEU
    let onDeleteTask: (PlanItem) -> Void     // NEU

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header bleibt identisch
            ...

            if tasks.isEmpty {
                // Empty state bleibt identisch
            } else {
                // VStack -> List mit .listStyle(.plain)
                List {
                    ForEach(tasks) { task in
                        NextUpRow(task: task) {
                            onRemoveFromNextUp(task.id)
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDeleteTask(task)
                            } label: {
                                Label("Loeschen", systemImage: "trash")
                            }
                            Button {
                                onEditTask(task)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(tasks.count) * 50)
                .scrollDisabled(true)
            }
        }
        // Card-Styling bleibt identisch
    }
}
```

### Aenderungen an BacklogView

```swift
NextUpSection(
    tasks: nextUpTasks,
    onRemoveFromNextUp: { taskID in
        if let item = planItems.first(where: { $0.id == taskID }) {
            updateNextUp(for: item, isNextUp: false)
        }
    },
    onEditTask: { task in          // NEU
        taskToEditDirectly = task
    },
    onDeleteTask: { task in        // NEU
        deleteTask(task)
    }
)
```

## Expected Behavior

- **Trailing Swipe (rechts-wisch):** Zeigt "Loeschen" (rot, destructive) + "Bearbeiten" (blau)
- **Loeschen:** Ruft `deleteTask()` auf - Task wird komplett geloescht
- **Bearbeiten:** Oeffnet `TaskFormSheet` ueber `taskToEditDirectly`
- **Kein Leading Swipe:** Kein Next Up Toggle (Task ist bereits in Next Up)
- **Bestehendes xmark-Button:** Bleibt erhalten (entfernt Task aus Next Up, loescht nicht)

## Test Plan

### UI Tests (FocusBloxUITests)

1. **testNextUpSwipeDeleteExists** - Trailing Swipe auf NextUp-Task zeigt Loeschen-Button
2. **testNextUpSwipeEditExists** - Trailing Swipe auf NextUp-Task zeigt Bearbeiten-Button
3. **testNextUpNoLeadingSwipe** - Kein Leading-Swipe vorhanden

### Unit Tests (FocusBloxTests)

Keine neuen Unit Tests noetig - deleteTask/taskToEditDirectly sind bereits getestet.

## Known Limitations

- Swipe Actions funktionieren nur im iOS Backlog (nicht auf macOS - dort eigene Implementierung)
- Die List-Hoehe wird dynamisch berechnet basierend auf Task-Count. Bei vielen NextUp-Tasks koennte die Hoehe zu gross werden
- `.scrollDisabled(true)` verhindert inneres Scrolling der NextUp-List

## Changelog

- 2026-02-16: Initial spec created
