# Context: Focus Block Reorder

## Request Summary
Tasks innerhalb eines Focus Blocks per Drag & Drop umsortieren. Die Reihenfolge bestimmt, welcher Task als nächstes bearbeitet wird.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/FocusBlock.swift` | Datenmodell - `taskIDs: [String]` Array definiert Reihenfolge |
| `Sources/Models/CalendarEvent.swift` | Parsing - lädt Ordnung aus Calendar Event Notes |
| `Sources/Services/EventKitRepository.swift` | Persistierung - `updateFocusBlock()` speichert neue Ordnung |
| `Sources/Views/TaskAssignmentView.swift` | UI - `FocusBlockCard` zeigt Tasks, hier wird Reordering implementiert |
| `Sources/Views/FocusLiveView.swift` | Lesend - zeigt aktuelle Ordnung während Block läuft |

## Existing Patterns

### Reihenfolge-Speicherung
- `FocusBlock.taskIDs` ist ein `[String]` Array - Reihenfolge = Array-Reihenfolge
- Serialisierung: `tasks:id1|id2|id3` in Calendar Event Notes (Pipe-separated)
- Parsing: `CalendarEvent.focusBlockTaskIDs` extrahiert IDs in korrekter Reihenfolge

### Drag & Drop (Inter-Block)
- `DraggableTaskRow` für Drag aus Next-Up in einen Block
- `FocusBlockCard.dropDestination()` für Drop-Ziel
- `PlanItemTransfer` als Transferable-Typ
- Handler: `assignTaskToBlock()` fügt Task am Ende ein

### Skip-Logik (bereits vorhanden)
```swift
// In FocusLiveView - verschiebt Task ans Ende
updatedTaskIDs.remove(at: index)
updatedTaskIDs.append(taskID)
eventKitRepo.updateFocusBlock(eventID: block.id, taskIDs: updatedTaskIDs, ...)
```

## Dependencies

**Upstream:**
- EventKitRepository für Persistierung
- FocusBlock Model für Datenstruktur
- PlanItem/LocalTask für Task-Daten

**Downstream:**
- FocusLiveView liest Reihenfolge für Current/Upcoming Tasks
- SprintReviewSheet zeigt Tasks in Reihenfolge

## Existing Specs
- `docs/specs/models/focus-block.md` (falls vorhanden)
- `docs/specs/features/live-activity.md` - nutzt FocusBlock

## Technical Status

### Bereits implementiert
- Reihenfolge-Speicherung in `FocusBlock.taskIDs`
- Serialisierung/Deserialisierung funktioniert
- `EventKitRepository.updateFocusBlock()` akzeptiert neue Ordnung
- `reorderTasksInBlock()` Callback existiert in TaskAssignmentView

### Fehlt
- `.onMove()` Modifier in FocusBlockCard für Intra-Block Reordering
- Edit-Mode für sichtbare Reorder-Controls (Drag-Handle)
- UI-Feedback während Drag

## Risks & Considerations

1. **Completed Tasks** - Sollten nicht reorder-bar sein (bereits im `completedTaskIDs` Array)
2. **Leere Blocks** - Edge Case: Block ohne Tasks
3. **Gleichzeitiger Edit** - Block könnte während Reorder vom User gelöscht werden
4. **Accessibility** - VoiceOver Support für Reordering
5. **Konsistenz** - FocusLiveView muss neue Ordnung sofort zeigen

---

## Analysis

### Code-Analyse (TaskAssignmentView.swift)

**Aktueller Stand:**
- `FocusBlockCard` (Zeilen 304-410) zeigt Tasks in einem `VStack` (Zeile 380)
- `onReorderTasks: ([String]) -> Void` Callback existiert bereits (Zeile 309)
- `reorderTasksInBlock()` Handler ist implementiert (Zeilen 251-267)
- **Problem:** Kein `.onMove()` Modifier vorhanden

**Warum VStack statt List?**
Kommentar Zeile 378-379: "Use VStack instead of List to preserve accessibility identifiers (List with editMode absorbs cell accessibility)"

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/TaskAssignmentView.swift` | MODIFY | Drag-Handle + `.draggable()`/`.dropDestination()` in TaskRowInBlock |
| `FocusBloxUITests/FocusBlockReorderUITests.swift` | CREATE | UI Tests für Drag & Drop Reordering |

### Scope Assessment
- **Files:** 2 (1 MODIFY, 1 CREATE)
- **Estimated LoC:** +80/-10
- **Risk Level:** LOW (Backend bereits fertig, nur UI-Interaktion)

### Technical Approach

**Empfehlung:** Intra-Block Drag & Drop mit `.draggable()` + `.dropDestination()`

1. **TaskRowInBlock erweitern:**
   - Drag-Handle Icon links hinzufügen (≡ oder grip-lines)
   - `.draggable(PlanItemTransfer(from: task))` Modifier
   - `.dropDestination()` für Drop zwischen Rows

2. **FocusBlockCard anpassen:**
   - State für aktuelle Reihenfolge während Drag
   - Animation bei Reorder
   - `onReorderTasks()` Callback aufrufen bei Drop

3. **Keine List verwenden** - Accessibility-Identifier bleiben erhalten

**Vorteile:**
- Konsistent mit bestehendem Drag-Pattern (Next-Up → Block)
- Kein Edit-Mode Button nötig
- Accessibility bleibt intakt

### Open Questions
- [x] Wie soll der Drag-Handle aussehen? → Standard iOS grip-lines Icon
