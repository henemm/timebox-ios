# Context: CTC-1 TaskTitleEngine

## Request Summary
Zentraler KI-Service der aus beliebigem Raw-Input (E-Mail-Subject, URL-Titel, Diktat, Clipboard-Text) einen actionable Task-Titel generiert. Laeuft im Hintergrund — Task wird sofort mit Roh-Titel erstellt, KI verbessert asynchron. Original-Input bleibt in Task-Beschreibung erhalten.

## User Story
`docs/project/stories/contextual-task-capture.md`

## Related Files

### Direkt relevant (Pattern-Vorlagen)
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | Foundation Models Pattern: @Generable, LanguageModelSession, Availability-Guards |
| `Sources/Services/AITaskScoringService.swift` | Zweites Beispiel fuer Foundation Models Pattern |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Zentraler Hub fuer Task-Erstellung, Enrichment-Integration (Zeile 122-123) |

### Task-Creation Entry Points (Integration)
| File | Relevance |
|------|-----------|
| `Sources/Services/TaskSources/LocalTaskSource.swift:102-126` | Haupt-Hub — alle UI-Views delegieren hierhin, Enrichment bei Zeile 123 |
| `Sources/Services/RemindersImportService.swift:83-93` | Bulk-Import aus Erinnerungen, direkter Insert |
| `Sources/Services/RecurrenceService.swift:123-140` | Recurring Instance Creation, direkter Insert |
| `FocusBloxShareExtension/ShareViewController.swift:168-170` | Share Extension, direkter Insert ohne Enrichment |
| `Sources/Intents/QuickCaptureSubIntents.swift:116-126` | Siri/Shortcuts, direkter Insert |
| `FocusBloxWatch Watch App/ContentView.swift:55-57` | Watch OS Diktat, direkter Insert |

### UI-Views (delegieren zu LocalTaskSource, kein Wiring noetig)
| File | Relevance |
|------|-----------|
| `Sources/Views/QuickCaptureView.swift` | iOS Quick Capture — nutzt source.createTask() |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | iOS Formular — nutzt source.createTask() |
| `Sources/Views/TaskFormSheet.swift` | iOS Sheet — nutzt source.createTask() |
| `FocusBloxMac/MenuBarView.swift` | macOS MenuBar — nutzt source.createTask() |
| `FocusBloxMac/QuickCapturePanel.swift` | macOS Quick Capture — nutzt source.createTask() |

## Existing Patterns

### Foundation Models API Pattern
```
1. #if canImport(FoundationModels) + @available(iOS 26.0, macOS 26.0, *)
2. @Generable struct mit @Guide Descriptions
3. LanguageModelSession { system-prompt } + session.respond(to:generating:)
4. Response via .content Property
5. Guards: isAvailable + AppSettings.aiScoringEnabled
6. @MainActor final class
```

### Task-Creation Flow (LocalTaskSource)
```
1. LocalTask(title:...) konstruieren
2. context.insert(task)
3. context.save()
4. SmartTaskEnrichmentService.enrichTask(task) — async, nach save
```

### Bestehende KI-Services
- **SmartTaskEnrichmentService:** Enriched Attribute (importance, urgency, category, energy) — beruehrt Titel NICHT
- **AITaskScoringService:** Scored Tasks 0-100 — beruehrt Titel NICHT
- **Keiner** der bestehenden Services modifiziert den Task-Titel

## Dependencies

### Upstream (was TaskTitleEngine braucht)
- `FoundationModels` Framework (iOS 26+ / macOS 26+)
- `SwiftData` ModelContext (zum Speichern des verbesserten Titels)
- `LocalTask` Model (Zugriff auf title + taskDescription)
- `AppSettings.shared.aiScoringEnabled` (User-Setting)

### Downstream (was TaskTitleEngine nutzt)
- Batch-Lauf bei App-Start (wie SmartTaskEnrichmentService.enrichAllTbdTasks)
- Share Extension / Watch / Siri setzen Flag, Hauptprozess verarbeitet

## Existing Specs
- Keine bestehende Spec fuer TaskTitleEngine (neu)
- `docs/specs/_template.md` — Template verfuegbar
- `docs/specs/features/itb-g-proactive-suggestions.md` — Pattern-Vorlage fuer Foundation Models Integration

---

## Analysis

### Type
Feature (CTC-1: TaskTitleEngine)

### Kritische Erkenntnis: FoundationModels in App Extensions
**FoundationModels ist in App Extensions (Share Extension, Watch, Siri Intents) NICHT verfuegbar.**
Die Titel-Verbesserung MUSS im Hauptprozess passieren.

### Technischer Ansatz: Batch-Service mit Flag

**Empfehlung:** TaskTitleEngine als paralleler Batch-Service (analog SmartTaskEnrichmentService).

**Flow:**
1. Task wird mit Roh-Titel erstellt + `needsTitleImprovement = true`
2. Bei App-Start: `TaskTitleEngine.improveAllPendingTitles()` laeuft
3. Fuer jede Task mit Flag:
   - Original-Titel → `taskDescription` sichern (falls leer)
   - KI-Call: Titel verbessern
   - `task.title = improvedTitle`
   - `task.needsTitleImprovement = false`
4. CloudKit synct verbessertes Objekt

**Warum NICHT im createTask() Flow:**
- Share Extension kann FoundationModels nicht nutzen → muss sowieso Batch sein
- createTask() soll schnell bleiben (User wartet)
- Batch-Processing bei App-Start ist etabliertes Pattern
- Ein einheitlicher Ansatz fuer ALLE Eingangswege

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/TaskTitleEngine.swift` | CREATE | Neuer KI-Service (~90 LoC) |
| `Sources/Models/LocalTask.swift` | MODIFY | +1 Property: `needsTitleImprovement: Bool` (+2 LoC) |
| `Sources/FocusBloxApp.swift` | MODIFY | Batch-Lauf in .onAppear einbauen (+3 LoC) |
| `FocusBloxShareExtension/ShareViewController.swift` | MODIFY | Flag setzen bei Erstellung (+1 LoC) |
| `FocusBloxTests/TaskTitleEngineTests.swift` | CREATE | Unit Tests (~120 LoC) |

### Scope Assessment
- Files: 5 (2 CREATE + 3 MODIFY)
- Estimated LoC: +215 (90 Service + 120 Tests + 5 Integration)
- Risk Level: LOW
  - Kein Eingriff in bestehende Enrichment-Pipeline
  - Neues Bool-Property mit Default = harmlose Schema-Erweiterung
  - Fallback bei Nicht-Verfuegbarkeit: Roh-Titel bleibt einfach stehen

### Risiken
1. **SwiftData Schema:** Neues `needsTitleImprovement` Property → automatische Lightweight-Migration (Bool mit Default = unkritisch)
2. **Titel-Verschlechterung:** KI koennte guten Titel verschlechtern → Original bleibt in taskDescription, Empfehlung: konservatives Prompting
3. **Race Condition:** Titel wird verbessert waehrend User ihn editiert → Loesung: Flag auf false setzen bei manuellem Edit

### Open Questions
- Keine offenen Fragen — Ansatz ist klar
