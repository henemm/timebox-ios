---
entity_id: task_title_engine
type: service
created: 2026-03-02
updated: 2026-03-02
status: implemented
version: "1.0"
tags: [ai, foundation-models, task-creation, cross-platform]
---

# TaskTitleEngine

## Approval

- [ ] Approved

## Purpose

Zentraler KI-Service der aus beliebigem Raw-Input (E-Mail-Subject, URL-Titel, Diktat, Clipboard-Text) einen actionable Task-Titel generiert. Laeuft als Batch-Service im Hintergrund bei App-Start — Tasks werden sofort mit Roh-Titel erstellt, die KI verbessert asynchron. Original-Input bleibt in `taskDescription` erhalten.

## User Story

`docs/project/stories/contextual-task-capture.md`

## Source

- **File:** `Sources/Services/TaskTitleEngine.swift`
- **Identifier:** `TaskTitleEngine`
- **Pattern-Vorlage:** `Sources/Services/SmartTaskEnrichmentService.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FoundationModels` | Framework | On-Device KI (iOS 26+ / macOS 26+) |
| `LocalTask` | Model | Task-Titel lesen/schreiben, taskDescription sichern |
| `SwiftData.ModelContext` | Framework | Persistenz |
| `AppSettings.aiScoringEnabled` | Setting | User-Toggle fuer KI-Features |

## Architektur-Entscheidung

### Warum Batch-Service (nicht inline in createTask)?

1. **FoundationModels ist in App Extensions NICHT verfuegbar** — Share Extension, Watch, Siri Intents koennen KI nicht nutzen
2. **createTask() soll schnell bleiben** — User wartet auf Ergebnis
3. **Einheitlicher Ansatz** fuer ALLE Eingangswege (Share, Watch, Siri, Hauptapp)
4. **Etabliertes Pattern** — SmartTaskEnrichmentService nutzt den gleichen Batch-Ansatz

### Flow

```
1. Task wird erstellt (beliebiger Eingangsweg)
   → Roh-Titel als title
   → needsTitleImprovement = true

2. App-Start (oder App-Foreground)
   → TaskTitleEngine.improveAllPendingTitles()

3. Fuer jede Task mit needsTitleImprovement == true:
   a) Original-Titel → taskDescription sichern (falls leer)
   b) KI-Call: Titel verbessern
   c) task.title = verbesserter Titel
   d) task.needsTitleImprovement = false
   e) modelContext.save()

4. CloudKit synct automatisch
```

## Implementation Details

### Neues Model-Property (LocalTask.swift)

```swift
var needsTitleImprovement: Bool = false
```

Lightweight-Migration: Bool mit Default `false` → kein Migrationscode noetig.

### Service-Struktur (TaskTitleEngine.swift)

```swift
import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class TaskTitleEngine {

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ImprovedTitle {
        @Guide(description: "Kurzer, actionable Task-Titel (max 80 Zeichen). Beginnt mit Verb im Infinitiv. Deutsch wenn Input deutsch, sonst Englisch.")
        let title: String
    }
    #endif

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Verbessert den Titel einer einzelnen Task
    func improveTitleIfNeeded(_ task: LocalTask) async {
        guard Self.isAvailable else { return }
        guard AppSettings.shared.aiScoringEnabled else { return }
        guard task.needsTitleImprovement else { return }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await performImprovement(task)
        }
        #endif
    }

    /// Batch: Alle Tasks mit needsTitleImprovement verarbeiten
    func improveAllPendingTitles() async -> Int {
        guard Self.isAvailable else { return 0 }
        guard AppSettings.shared.aiScoringEnabled else { return 0 }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.needsTitleImprovement && !$0.isCompleted }
        )
        guard let tasks = try? modelContext.fetch(descriptor) else { return 0 }

        var improved = 0
        for task in tasks {
            await improveTitleIfNeeded(task)
            improved += 1
            try? await Task.sleep(for: .milliseconds(500))
        }
        return improved
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performImprovement(_ task: LocalTask) async {
        // Original sichern
        if task.taskDescription == nil || task.taskDescription?.isEmpty == true {
            task.taskDescription = task.title
        }

        do {
            let session = LanguageModelSession {
                "Du verbesserst Task-Titel. Regeln:"
                "- Kurz und actionable (max 80 Zeichen)"
                "- Beginne mit Verb im Infinitiv (z.B. 'Antworten auf...', 'Pruefen ob...')"
                "- Entferne E-Mail-Artefakte (Re:, Fwd:, AW:, WG:)"
                "- Behalte die Sprache des Inputs bei"
                "- Wenn der Titel bereits gut ist, gib ihn unveraendert zurueck"
            }

            let prompt = "Verbessere diesen Task-Titel: \(task.title)"
            let response = try await session.respond(to: prompt, generating: ImprovedTitle.self)
            let improved = response.content.title.trimmingCharacters(in: .whitespacesAndNewlines)

            if !improved.isEmpty {
                task.title = String(improved.prefix(200))
            }
            task.needsTitleImprovement = false
            try modelContext.save()
        } catch {
            // Bei Fehler: Flag bleibt, naechster Versuch bei naechstem App-Start
            print("[TaskTitleEngine] Failed for '\(task.title)': \(error)")
        }
    }
    #endif
}
```

