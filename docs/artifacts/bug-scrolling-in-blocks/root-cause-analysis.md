# Bug: Scrolling in Focus Blocks nicht möglich

## Problem-Beschreibung
Im Tab "Zuordnen" kann nicht innerhalb eines Focus Blocks gescrollt werden, wenn es eine größere Menge an Tasks gibt.

## Root Cause

### Primäre Ursache: `.scrollDisabled(true)`

**Datei:** `TaskAssignmentView.swift`
**Zeile:** 331
**Code:**
```swift
List {
    ForEach(tasks) { task in
        TaskRowInBlock(task: task) { ... }
        // ...
    }
}
.listStyle(.plain)
.environment(\.editMode, .constant(.active))
.frame(minHeight: CGFloat(tasks.count * 44))  // Nur MINIMUM
.scrollDisabled(true)  // ❌ BLOCKIERT Scrolling!
```

### Warum das ein Problem ist:

1. **`.scrollDisabled(true)`** verhindert Scrolling innerhalb der List
2. **`.frame(minHeight:...)`** setzt nur eine Mindesthöhe, KEINE Maximalhöhe
3. Die FocusBlockCard wächst unbegrenzt mit mehr Tasks
4. Der äußere ScrollView scrollt die ganze Card - aber nicht die Tasks INNERHALB der Card
5. **Ergebnis:** Bei mehr als ~6-8 Tasks sind untere Tasks nicht erreichbar

### Sekundäre Ursache: Gleiches Pattern in BlockPlanningView

**Datei:** `BlockPlanningView.swift`
**Zeile:** 216
**Code:**
```swift
List {
    ForEach(focusBlocks) { block in
        // ...
    }
}
.listStyle(.plain)
.frame(minHeight: CGFloat(focusBlocks.count * 60))
.scrollDisabled(true)  // ❌ Gleiches Problem!
```

## Betroffene Views

| View | Datei | Zeile | Status |
|------|-------|-------|--------|
| FocusBlockCard | TaskAssignmentView.swift | 331 | ❌ Bug |
| existingBlocksSection | BlockPlanningView.swift | 216 | ❌ Bug |
| taskBacklog | TaskAssignmentView.swift | 101-135 | ⚠️ Potenziell |
| NextUpSection | NextUpSection.swift | 38-44 | ⚠️ Potenziell |

## Potenziell betroffene Bereiche

### taskBacklog (TaskAssignmentView.swift:101-135)
```swift
VStack(spacing: 6) {
    ForEach(unscheduledTasks) { task in
        DraggableTaskRow(...)
    }
}
```
- Kein ScrollView
- Bei vielen unassigned Tasks könnte Content abgeschnitten werden

### NextUpSection (NextUpSection.swift:38-44)
```swift
VStack(spacing: 6) {
    ForEach(tasks) { task in
        NextUpRow(task: task) { ... }
    }
}
```
- Kein ScrollView
- Bei vielen Next Up Tasks könnte Content abgeschnitten werden

## Fix-Strategie

### Option A: Maximale Höhe mit Scrolling (Empfohlen)
```swift
List {
    ForEach(tasks) { ... }
}
.listStyle(.plain)
.frame(maxHeight: 300)  // Feste Maximalhöhe
// KEIN .scrollDisabled(true)!
```

### Option B: Dynamische Höhe mit Threshold
```swift
let listHeight = min(CGFloat(tasks.count * 44), 300)

List { ... }
.frame(height: listHeight)
.scrollDisabled(tasks.count <= 6)  // Nur bei wenigen Tasks
```

**Empfehlung:** Option A - einfacher, vorhersagbar, funktioniert immer.
