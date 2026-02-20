# Context: Generische Suche (iOS + macOS)

## Request Summary
Suchfeld im Backlog (iOS + macOS), das Tasks nach Titel, Tags und Kategorie filtert.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift` | iOS Backlog — hier kommt `.searchable()` hin |
| `FocusBloxMac/ContentView.swift` | macOS Backlog — eigene Search-State noetig |
| `Sources/Models/PlanItem.swift` | iOS Task-Wrapper — Felder: title, tags, taskType |
| `Sources/Models/LocalTask.swift` | SwiftData Model — gleiche Felder, von macOS direkt genutzt |
| `Sources/Models/TaskCategory.swift` | Kategorie-Enum mit `localizedName` fuer Suche |
| `Sources/Views/BacklogRow.swift` | iOS Row — keine Aenderung noetig |
| `FocusBloxMac/MacBacklogRow.swift` | macOS Row — keine Aenderung noetig |

## Existing Patterns

### iOS BacklogView
- 8 ViewModes (list, matrix, category, duration, dueDate, tbd, completed, recurring, aiRecommended)
- Filtering via computed properties auf `planItems: [PlanItem]`
- Kein `.searchable()` vorhanden
- Tasks kommen via `LocalTaskSource` + `SyncEngine`

### macOS ContentView
- `@Query` direkt auf `LocalTask` (NICHT PlanItem)
- Sidebar-Filter via `SidebarFilter` enum
- `filteredTasks` computed property mit switch-Statement
- Kein Suchfeld vorhanden

### Plattform-Divergenz
| Aspekt | iOS | macOS |
|--------|-----|-------|
| Task-Typ | `PlanItem` | `LocalTask` |
| Datenquelle | `LocalTaskSource` + `SyncEngine` | `@Query` direkt |
| Filter | Computed properties | Sidebar + switch |

## Dependencies
- **Upstream:** `PlanItem.title/tags/taskType` (iOS), `LocalTask.title/tags/taskType` (macOS), `TaskCategory.localizedName`
- **Downstream:** Keine — Suche ist reine View-Layer-Logik

## Existing Specs
- Keine relevanten Specs vorhanden

## Risks & Considerations
- Suche muss in **allen 8 ViewModes** funktionieren (iOS)
- macOS nutzt `LocalTask` direkt, iOS nutzt `PlanItem` — Suchlogik separat
- Tag-Suche: Tags sind `[String]` — Suche muss ueber Array iterieren
- Kategorie-Suche: User tippt "Geld" → muss `TaskCategory.income` finden (via `localizedName`)
- Performance: Bei vielen Tasks sollte String-Matching effizient sein (`.localizedCaseInsensitiveContains`)

---

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/BacklogView.swift` | MODIFY | `@State searchText`, `.searchable()`, Filter auf alle computed properties |
| `FocusBloxMac/ContentView.swift` | MODIFY | `@State searchText`, `.searchable()`, Filter in `filteredTasks` |

### Scope Assessment
- Files: **2** (+ Tests)
- Estimated LoC: **+25** netto
- Risk Level: **LOW** — rein additive Aenderung, kein bestehendes Verhalten geaendert

### Technical Approach
**Empfehlung: `.searchable()` Modifier auf View-Ebene + inline Filter-Funktion**

1. **iOS BacklogView:**
   - `@State private var searchText = ""`
   - `.searchable(text: $searchText, prompt: "Tasks durchsuchen")` auf NavigationStack
   - Hilfsfunktion `matchesSearch(_ item: PlanItem) -> Bool`
   - Alle computed properties (backlogTasks, nextUpTasks, etc.) filtern zusaetzlich nach searchText

2. **macOS ContentView:**
   - `@State private var searchText = ""`
   - `.searchable(text: $searchText, prompt: "Tasks durchsuchen")` auf NavigationSplitView
   - `filteredTasks` computed property erweitern: bestehende Sidebar-Filter + Suchfilter

3. **Suchlogik (inline, kein eigener Service):**
   - Titel: `.localizedCaseInsensitiveContains(searchText)`
   - Tags: `tags.contains { $0.localizedCaseInsensitiveContains(searchText) }`
   - Kategorie: `TaskCategory(rawValue: taskType)?.localizedName.localizedCaseInsensitiveContains(searchText)`
   - Leerer searchText = kein Filter (aktuelles Verhalten)

**Kein eigener SearchService noetig** — die Logik ist trivial und gehoert in die View-Ebene.

### Dependencies
- **Upstream:** PlanItem.title/tags/taskType, LocalTask.title/tags/taskType, TaskCategory.localizedName
- **Downstream:** Keine — rein additiv

### Open Questions
- Keine
