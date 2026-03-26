# Context: RW_4.2 — Success Story Generator

## Request Summary
KI-generierte Tages-Zusammenfassung im Abend-Modus: 2-4 motivierende Saetze basierend auf erledigten Tasks, Focus-Zeit und ueberwundenen Blockaden. Fallback auf statische Templates ohne Apple Intelligence.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | Evening mode mit Stub-Card `successStoryStubCard` (Zeile ~319-329) — wird durch SuccessStoryView ersetzt |
| `Sources/Models/AppSettings.swift` | Caching-Pattern (AppStorage), hier kommt `cachedSuccessStory` + `cachedSuccessStoryDate` |
| `Sources/Models/PlanItem.swift` | Datenquelle: `completedAt`, `taskType`, `rescheduleCount`, `estimatedDuration` |
| `Sources/Services/SmartTaskEnrichmentService.swift` | **Pattern-Vorlage**: `#if canImport(FoundationModels)`, `@Generable`, Availability-Check |
| `Sources/Services/AITaskScoringService.swift` | **Pattern-Vorlage**: gleicher Foundation Models Ansatz |
| `Sources/Services/EveningResetService.swift` | Abend-Reset-Logik, laeuft vor Success Story |
| `Sources/Services/SyncEngine.swift` | Laedt Tasks fuer Datensammlung |
| `Sources/Services/LocalTaskSource.swift` | SwiftData-backed Task Source |
| `FocusBloxUITests/DayViewUITests.swift` | Bestehende Evening-Mode UI Tests, hier kommen neue dazu |

## Existing Patterns

### Foundation Models Integration (3 Services nutzen es bereits)
```swift
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, macOS 26.0, *)
@Generable struct StructuredOutput { ... }

// Availability check:
SystemLanguageModel.default.availability == .available
```

### AppStorage Caching (AppSettings.swift)
- ISO-8601 Date-Strings fuer Datumsvergleiche
- Simple Key-Value Paare in UserDefaults

### Evening Mode Phase
- `DayPhase.evening` ab `eveningStartHour` (Default 18)
- Test-Override: `-eveningStartHour 0` Launch Argument

## Dependencies
- **Upstream:** PlanItem (Daten), SyncEngine (Task-Loading), EventKitRepository (Focus Blocks fuer Gesamtzeit)
- **Downstream:** DayView.swift eveningContent (ersetzt Stub durch echte View)

## Existing Specs
- `docs/specs/rework/4.2-success-story-generator.md` — Feature-Spec (Quelle)
- `docs/specs/rework/2.1d-day-view-evening-mode.md` — Evening Mode Foundation (Stub-Definition)
- `docs/specs/rework/4.1-soft-evening-reset.md` — Reset-Logik (Abhaengigkeit, ERLEDIGT)

## Neue Dateien (laut Spec)
| Datei | Beschreibung |
|-------|-------------|
| `Sources/Services/SuccessStoryService.swift` | Daten sammeln, Prompt bauen, Foundation Model aufrufen, cachen |
| `Sources/Views/SuccessStoryView.swift` | Card-Darstellung der generierten Story |

## Betroffene Dateien
| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/DayView.swift` | Stub `successStoryStub` durch `SuccessStoryView` ersetzen |
| `Sources/Models/AppSettings.swift` | + `cachedSuccessStory: String`, + `cachedSuccessStoryDate: String` |
| `FocusBloxUITests/DayViewUITests.swift` | Evening UI Tests anpassen (Stub → echte View) |

## Risks & Considerations
- Foundation Models API nur auf iOS 26+ / macOS 26+ — `#if canImport` + `@available` Pflicht
- 10-Sekunden-Timeout fuer LLM-Aufruf — Fallback auf statische Templates muss robust sein
- Bei 0 erledigten Tasks: kein negativer Text, Ermutigung oder keine Story
- Cache-Invalidierung: nur 1 Story pro Tag, aber was wenn abends neue Tasks erledigt werden?
- Spec sagt "Sprache folgt System-Sprache" — Foundation Models auf Deutsch seit iOS 26
