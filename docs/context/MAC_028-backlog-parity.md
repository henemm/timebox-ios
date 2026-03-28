# Context: MAC_028 — Backlog Paritaet (Parkdeck + Stacking)

## Request Summary
macOS Backlog soll Parkdeck-Metapher (collapsed Sektion fuer low-prio/geparkte Tasks) und Recurring Stacking (visuelle Gruppierung verpasster Recurring-Instanzen mit Badge) erhalten — beides existiert bereits auf iOS.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/ContentView.swift` | macOS Backlog-Rendering, hier kommen Parkdeck-Sektion + Stacking-Gruppierung rein |
| `FocusBloxMac/MacBacklogRow.swift` | macOS Task-Row, braucht Stacking-Badge |
| `Sources/Views/BacklogView.swift` | iOS Referenz: activeTasks/parkdeckTasks Splitting, Stacking-Gruppierung |
| `Sources/Views/BacklogRow.swift` | iOS Referenz: Stacking-Badge Rendering (Zeilen 219-230) |
| `Sources/Models/PlanItem.swift` | isParked, isInParkdeck, stackedInstanceCount |
| `Sources/Models/LocalTask.swift` | isParked: Bool Feld (Zeile 126) |
| `Sources/Services/TaskPriorityScoringService.swift` | stackingBoost() Funktion (Zeilen 158-160) |

## Existing Patterns

### Parkdeck (iOS)
- `PlanItem.isInParkdeck` = `isParked || priorityTier == .eventually || .someday`
- BacklogView splittet in activeTasks (doNow/planSoon, nicht geparkt) und parkdeckTasks
- Parkdeck-Sektion collapsed by default, Header mit Badge-Count
- Swipe: "Parken" (car.fill) bzw "Aktivieren" (arrow.up.circle)

### Stacking (iOS)
- Gruppierung nach `recurrenceGroupID` — aelteste Instanz wird Representative
- `stackedInstanceCount` am Representative gesetzt (nicht persistiert)
- Badge: x2 secondary, x3+ orange mit Capsule-Background
- Row-Tint: ab x3 orange.opacity(0.06)
- Completion: nur aelteste Instanz wird completed
- Priority Boost: +5 pro Extra-Instanz, max +15

### macOS Unterschiede
- Verwendet `LocalTask` direkt (kein PlanItem-DTO)
- Context Menus statt Swipe Actions
- Flat Tier-Sektionen (doNow/planSoon/eventually/someday)

## Dependencies
- Upstream: LocalTask.isParked, LocalTask.recurrenceGroupID, TaskPriorityScoringService.stackingBoost()
- Downstream: MacBacklogRow rendert Tasks, ContentView steuert Sektionen

## Existing Specs
- `docs/specs/rework/2.4-backlog-ux-rework-impl.md` — Parkdeck iOS Spec
- `docs/specs/rework/3.5-recurring-stacking-impl.md` — Stacking iOS Spec

## Risks & Considerations
- macOS nutzt LocalTask direkt → Stacking-Gruppierung muss auf LocalTask-Ebene passieren
- Park/Activate als Context Menu Items (nicht Swipe)
- Stacking-Completion muss aelteste Instanz finden → gleiche Logik wie iOS SyncEngine

---

## Analysis

### Type
Feature (macOS Paritaet)

### Key Finding
`parkTask()` und `activateTask()` existieren bereits in ContentView.swift (Zeilen 866-883). Parkdeck UI-Sektion und Stacking-Gruppierung fehlen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | Parkdeck-Sektion (collapsed), Stacking-Gruppierung, Context Menu Park/Activate, Stacked Completion |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | Stacking-Badge (x2/x3+), orange Tint bei >=3 |

### Scope Assessment
- Files: 2 (Production)
- Estimated LoC: ~130-150 (Production), ~150 (Tests)
- Risk Level: LOW — alle Model-Felder + Services existieren bereits

### Technical Approach
1. **Parkdeck-Sektion:** `isParkdeckExpanded` State + computed properties `activeTasks`/`parkdeckTasks` basierend auf `isParked`/Tier. Collapsed Section mit Badge-Count. Ersetzt eventually/someday Tier-Sektionen.
2. **Stacking-Gruppierung:** `groupStackedTasks()` Funktion die nach `recurrenceGroupID` gruppiert. Aelteste Instanz als Representative mit `stackedInstanceCount`. Anwenden in `filteredTasks` Pipeline.
3. **Stacking-Badge:** In MacBacklogRow — Badge "x2" (secondary), "x3+" (orange Capsule). Row-Tint ab x3.
4. **Stacked Completion:** Bei Completion eines gestackten Tasks → aelteste Instanz finden und nur diese completen.
5. **Context Menu:** Park/Activate Items hinzufuegen (Funktionen existieren bereits).

### Dependencies
- **Vorhanden:** LocalTask.isParked, LocalTask.recurrenceGroupID, TaskPriorityScoringService, DeferredCompletionController
- **Keine neuen Dependencies noetig**

### Open Questions
- Keine — Scope ist klar definiert durch iOS-Referenzimplementation
