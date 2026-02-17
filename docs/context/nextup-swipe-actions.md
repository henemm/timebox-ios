# Context: NextUp Swipe Actions (Edit + Delete)

## Request Summary
NextUp-Tasks sollen per Swipe bearbeitet und gelöscht werden können - gleiche Wischgesten wie im Backlog (Trailing: Löschen + Bearbeiten), aber kein Leading-Swipe (kein Next Up Toggle nötig).

## Related Files
| File | Relevance |
|------|-----------|
| Sources/Views/NextUpSection.swift | Enthält NextUpSection + NextUpRow - hier müssen Swipe Actions hin |
| Sources/Views/BacklogView.swift | Hosting-View, enthält die Callbacks (deleteTask, taskToEditDirectly) + Referenz-Swipe-Pattern |
| FocusBloxMac/ContentView.swift | macOS nutzt NICHT NextUpSection shared, hat eigene inline-Implementierung in einer List |

## Existing Patterns

### Backlog Swipe Actions (Referenz-Pattern)
BacklogView.swift:572-593 - auf List-Rows:
- Leading: Next Up (green, fullSwipe)
- Trailing: Delete (destructive) + Edit (blue)
- `.swipeActions(edge: .trailing, allowsFullSwipe: false)`

### NextUpSection aktuell
- Nutzt **VStack** (nicht List!) → `.swipeActions` funktioniert NICHT
- ForEach rendert NextUpRow in VStack
- NextUpRow hat nur "xmark remove" Button
- Callbacks: nur `onRemoveFromNextUp: (String) -> Void`

### macOS NextUp (ContentView.swift)
- Eigene inline-Implementierung
- Nutzt `List` mit `Section` → swipeActions würden theoretisch dort funktionieren
- Rendert `makeBacklogRow` für NextUp tasks → hat gleiche Funktionalität wie Backlog-Rows

## Architektur-Problem
`.swipeActions` ist ein SwiftUI Modifier der **nur auf List-Rows** funktioniert. NextUpSection nutzt VStack mit eigenem Card-Styling (blaue Umrandung, blauer Hintergrund).

### Lösungsansätze
1. **VStack → List konvertieren**: NextUpSection intern auf List umstellen mit `.listStyle(.plain)`, Swipe Actions hinzufügen
2. **NextUp in BacklogView-List integrieren**: NextUp-Tasks als Section in die bestehende List einbauen (wie macOS es macht)
3. **Custom Swipe Gesture**: Eigene Drag-Gesture auf NextUpRow implementieren

## Dependencies
- Upstream: PlanItem (Model), SyncEngine (deleteTask), TaskFormSheet (Edit-UI)
- Downstream: BacklogView (hostet NextUpSection, liefert Callbacks)

## Existing Specs
- Keine bestehende Spec für NextUpSection

## Risks & Considerations
- VStack→List Konvertierung ändert das visuelle Erscheinungsbild
- NextUpSection ist in ALLEN View-Modes sichtbar (nicht nur List-Mode)
- List-in-VStack kann Scrolling-Konflikte verursachen
- macOS nutzt NextUpSection nicht direkt → Änderung betrifft nur iOS