### Integration: App-Start (FocusBloxApp.swift)

In `.onAppear` nach bestehenden Batch-Services:

```swift
let titleEngine = TaskTitleEngine(modelContext: modelContext)
Task { await titleEngine.improveAllPendingTitles() }
```

### Integration: Share Extension (ShareViewController.swift)

Nach `let task = LocalTask(title: trimmedTitle)`:

```swift
task.needsTitleImprovement = true
```

### Integration: LocalTaskSource.createTask()

Am Ende von createTask(), nach SmartTaskEnrichmentService:

```swift
task.needsTitleImprovement = true
try modelContext.save()
```

## Expected Behavior

### Input → Output Beispiele

| Raw Input | Verbesserter Titel |
|-----------|-------------------|
| `Re: Fwd: AW: Meeting Donnerstag` | `Meeting Donnerstag vorbereiten` |
| `https://developer.apple.com/wwdc25` | `WWDC25 Inhalte pruefen` |
| `Erinnere mich dass ich Herbert antworten muss` | `Herbert antworten` |
| `Steuererklaerung abgeben` | `Steuererklaerung abgeben` (bereits gut) |
| `Buy milk and eggs` | `Buy milk and eggs` (bereits gut) |

### Verhalten ohne Apple Intelligence

- `isAvailable` gibt `false` zurueck
- `needsTitleImprovement` bleibt `true` (naechster Versuch bei naechstem Start)
- Roh-Titel bleibt unveraendert
- Keine Fehlermeldung, keine UI-Aenderung

### Verhalten bei aiScoringEnabled == false

- Service ueberspringt alle Tasks
- Flag bleibt stehen (User kann KI spaeter aktivieren)

## Side Effects

- `task.title` wird ueberschrieben (Original in `taskDescription` gesichert)
- `task.needsTitleImprovement` wird auf `false` gesetzt
- `modelContext.save()` wird aufgerufen → CloudKit Sync

## Known Limitations

1. **App Extensions:** FoundationModels nicht verfuegbar → Titel-Verbesserung erst bei naechstem App-Start
2. **Latenz:** Zwischen Task-Erstellung (Share Extension) und Titel-Verbesserung kann Zeit vergehen
3. **Sprache:** On-Device Model kann bei seltenen Sprachen schlechtere Ergebnisse liefern
4. **Keine Rueckgaengig-UI:** Kein expliziter "Originaltitel wiederherstellen"-Button (aber Original in taskDescription)

## Test Plan

### Unit Tests (TaskTitleEngineTests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_isAvailable_returnsBool` | Availability-Check gibt Bool zurueck |
| `test_improveTitleIfNeeded_skipsWhenNotAvailable` | Kein KI-Call wenn isAvailable == false |
| `test_improveTitleIfNeeded_skipsWhenAiDisabled` | Kein KI-Call wenn aiScoringEnabled == false |
| `test_improveTitleIfNeeded_skipsWhenFlagFalse` | Kein KI-Call wenn needsTitleImprovement == false |
| `test_improveTitleIfNeeded_savesOriginalToDescription` | Original-Titel wird in taskDescription gesichert |
| `test_improveTitleIfNeeded_preservesExistingDescription` | Bestehende taskDescription wird NICHT ueberschrieben |
| `test_improveTitleIfNeeded_setsFlagToFalse` | Flag wird nach Verarbeitung auf false gesetzt |
| `test_improveAllPendingTitles_fetchesOnlyFlagged` | Batch holt nur Tasks mit needsTitleImprovement == true |
| `test_improveAllPendingTitles_skipsCompletedTasks` | Erledigte Tasks werden nicht verarbeitet |
| `test_improveAllPendingTitles_returnsCount` | Return-Wert entspricht Anzahl verarbeiteter Tasks |
| `test_needsTitleImprovement_defaultIsFalse` | Neues Property hat Default false |

### UI Tests (nicht fuer CTC-1)

UI Tests entfallen fuer den reinen Service — die UI-Integration kommt mit CTC-2/3/4.

## Affected Files

| File | Change Type | LoC |
|------|-------------|-----|
| `Sources/Services/TaskTitleEngine.swift` | CREATE | ~90 |
| `Sources/Models/LocalTask.swift` | MODIFY | +2 |
| `Sources/FocusBloxApp.swift` | MODIFY | +3 |
| `FocusBloxShareExtension/ShareViewController.swift` | MODIFY | +1 |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | MODIFY | +2 |
| `FocusBloxTests/TaskTitleEngineTests.swift` | CREATE | ~120 |

**Total:** 6 Dateien, ~218 LoC

## Changelog

- 2026-03-02: Initial spec created
- 2026-03-02: Implemented — 9/9 unit tests GREEN, iOS + macOS build successful
