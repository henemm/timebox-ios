---
entity_id: bug-35-quick-capture-fix
type: bugfix
created: 2026-02-11
updated: 2026-02-11
status: draft
workflow: bug-35-quick-capture-fix
---

# Bug 35: Quick Capture - Interactive Snippet + CC Button Fix

## Approval

- [ ] Approved for implementation

## Purpose

Spotlight "Task erstellen" zeigt nur Titel-Feld ohne Metadaten-Buttons.
Control Center "Quick Add Task" Button ist funktionslos.

## Root Causes

1. `CreateTaskIntent` nutzt alte pre-iOS-26 Patterns - zeigt nur Siri-Textdialog ohne interaktive UI
2. iOS 26 bietet **Interactive Snippets** (`SnippetIntent` + `ShowsSnippetView`) - damit kann eine eigene SwiftUI-View mit Buttons direkt im Spotlight-Dialog angezeigt werden
3. `SharedModelContainer` nutzt nicht App Group - Tasks kommen nicht in der App an
4. `QuickAddTaskIntent` (FocusBloxCore) ist nur Logging-Stub
5. Doppelte `AppShortcutsProvider` in zwei Targets

## Loesung

**Interactive Snippet** statt alter Parameter-Dialog:
- Spotlight fragt nach dem Titel (Pflichtparameter)
- Danach erscheint ein **interaktives Snippet** mit den 4 Metadaten-Buttons (wie QuickCaptureView)
- Jeder Button triggert einen Sub-Intent, der den Wert aendert und das Snippet aktualisiert
- "Erstellen"-Button speichert den Task

## Scope

- **Files:** 4 neue Dateien, 3 aendern, 2 loeschen
- **Estimated:** ~200 LoC

## Implementation Details

### 1. `CreateTaskSnippetIntent` - Neues SnippetIntent
**Neue Datei:** `Sources/Intents/CreateTaskSnippetIntent.swift`

SnippetIntent das die interaktive QuickCapture-View anzeigt:
```swift
struct CreateTaskSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Quick Capture Snippet"
    static let isDiscoverable: Bool = false

    @Parameter var taskTitle: String
    @Dependency var captureState: QuickCaptureState

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        return .result(view: QuickCaptureSnippetView(
            title: taskTitle,
            state: captureState
        ))
    }
}
```

### 2. `QuickCaptureState` - Shared State
**Neue Datei:** `Sources/Intents/QuickCaptureState.swift`

Observable State-Objekt das zwischen Snippet und Sub-Intents geteilt wird:
```swift
@Observable
final class QuickCaptureState {
    var importance: Int? = nil      // nil/1/2/3
    var urgency: String? = nil      // nil/not_urgent/urgent
    var taskType: String = "maintenance"
    var estimatedDuration: Int? = nil
}
```
In `FocusBloxApp.init()` registrieren:
```swift
AppDependencyManager.shared.add(dependency: QuickCaptureState())
```

### 3. `QuickCaptureSnippetView` - Interaktive SwiftUI-View
**Neue Datei:** `Sources/Intents/QuickCaptureSnippetView.swift`

Kompakte View mit den 4 Metadaten-Buttons (Logik aus QuickCaptureView uebernehmen):
```swift
struct QuickCaptureSnippetView: View {
    let title: String
    let state: QuickCaptureState

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            HStack(spacing: 12) {
                // Importance cycle button → CycleImportanceIntent
                Button(intent: CycleImportanceIntent()) { ... }
                // Urgency cycle button → CycleUrgencyIntent
                Button(intent: CycleUrgencyIntent()) { ... }
                // Category cycle button → CycleCategoryIntent
                Button(intent: CycleCategoryIntent()) { ... }
                // Duration cycle button → CycleDurationIntent
                Button(intent: CycleDurationIntent()) { ... }
            }
            Button(intent: SaveQuickCaptureIntent(taskTitle: title)) {
                Label("Erstellen", systemImage: "arrow.up.circle.fill")
            }
        }
    }
}
```

Wichtig: Buttons nutzen `Button(intent:)` statt `Button(action:)` - das ist die iOS 26 Interactive Snippet API.

### 4. Sub-Intents fuer Button-Aktionen
**Neue Datei:** `Sources/Intents/QuickCaptureSubIntents.swift`

5 kleine Intents:
- `CycleImportanceIntent` - nil→1→2→3→nil (gleiche Logik wie QuickCaptureView)
- `CycleUrgencyIntent` - nil→not_urgent→urgent→nil
- `CycleCategoryIntent` - maintenance→income→recharge→learning→giving_back→maintenance
- `CycleDurationIntent` - nil→15→25→45→60→nil
- `SaveQuickCaptureIntent` - Task erstellen und speichern

