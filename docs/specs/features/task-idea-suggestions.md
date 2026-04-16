---
entity_id: task-idea-suggestions
type: feature
created: 2026-04-16
updated: 2026-04-16
status: draft
version: "1.0"
tags: [ai, task-creation, on-device]
---

# KI-gestützte Task-Ideen beim Erstellen (Issue #199)

## Approval

- [ ] Approved

## Purpose

Beim Erstellen eines neuen Tasks erscheint ein optionaler Bereich „Vielleicht auch interessant?" mit 2–3 KI-generierten Task-Ideen, die per Tipp direkt als eigenständiger Task übernommen werden können. Das Feature nutzt On-Device AI (Apple Foundation Models) und ist per Settings-Toggle steuerbar (Standard: AUS).

## Source

- **File:** `Sources/Services/TaskIdeaSuggestionService.swift` (neu)
- **Identifier:** `final class TaskIdeaSuggestionService`

Weitere betroffene Dateien:
- `Sources/Views/TaskCreation/CreateTaskView.swift` — Einbau-Punkt: nach dem bestehenden MARK: Task Suggestions Block
- `Sources/Models/AppSettings.swift` — neue `@AppStorage`-Property
- `Sources/Views/SettingsView.swift` — neuer Toggle in der KI-Sektion

## Dependencies

| Entity | Typ | Zweck |
|--------|-----|-------|
| `IntentionSuggestionService` | Service (Vorlage) | Pattern für On-Device-AI-Aufrufe mit `@Generable`-Structs und Fallback |
| `SmartTaskEnrichmentService` | Service | `isAvailable`-Guard-Pattern für FoundationModels-Verfügbarkeitsprüfung |
| `TaskSuggestionService` | Service | Liefert offene + erledigte Tasks als Kontext via `fetchAllTasks()` |
| `AppSettings` | Model | Speichert den Toggle-Zustand (`@AppStorage("taskIdeaSuggestionsEnabled")`) |
| `SettingsView` | View | Zeigt den Toggle in der bestehenden KI-Sektion neben `aiScoringToggle` |
| `CreateTaskView` | View | Zeigt den „Vielleicht auch interessant?"-Bereich und verwaltet State |
| `FoundationModels` | Framework | On-Device AI (`LanguageModelSession`, `SystemLanguageModel`) |
| `LocalTaskSource` | Service | Erstellt den übernommenen Task per `createTask(...)` |

## Implementation Details

### 1. TaskIdeaSuggestionService (~120 LoC)

Analog zu `IntentionSuggestionService`. Struktur:

```swift
@MainActor
final class TaskIdeaSuggestionService {

    static var isAIAvailable: Bool { ... } // SystemLanguageModel.default.availability == .available

    static func suggestions(existingTasks: [LocalTask]) async -> [String] {
        if isAIAvailable {
            if let ideas = await generateWithAI(existingTasks: existingTasks),
               ideas.count >= 2 { return Array(ideas.prefix(3)) }
        }
        return fallbackSuggestions(existingTasks: existingTasks)
    }

    // @Generable struct TaskIdeaSet { idea1, idea2, idea3 }
    // Prompt: offene Tasks als Kontext, kurze Ideen (3–7 Worte), kein Duplikat
    // Fallback: 2–3 statische Ideen aus den Titeln vorhandener offener Tasks
}
```

**Prompt-Strategie:**
- Kontext: Titel der letzten 10 offenen Tasks (keine personenbezogenen Details)
- Anweisung: kurze Aufgaben-Ideen (3–7 Worte), keine Duplikate, keine Floskeln
- Ton: beiläufig, wie Haftnotizen, nicht werbend

**Fallback (wenn AI nicht verfügbar):**
- Leere Liste — kein Bereich wird angezeigt (kein statischer Dummy-Content)

### 2. CreateTaskView — Neuer Bereich (~50 LoC)

Einbau-Punkt: neue `Section` nach dem bestehenden Autocomplete-Block (`MARK: Task Suggestions`).

