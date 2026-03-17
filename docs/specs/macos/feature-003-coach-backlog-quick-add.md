---
entity_id: feature-003-coach-backlog-quick-add
type: feature
created: 2026-03-17
updated: 2026-03-17
status: done
version: "1.0"
tags: [macos, coach-backlog, quick-add, task-creation]
---

# FEATURE_003: Coach-Backlog macOS — Quick-Add TextField

## Approval

- [x] Approved

## Purpose

Der normale macOS-Backlog hat ein Quick-Add TextField oben (TextField + Plus-Button), ueber das neue Tasks per Enter-Taste schnell erstellt werden koennen. Der Coach-Backlog (`MacCoachBacklogView`) hat dieses Feature nicht. Diese Spec fuegt ein identisches Quick-Add TextField zum Coach-Backlog hinzu, damit Coach-Mode-Nutzer Tasks genauso effizient anlegen koennen.

## Source

- **File:** `FocusBloxMac/MacCoachBacklogView.swift`
- **Identifier:** `MacCoachBacklogView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ContentView` | View | Besitzt `addTask()` Logik inkl. Enrichment + Spotlight. Stellt Closure bereit. |
| `TaskTitleEngine` | Service | `stripKeywords()` fuer Keyword-Bereinigung (aufgerufen in ContentView.addTask) |
| `SmartTaskEnrichmentService` | Service | AI-Enrichment im Hintergrund (aufgerufen in ContentView.addTask) |
| `LocalTask` | Model | Task-Entity die erstellt wird |

## Implementation Details

### Datei 1: `FocusBloxMac/ContentView.swift`

**1. `addTask(with:)` extrahieren aus bestehendem `addTask()`**

```swift
// Bestehende addTask() wird Wrapper:
private func addTask() {
    guard !newTaskTitle.isEmpty else { return }
    addTask(with: newTaskTitle)
    newTaskTitle = ""
}

// Neue Methode — wiederverwendbar fuer Coach-Backlog Callback:
private func addTask(with title: String) {
    let cleanedTitle = TaskTitleEngine.stripKeywords(title)
    let nextSortOrder = (tasks.map(\.sortOrder).max() ?? 0) + 1
    let newTask = LocalTask(
        title: cleanedTitle,
        sortOrder: nextSortOrder,
        taskType: "",
        sourceSystem: "local"
    )
    modelContext.insert(newTask)
    try? modelContext.save()
    refreshTasks()
    inspectorOverrideTaskID = newTask.uuid
    scrollToTaskID = newTask.uuid

    Task {
        let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
        await enrichment.enrichTask(newTask)
        // ... Title Improvement + Spotlight (unveraendert)
    }
}
```

**2. Closure bei MacCoachBacklogView-Aufruf verdrahten**

```swift
// Vorher (Zeile ~271):
MacCoachBacklogView(tasks: visibleTasks, selectedTasks: $selectedTasks,
                    onImport: importFromReminders)

// Nachher:
MacCoachBacklogView(tasks: visibleTasks, selectedTasks: $selectedTasks,
                    onImport: importFromReminders,
                    onAddTask: { title in addTask(with: title) })
```

### Datei 2: `FocusBloxMac/MacCoachBacklogView.swift`

**1. Neue Properties**

```swift
var onAddTask: ((String) -> Void)?
@State private var coachNewTaskTitle = ""
```

**2. Quick-Add HStack einfuegen (oberhalb taskList)**

```swift
var body: some View {
    VStack(spacing: 0) {
        // Toolbar: ViewMode-Switcher + Sync + Task Count (unveraendert)
        HStack { ... }

        // Quick-Add Bar (NEU)
        HStack {
            TextField("Neuer Task...", text: $coachNewTaskTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("coachQuickAddTextField")
                .onSubmit { submitCoachTask() }

            Button {
                submitCoachTask()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .disabled(coachNewTaskTitle.isEmpty)
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityIdentifier("coachAddTaskButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        Divider()

        taskList  // unveraendert
    }
}

private func submitCoachTask() {
    guard !coachNewTaskTitle.isEmpty else { return }
    let title = coachNewTaskTitle
    coachNewTaskTitle = ""
    onAddTask?(title)
}
```

## Expected Behavior

- **Input:** Nutzer tippt Text in das Quick-Add TextField im Coach-Backlog und drueckt Enter (oder klickt Plus-Button)
- **Output:** Neuer Task erscheint in der Task-Liste. TextField wird geleert. AI-Enrichment laeuft im Hintergrund.
- **Side effects:** Keine — nutzt bestehende `addTask(with:)` Logik aus ContentView

## Acceptance Criteria

1. `coachQuickAddTextField` ist sichtbar im Coach-Backlog (macOS, `coachModeEnabled = true`)
2. `coachAddTaskButton` ist sichtbar und initial disabled (leeres TextField)
3. Enter-Taste im TextField erstellt neuen Task und leert das Feld
4. Plus-Button erstellt neuen Task und leert das Feld
5. Erstellter Task erscheint in der Task-Liste
6. Build ohne Fehler/Warnings

## Test Plan (UI Tests — TDD RED)

**Datei:** `FocusBloxMacUITests/MacCoachBacklogUITests.swift` (bestehende Datei erweitern)
**Target:** `FocusBloxMacUITests`

| # | Testname | Setup | Assertion | Warum RED |
|---|----------|-------|-----------|-----------|
| T1 | `test_coachBacklog_quickAddTextField_exists` | Launch mit `-coachModeEnabled 1` | `coachQuickAddTextField` exists | TextField existiert noch nicht in MacCoachBacklogView |
| T2 | `test_coachBacklog_quickAdd_createsTask` | Launch + Text eingeben + Return | Neuer Task-Titel erscheint in Liste | Kein Quick-Add implementiert, Task kann nicht erstellt werden |

**TDD RED Rationale:** Beide Tests schlagen fehl weil `MacCoachBacklogView` aktuell kein Quick-Add TextField hat — weder das UI-Element noch die Callback-Logik existieren.

## Known Limitations

- Quick-Add im Coach-Backlog nutzt dieselbe `addTask(with:)` Logik wie der normale Backlog — kein Coach-spezifisches Verhalten (z.B. automatische Kategorie-Zuweisung)
- Inspector-Oeffnung nach Task-Erstellung funktioniert nur wenn der neue Task in `visibleTasks` erscheint (abhaengig von Coach-Filter)

## Changelog

- 2026-03-17: Initial spec created (FEATURE_003)
- 2026-03-17: **IMPLEMENTATION COMPLETE**
  - Added Quick-Add TextField + Plus Button in `MacCoachBacklogView`
  - Extracted `addTask(with: String)` in `ContentView` for reusable task creation
  - Wired `onAddTask` callback from ContentView to MacCoachBacklogView
  - 2 UI tests passing (TDD GREEN): `test_coachBacklog_quickAddTextField_exists`, `test_coachBacklog_quickAdd_createsTask`
  - Changed files: FocusBloxMac/MacCoachBacklogView.swift, FocusBloxMac/ContentView.swift, FocusBloxMacUITests/MacCoachBacklogUITests.swift
  - Status: Done, Approved