Jeder Cycle-Intent liest/aendert den shared `QuickCaptureState` via `@Dependency`.

### 5. `CreateTaskIntent` umbauen
**File:** `Sources/Intents/CreateTaskIntent.swift`

Return-Type aendern zu `ShowsSnippetIntent`:
```swift
func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity>
    & ProvidesDialog & ShowsSnippetIntent {
    // ... (Titel bekommen)
    return .result(
        value: entity,
        dialog: "Task konfigurieren:",
        snippetIntent: CreateTaskSnippetIntent(taskTitle: taskTitle)
    )
}
```
- `dueDate` und `taskDescription` Parameter entfernen
- importance/urgency/duration/category Parameter entfernen (werden ueber Snippet gesetzt)
- Nur `taskTitle` als Pflichtparameter behalten

### 6. `SharedModelContainer` reparieren
**File:** `Sources/Intents/TaskEntity.swift`

App Group Container nutzen:
```swift
static func create() throws -> ModelContainer {
    let schema = Schema([LocalTask.self, TaskMetadata.self])
    let config = ModelConfiguration(
        schema: schema,
        groupContainer: .identifier("group.com.henning.focusblox"),
        cloudKitDatabase: .automatic
    )
    return try ModelContainer(for: schema, configurations: [config])
}
```

### 7. Bereinigung
- `FocusBloxCore/QuickAddTaskIntent.swift` - Logging-Stub loeschen
- `FocusBloxCore/FocusBloxShortcuts.swift` - Doppelte AppShortcutsProvider loeschen

### 8. CC Button
**File:** `FocusBloxWidgets/QuickAddTaskControl.swift`

CC kann keine Snippets zeigen. `QuickAddLaunchIntent` oeffnet App mit URL-Scheme `focusblox://create-task` → QuickCaptureView als Sheet. Pruefen ob der bestehende Code korrekt funktioniert nach Bereinigung der FocusBloxCore-Stubs.

## Datei-Uebersicht

| Aktion | Datei |
|--------|-------|
| NEU | `Sources/Intents/CreateTaskSnippetIntent.swift` |
| NEU | `Sources/Intents/QuickCaptureState.swift` |
| NEU | `Sources/Intents/QuickCaptureSnippetView.swift` |
| NEU | `Sources/Intents/QuickCaptureSubIntents.swift` |
| AENDERN | `Sources/Intents/CreateTaskIntent.swift` |
| AENDERN | `Sources/Intents/TaskEntity.swift` |
| AENDERN | `Sources/FocusBloxApp.swift` (Dependency registrieren) |
| LOESCHEN | `FocusBloxCore/QuickAddTaskIntent.swift` |
| LOESCHEN | `FocusBloxCore/FocusBloxShortcuts.swift` |

## Test Plan

### Automated Tests (TDD RED)

Unit Tests in `FocusBloxTests/QuickCaptureIntentTests.swift`:

- [ ] Test 1: GIVEN QuickCaptureState WHEN CycleImportanceIntent performs THEN importance cycles nil→1→2→3→nil
- [ ] Test 2: GIVEN QuickCaptureState WHEN CycleUrgencyIntent performs THEN urgency cycles nil→not_urgent→urgent→nil
- [ ] Test 3: GIVEN SaveQuickCaptureIntent WHEN perform() with title THEN task saved in SharedModelContainer
- [ ] Test 4: GIVEN SharedModelContainer WHEN create() THEN container uses App Group config

## Acceptance Criteria

- [ ] Spotlight "Task erstellen" zeigt nach Titel-Eingabe ein interaktives Snippet mit 4 Metadaten-Buttons
- [ ] Buttons cyclen Werte visuell (Icon + Farbe aendert sich)
- [ ] "Erstellen"-Button speichert Task mit allen Metadaten
- [ ] Task erscheint in der App (SharedModelContainer nutzt App Group)
- [ ] Control Center Button oeffnet App mit QuickCaptureView
- [ ] Keine doppelten AppShortcutsProvider
- [ ] Build kompiliert ohne Errors
- [ ] Alle Tests gruen

## Changelog

- 2026-02-11: Initial spec - Option A (parameterSummary) - FALSCH, hat keinen Effekt auf Spotlight-Dialog
- 2026-02-11: Spec v2 - Interactive Snippets (iOS 26 SnippetIntent + ShowsSnippetView)