Bedingungen für Anzeige:
1. `AppSettings.shared.taskIdeaSuggestionsEnabled == true`
2. `TaskIdeaSuggestionService.isAIAvailable == true`
3. `ideaSuggestions.isEmpty == false` (nach .task{}-Ladevorgang)

```swift
// MARK: - KI Task-Ideen
@State private var ideaSuggestions: [String] = []
@State private var ideaSuggestionsLoaded = false

// In body, neue Section:
if settings.taskIdeaSuggestionsEnabled,
   TaskIdeaSuggestionService.isAIAvailable,
   !ideaSuggestions.isEmpty {
    Section {
        ForEach(ideaSuggestions, id: \.self) { idea in
            Button {
                adoptIdea(idea)
            } label: {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(idea)
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityIdentifier("taskIdea_\(idea.hashValue)")
        }
    } header: {
        Text("Vielleicht auch interessant?")
    }
}

// .task { } beim Erscheinen der View:
.task {
    let tasks = await TaskSuggestionService.fetchAllTasks(context: modelContext)
    ideaSuggestions = await TaskIdeaSuggestionService.suggestions(existingTasks: tasks)
    ideaSuggestionsLoaded = true
}
```

**`adoptIdea(_ idea: String)`:**
- Erstellt sofort einen neuen `LocalTask` via `LocalTaskSource.createTask(title: idea, ...)`
- Kein Rückfrage-Dialog, kein Confirmation-Sheet
- Entfernt die übernommene Idee aus `ideaSuggestions`
- Der aktuelle Task-Erstellungsformular bleibt offen (keine Unterbrechung)

### 3. AppSettings — neue Property (~4 LoC)

```swift
// MARK: - KI Task-Ideen
/// Ob KI-generierte Task-Ideen beim Erstellen angezeigt werden (default: AUS)
@AppStorage("taskIdeaSuggestionsEnabled") var taskIdeaSuggestionsEnabled: Bool = false
```

### 4. SettingsView — neuer Toggle (~8 LoC)

In der bestehenden KI-Sektion (neben `aiScoringToggle`), mit `isAvailable`-Guard:

```swift
if TaskIdeaSuggestionService.isAIAvailable {
    Toggle("KI Task-Ideen", isOn: $taskIdeaSuggestionsEnabled)
        .accessibilityIdentifier("taskIdeaSuggestionsToggle")
}
```

Footer-Text: „Beim Erstellen eines Tasks erscheinen 2–3 Ideen für verwandte Aufgaben."

## Expected Behavior

- **Eingabe:** Offene Tasks aus SwiftData (max. 10 Titel als Kontext)
- **Ausgabe:** 2–3 kurze Task-Ideen als Strings (3–7 Worte)
- **Übernahme:** Tipp auf eine Idee → sofortiger Task-Create ohne Rückfrage → Idee verschwindet aus Liste
- **Ignorieren:** Keine Aktion nötig, kein Pflichtelement
- **Nicht verfügbar (AI):** Bereich wird nicht angezeigt (kein Fallback-Content sichtbar)
- **Feature deaktiviert:** Bereich wird nicht angezeigt, kein AI-Aufruf
- **Nebeneffekte:** Jeder übernommene Vorschlag erzeugt einen `LocalTask` und triggert `SmartNotificationEngine.reconcile`

## Known Limitations

- Vorschläge werden nur einmal beim Öffnen der View geladen, nicht bei jedem Tastendruck
- Der `isAvailable`-Guard hängt von `SystemLanguageModel.default.availability` ab — auf Geräten ohne Apple Intelligence bleibt der Bereich dauerhaft unsichtbar (auch wenn Toggle aktiviert)
- Fallback-Modus liefert keine Ideen (leere Liste = kein Bereich sichtbar); bewusste Entscheidung gegen generischen Dummy-Content

## Changelog

- 2026-04-16: Initiale Spec erstellt
