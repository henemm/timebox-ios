# Context: BACKLOG-013 macOS Text-Truncation in weiteren Views

## Request Summary
Bug 86 Fix (`.frame(maxWidth: .infinity)` auf VStack) auf 9 weitere macOS Views uebertragen, die dasselbe Truncation-Pattern haben.

## Related Files
| File | Relevance |
|------|-----------|
| FocusBloxMac/MacBacklogRow.swift | REFERENZ - bereits gefixte View |
| FocusBloxMac/MacPlanningView.swift | NextUpTaskRow - VStack ohne maxWidth |
| FocusBloxMac/MacAssignView.swift | MacTaskInBlockRow + MacDraggableTaskRow |
| FocusBloxMac/MacFocusView.swift | TaskQueueRow + MacReviewTaskRow |
| FocusBloxMac/MenuBarView.swift | 3 Instanzen (Block-Titel, Task-Titel, TaskRow) |
| FocusBloxMac/MacTimelineView.swift | FocusBlockView Header |

## Bug-Pattern
**Ursache:** VStack/Text ohne `.frame(maxWidth: .infinity)` in HStack mit Spacer().
SwiftUI gibt Spacer() Platz, Text wird komprimiert und mit "..." abgeschnitten.

**Fix-Pattern (aus MacBacklogRow):**
```swift
VStack(alignment: .leading, spacing: 4) {
    Text(task.title)
        .lineLimit(2)
        .truncationMode(.tail)
    metadataRow
}
.frame(maxWidth: .infinity, alignment: .leading)  // <-- DER FIX
```

## Zwei Varianten

### Variante A: VStack vorhanden (3 Views)
- NextUpTaskRow, MacDraggableTaskRow, MacReviewTaskRow
- Fix: `.frame(maxWidth: .infinity, alignment: .leading)` auf VStack

### Variante B: Text direkt in HStack (6 Views)
- TaskQueueRow, MenuBarView (3x), MacTimelineView, MacTaskInBlockRow
- Fix: `.frame(maxWidth: .infinity, alignment: .leading)` direkt auf Text

## Alle 9 Stellen
1. MacPlanningView - NextUpTaskRow (VStack)
2. MacAssignView - MacTaskInBlockRow (Text direkt)
3. MacAssignView - MacDraggableTaskRow (VStack)
4. MacFocusView - TaskQueueRow (Text direkt)
5. MacFocusView - MacReviewTaskRow (VStack)
6. MenuBarView - activeFocusSection Block-Titel (Text direkt)
7. MenuBarView - currentTaskRow Task-Titel (Text direkt)
8. MenuBarView - MenuBarTaskRow (Text direkt)
9. MacTimelineView - FocusBlockView Header (Text direkt)

## Analysis

### Type
Bug (Blast Radius von Bug 86)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| FocusBloxMac/MacPlanningView.swift | MODIFY | `.frame(maxWidth: .infinity)` auf NextUpTaskRow VStack |
| FocusBloxMac/MacAssignView.swift | MODIFY | Fix fuer MacTaskInBlockRow + MacDraggableTaskRow |
| FocusBloxMac/MacFocusView.swift | MODIFY | Fix fuer TaskQueueRow + MacReviewTaskRow |
| FocusBloxMac/MenuBarView.swift | MODIFY | Fix fuer 3 Text-Instanzen |
| FocusBloxMac/MacTimelineView.swift | MODIFY | Fix fuer FocusBlockView Header |

### Scope Assessment
- Files: 5
- Estimated LoC: ~9 Zeilen hinzugefuegt (je 1 Modifier pro Stelle)
- Risk Level: LOW — reine Layout-Modifier, keine Logik

### Technical Approach
Identischer Fix wie Bug 86: `.frame(maxWidth: .infinity, alignment: .leading)` auf den Container (VStack) oder direkt auf Text wenn kein VStack vorhanden.

### Risks
- Minimal: Nur Layout-Modifier, keine Logik-Aenderung
- MenuBarView hat begrenzte Breite (StatusBar-Popup) — lineLimit(1) bleibt, aber Text bekommt verfuegbare Breite
