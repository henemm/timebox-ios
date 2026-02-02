# Context: macOS Backlog View (MAC-013)

## Request Summary
Backlog-Ansicht für macOS mit drei-Spalten Layout, Kategorien-Sidebar und Multi-Selection.

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxMac/ContentView.swift` | Aktuell 2-Spalten, wird zu 3-Spalten erweitert |
| `Sources/Views/BacklogView.swift` | iOS Reference: ViewModes, Filter-Logik |
| `Sources/Views/BacklogRow.swift` | iOS Row Component (nicht direkt nutzbar für macOS) |
| `Sources/Models/LocalTask.swift` | Shared Model |
| `Sources/Models/PlanItem.swift` | Shared ViewModel |
| `Sources/Services/SyncEngine.swift` | Shared Sync Logic |

## Existing Patterns

### iOS BacklogView Features
- 6 ViewModes: list, eisenhowerMatrix, category, duration, dueDate, tbd
- Next Up Section oben
- Pull-to-refresh
- Inline title editing (double-tap)
- Quick actions via metadata badges

### macOS-spezifische Patterns
- `NavigationSplitView` für 3-Spalten-Layout
- Native `List(selection:)` für Single/Multi-Selection
- `⌘-Click` für Multi-Select (automatisch)
- Sidebar mit `.sidebarListStyle()`

## Dependencies
- **Upstream:** LocalTask, PlanItem, SyncEngine (shared)
- **Downstream:** MAC-014 (Planning View) baut auf dieser View auf

## macOS-Adaptationen

### Nicht übernehmen von iOS:
- Sensory Feedback (nur iOS)
- Swipe Actions (macOS hat Context Menu)
- Touch-optimierte Chips

### Neue macOS Features:
- Sidebar mit Kategorien-Filter
- Multi-Selection mit Bulk Actions
- Inspector Panel rechts
- Sortierung via Column Headers
- Keyboard Navigation (bereits implementiert)

## Risks & Considerations
- Sidebar erfordert `columnVisibility` State für collapsible
- Multi-Selection muss mit Bulk Actions kombiniert werden
- Performance bei vielen Tasks (LazyVStack bereits in iOS verwendet)
