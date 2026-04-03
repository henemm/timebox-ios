---
entity_id: FEATURE_175-smart-task-suggestions
type: feature
created: 2026-04-03
updated: 2026-04-03
status: draft
version: "1.0"
tags: [task-creation, autocomplete, duplicate-detection]
---

# Smart Task-Vorschläge beim Erstellen

## Approval

- [ ] Approved

## Purpose

Beim Erstellen eines neuen Tasks zeigt die App intelligente Vorschläge basierend auf bestehenden und erledigten Tasks. Zusätzlich warnt sie bei Duplikaten — ruhig, nicht-blockierend.

## Source

- **Service:** `Sources/Services/TaskSuggestionService.swift` (NEU)
- **View-Integration:** `Sources/Views/TaskCreation/CreateTaskView.swift` (ÄNDERUNG)
- **Settings:** `Sources/Models/AppSettings.swift` (ÄNDERUNG)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| LocalTaskSource | Service | Liefert bestehende + erledigte Tasks für Matching |
| LocalTask | Model | Task-Datenmodell mit `title`, `isCompleted`, `completedAt` |
| AppSettings | Model | Toggle für Feature ein/aus |
| CreateTaskView | View | Integration der Vorschlags-UI |

## User-Erwartung (vom User-Advocate)

1. **Autocomplete ab 2-3 Zeichen** — subtile Vorschlagsliste unter dem Titel-Feld
2. **Duplikat-Hinweis** — ruhiger, nicht-blockierender Hinweis nach Eingabe
3. Vorschläge dürfen Keyboard NICHT verdecken
4. Auch erledigte Tasks als Vorschläge einbeziehen
5. Duplikat-Warnung NIEMALS blockierend — nur Information

## Implementation Details

### TaskSuggestionService (NEU)

```swift
@MainActor
final class TaskSuggestionService {
    private let modelContext: ModelContext

    /// Liefert Task-Titel-Vorschläge basierend auf Input
    /// - Parameter input: Aktueller Titel-Text (min. 2 Zeichen)
    /// - Returns: Max 5 passende Task-Titel, sortiert nach Relevanz
    func suggestions(for input: String) async -> [TaskSuggestion]

    /// Prüft ob ein ähnlicher Task bereits existiert
    /// - Returns: Bester Match mit Ähnlichkeit > 80%, oder nil
    func findDuplicate(for title: String) async -> DuplicateMatch?
}

struct TaskSuggestion: Identifiable {
    let id: UUID        // UUID des Original-Tasks
    let title: String   // Titel des bestehenden Tasks
    let isCompleted: Bool  // War der Task schon erledigt?
    let completedAt: Date? // Wann zuletzt erledigt?
}

struct DuplicateMatch {
    let task: TaskSuggestion
    let similarity: Double  // 0.0 - 1.0
}
```

**Matching-Algorithmus:**
1. Prefix-Match (case-insensitive): Höchste Priorität
2. Contains-Match: Zweite Priorität
3. Levenshtein-Distanz für Duplikat-Erkennung (>80% = Warnung)

**Datenquellen:**
- `fetchIncompleteTasks()` — offene Tasks
- `fetchCompletedTasks(withinDays: 90)` — erledigte der letzten 90 Tage

### CreateTaskView Integration

```
┌──────────────────────────────┐
│ Task-Titel: [Zahna___]       │  ← TextField
├──────────────────────────────┤
│ 🔍 Zahnarzt Termin           │  ← Vorschlag (Tipp übernimmt)
│ 🔍 Zahnarzt anrufen          │  ← Vorschlag
├──────────────────────────────┤
│ ⚠️ Ähnlich: "Zahnarzt Termin │  ← Duplikat-Hinweis (wenn >80%)
│    vereinbaren" (vor 3 Wo.)  │
│    [Trotzdem erstellen]      │
└──────────────────────────────┘
```

- Vorschläge erscheinen als Section UNTER dem Titel-Feld (innerhalb der Form)
- Max 5 Vorschläge
- Tipp auf Vorschlag → Titel wird übernommen, Vorschläge verschwinden
- Duplikat-Hinweis als gelber/orangener Footer unter der Titel-Section
- "Trotzdem erstellen" ist der Default — kein Blocker

### AppSettings Erweiterung

```swift
// In AppSettings:
@AppStorage("taskSuggestionsEnabled") var taskSuggestionsEnabled: Bool = true
```

- Default: AN (Autocomplete ist nützlich für alle)
- In SettingsView neben "AI Task Scoring" als eigener Toggle

## Affected Files

| Datei | Änderung | ~LoC |
|-------|----------|------|
| `Sources/Services/TaskSuggestionService.swift` | NEU | ~80 |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | Vorschlags-UI + State | ~60 |
| `Sources/Models/AppSettings.swift` | 1 Toggle | ~3 |
| `FocusBloxTests/TaskSuggestionServiceTests.swift` | Unit Tests | ~80 |
| `FocusBloxUITests/TaskSuggestionUITests.swift` | UI Tests | ~60 |

**Gesamt: ~280 LoC, 5 Dateien** (knapp im Scope)

## Expected Behavior

- **Input:** User tippt "Zahn" in Titel-Feld
- **Output:** Liste mit "Zahnarzt Termin vereinbaren", "Zahnarzt anrufen" etc.
- **Duplikat:** User tippt exakt "Zahnarzt Termin" → orangener Hinweis mit letztem Erledigungsdatum
- **Performance:** <100ms (rein deterministisch, kein AI)
- **Side effects:** Keine — rein read-only Abfrage

## Known Limitations

- Matching ist rein String-basiert (kein semantisches Matching)
- Nur Tasks der letzten 90 Tage werden für Duplikate berücksichtigt
- Keine Cross-Device-Synchronisation der Vorschlags-Historie (nutzt lokale SwiftData)

## Changelog

- 2026-04-03: Initial spec created (Split von #183, KI-Ideen → #199)
