---
entity_id: focus-block-reorder
type: feature
created: 2026-01-31
status: approved
workflow: focus-block-reorder
---

# Focus Block Task Reordering

## Approval

- [x] Approved for implementation (2026-01-31)

## Purpose

Tasks innerhalb eines Focus Blocks per Drag & Drop umsortieren. Die Reihenfolge bestimmt, welcher Task als nächstes bearbeitet wird (erster Task = aktueller Task im Focus Tab).

## Scope

**Files:**
- `Sources/Views/TaskAssignmentView.swift` (MODIFY)
- `FocusBloxUITests/FocusBlockReorderUITests.swift` (CREATE)

**Estimated:** +80/-10 LoC

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBlock` | Model | Speichert `taskIDs` Array (Reihenfolge) |
| `EventKitRepository` | Service | `updateFocusBlock()` persistiert neue Ordnung |
| `PlanItemTransfer` | Transferable | Bereits für Inter-Block Drag verwendet |

## Implementation Details

### 1. TaskRowInBlock erweitern

```swift
struct TaskRowInBlock: View {
    let task: PlanItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // NEU: Drag-Handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("dragHandle_\(task.id)")

            // Bestehender Content...
        }
        .draggable(PlanItemTransfer(from: task))  // NEU
    }
}
```

### 2. FocusBlockCard mit Reorder-Logic

```swift
// State für Reihenfolge während Drag
@State private var orderedTaskIDs: [String]

// ForEach mit dropDestination pro Row
ForEach(orderedTasks) { task in
    TaskRowInBlock(task: task, onRemove: { ... })
        .dropDestination(for: PlanItemTransfer.self) { items, _ in
            // Reorder-Logik: Task an diese Position einfügen
            reorderTask(draggedID: items.first?.id, targetID: task.id)
            return true
        }
}
```

### 3. Reorder-Logik

```swift
private func reorderTask(draggedID: String?, targetID: String) {
    guard let draggedID, draggedID != targetID else { return }

    var newOrder = orderedTaskIDs
    newOrder.removeAll { $0 == draggedID }

    if let targetIndex = newOrder.firstIndex(of: targetID) {
        newOrder.insert(draggedID, at: targetIndex)
    }

    orderedTaskIDs = newOrder
    onReorderTasks(newOrder)
}
```

## Test Plan

### UI Tests (TDD RED)

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testDragHandleExists` | Focus Block mit 2+ Tasks | Assign Tab öffnen | Drag-Handle (≡) sichtbar bei jedem Task |
| `testReorderFirstToSecond` | Block mit Tasks [A, B, C] | Task A unter Task B ziehen | Reihenfolge ist [B, A, C] |
| `testReorderLastToFirst` | Block mit Tasks [A, B, C] | Task C über Task A ziehen | Reihenfolge ist [C, A, B] |
| `testReorderPersistsAfterReload` | Block mit Tasks [A, B] | Reorder zu [B, A], Tab wechseln, zurück | Reihenfolge bleibt [B, A] |

### Manuell (optional)

- [ ] Haptic Feedback beim Drag spürbar
- [ ] Animation flüssig

## Acceptance Criteria

- [ ] Drag-Handle (≡) bei jedem Task im Focus Block sichtbar
- [ ] Long-Press + Drag ändert Reihenfolge
- [ ] Neue Reihenfolge wird sofort in EventKit persistiert
- [ ] Focus Tab zeigt Tasks in neuer Reihenfolge
- [ ] Accessibility-Identifier bleiben erhalten

## Edge Cases

| Case | Verhalten |
|------|-----------|
| Block mit nur 1 Task | Drag-Handle sichtbar, aber Drag hat keine Wirkung |
| Leerer Block | Keine Tasks, kein Drag möglich |
| Drop auf gleiche Position | Keine Änderung |

## Changelog

- 2026-01-31: Initial spec created
