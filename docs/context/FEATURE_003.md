# Context: FEATURE_003 — Coach-Backlog macOS: Quick-Add TextField

## Request Summary

Der normale macOS-Backlog hat ein Quick-Add TextField oben (zum schnellen Erstellen neuer Tasks via Enter), aber der Coach-Backlog auf macOS hat keines. Dieses Feature fuegt das Quick-Add TextField zum MacCoachBacklogView hinzu.

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxMac/MacCoachBacklogView.swift` | **TARGET** — Coach-Backlog macOS View, bekommt Quick-Add TextField |
| `FocusBloxMac/ContentView.swift` | Referenz-Implementation des Quick-Add (lines 374-396), `addTask()` (lines 782-826), ruft MacCoachBacklogView auf (line 271) |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | Bestehende UI Tests fuer Coach-Backlog, neue Quick-Add Tests hier |
| `FocusBloxMacUITests/Bug94FocusAfterAddUITests.swift` | Referenz: wie Quick-Add auf macOS getestet wird |
| `Sources/ViewModels/CoachBacklogViewModel.swift` | Shared ViewModel — keine Aenderung noetig (nur Filter-Logik) |
| `Sources/Views/CoachBacklogView.swift` | iOS Coach-Backlog — hat KEIN Quick-Add (nutzt TaskFormSheet via + Button) |
| `FocusBloxMac/FocusBloxMacApp.swift` | Mock Data Seeding fuer UI Tests (keine Aenderung noetig) |

## Existing Patterns

### Quick-Add im normalen macOS Backlog (ContentView)
```swift
// State
@State private var newTaskTitle = ""

// UI: HStack mit TextField + Plus-Button
HStack {
    TextField("Neuer Task...", text: $newTaskTitle)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("newTaskTextField")
        .onSubmit { addTask() }
    Button { addTask() } label: {
        Image(systemName: "plus.circle.fill").font(.title2)
    }
    .disabled(newTaskTitle.isEmpty)
}

// addTask() erstellt LocalTask, speichert in modelContext,
// triggert AI-Enrichment via SmartTaskEnrichmentService
```

### Callback-Pattern in MacCoachBacklogView
```swift
// Bestehend: onImport Callback
var onImport: (() async -> Void)?

// Aufruf aus ContentView:
MacCoachBacklogView(tasks: visibleTasks, selectedTasks: $selectedTasks,
                    onImport: importFromReminders)
```

## Dependencies

### Upstream (was Quick-Add braucht)
- `@Environment(\.modelContext)` — zum Speichern neuer Tasks
- `TaskTitleEngine.stripKeywords()` — Keyword-Bereinigung
- `SmartTaskEnrichmentService` — AI-Enrichment im Hintergrund
- `LocalTask` Model — Task-Entity

### Downstream (was sich aendern muss)
- `ContentView` — muss `refreshTasks()` nach Quick-Add aufrufen (via Callback)

## Analysis

### Type
Feature

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY | Quick-Add HStack + `@State coachNewTaskTitle` + `onAddTask` Callback Property |
| `FocusBloxMac/ContentView.swift` | MODIFY | `addTask(with:)` Extraktion + Closure bei MacCoachBacklogView-Aufruf verdrahten |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | MODIFY | 2 neue UI Tests: TextField-Existenz + Task-Erstellung |

### Scope Assessment
- Files: 3
- Estimated LoC: +70
- Risk Level: LOW

### Technical Approach

**Option B: Closure-Delegation an ContentView** (empfohlen)

MacCoachBacklogView bekommt `onAddTask: ((String) -> Void)?` Callback. ContentView refaktoriert `addTask()` zu `addTask(with title: String)` und uebergibt die Closure beim Instantiieren.

**Begruendung:**
- Folgt bestehendem `onImport`-Callback-Pattern
- Keine Duplikation von Persistenz-/Enrichment-Logik
- Inspector/Scroll-Mechanik bleibt in ContentView wo sie hingehoert
- `coachNewTaskTitle` als eigener `@State` in MacCoachBacklogView — kein Konflikt

**Reihenfolge:**
1. TDD RED: 2 UI Tests in MacCoachBacklogUITests
2. ContentView: `addTask(with:)` extrahieren
3. MacCoachBacklogView: Quick-Add HStack + onAddTask Callback
4. ContentView: Closure bei MacCoachBacklogView verdrahten
5. Tests gruen

### Accessibility Identifiers

| Element | Identifier |
|---------|------------|
| Quick-Add TextField | `coachQuickAddTextField` |
| Quick-Add Button | `coachAddTaskButton` |

(Unterscheidbar von regular Backlog: `newTaskTextField` / `addTaskButton`)

### Existing Specs

- `docs/specs/macos/MAC-013-backlog-view.md` — Original macOS Backlog Spec (done)
- `docs/specs/macos/feature-012-coachbacklog-effectivescore.md` — Letztes Coach-Backlog Feature (draft)

### Risks & Considerations

- **LOW Risk:** Feature ist klein (Size S), klares Pattern vorhanden
- Kein Impact auf iOS Coach-Backlog (separate View)
- Keine neuen Dependencies
- UI Tests koennen bestehendes Pattern aus Bug94 Tests uebernehmen
