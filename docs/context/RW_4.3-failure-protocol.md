# Context: RW_4.3 — Failure Protocol

## Request Summary
Optionales Quick-Select im Abend-Modus: Warum wurde ein Task nicht erledigt? 6 vordefinierte Gruende, historisiert, fliessen in BehavioralProfileService.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | Evening Content mit `failureQuickSelectStub` (Zeile 278, 315-325) — Stub wird durch echte View ersetzt |
| `Sources/Models/PlanItem.swift` | Task-Model, `unfinishedTasks` Liste kommt daraus |
| `Sources/Models/LocalTask.swift` | SwiftData Model — kein `failureReason` Feld vorhanden, neues Model noetig |
| `Sources/Services/BehavioralProfileService.swift` | Soll Failure-Daten konsumieren (Spec: tooTired → nicht morgens, noTime → weniger Meeting-Tage) |
| `Sources/Models/BehavioralProfile.swift` | Profile-Struct — braucht ggf. neues Feld fuer Failure-Insights |
| `FocusBloxUITests/DayViewUITests.swift` | Existierender Test prueft `failureQuickSelectStubCard` (Zeile 353) — muss angepasst werden |
| `Sources/Views/SuccessStoryView.swift` | Schwester-Feature im gleichen Evening-Screen |
| `Sources/Services/SuccessStoryService.swift` | Pattern-Referenz fuer Service-Architektur (enum + static methods) |

## Existing Patterns
- **Service-Pattern:** `enum XyzService` mit static methods (SuccessStoryService, BehavioralProfileService)
- **Evening Mode:** DayView.eveningContent zeigt ScrollView mit Sections (completedTasks, unfinishedTasks, SuccessStory, failureStub)
- **SwiftData Models:** `@Model final class` mit `#Index`, CloudKit-kompatibel (Default-Werte fuer alle Attribute)
- **Stub-Pattern:** Features bekommen erst Stub-Views, dann echte Implementation (wie successStoryStub → SuccessStoryView)

## Dependencies
- **Upstream:** `unfinishedTasks: [PlanItem]` — bereits in `loadEveningData()` geladen
- **Upstream:** `modelContext` — bereits als `@Environment` in DayView
- **Downstream:** `BehavioralProfileService.compute()` — soll Failure-Records als neuen Input bekommen

## Existing Specs
- `docs/specs/rework/4.3-failure-protocol.md` — Haupt-Spec mit Model, Service, View Vorgaben
- `docs/specs/rework/4.2-success-story-generator-impl.md` — Schwester-Feature, gleicher Evening-Screen
- `docs/specs/rework/4.1-soft-evening-reset.md` — Evening Reset, Vorgaenger-Feature

## Risks & Considerations
- **Neues SwiftData Model:** `TaskFailureRecord` braucht Schema-Migration (CloudKit auto-migration)
- **Xcode-Projekt:** Neue Dateien muessen via `pbxproj` Python-Script hinzugefuegt werden
- **BehavioralProfileService Erweiterung:** Muss `ModelContext` bekommen um FailureRecords zu fetchen — aktuell bekommt er nur `[LocalTask]` + `[FocusBlock]`
- **NextUpSuggestionService existiert nicht** — Spec erwaehnt ihn, muss ggf. ausgescoped werden
- **LoC Budget:** ~250 LoC Limit — BPS-Integration koennte Budget sprengen, ggf. Stub belassen

---

## Analysis

### Type
Feature (neues UI + neues Model + neuer Service)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/TaskFailureRecord.swift` | CREATE | SwiftData @Model: taskID, date, reason (enum als String) |
| `Sources/Services/FailureProtocolService.swift` | CREATE | enum mit save() + fetch() static methods |
| `Sources/Views/FailureQuickSelectView.swift` | CREATE | 6 Reason-Buttons pro Task, dismissbar |
| `Sources/Views/DayView.swift` | MODIFY | Stub ersetzen durch FailureQuickSelectView |
| `Sources/FocusBloxApp.swift` | MODIFY | TaskFailureRecord zum Schema hinzufuegen |
| `FocusBloxUITests/DayViewUITests.swift` | MODIFY | Stub-Test anpassen + neue Tests |

### Scope Assessment
- Files: 6 (3 CREATE, 3 MODIFY)
- Estimated LoC: ~203 (Production ~155, Tests ~48)
- Risk Level: LOW-MEDIUM

### Technical Approach
1. `TaskFailureRecord` als @Model mit String-basiertem Enum (CloudKit-kompatibel)
2. `FailureProtocolService` als enum mit static methods — nur save() + fetchForDate()
3. `FailureQuickSelectView` pro unerledgtem Task — `@State dismissed` fuer Wegwischbarkeit
4. DayView: Stub ersetzen, `unfinishedTasks` + `modelContext` an View weiterreichen
5. Schema in FocusBloxApp.swift erweitern

### Scope-Reduktion (Empfehlung)
**BehavioralProfileService-Integration auf RW_4.3b verschieben.** Daten werden gespeichert und sind abrufbar — Auswertungslogik kommt separat. Spart ~28 LoC und haelt Ticket sauber unter 250.

### Dependencies
- Upstream: `unfinishedTasks: [PlanItem]` (bereits geladen in loadEveningData)
- Upstream: `modelContext` (bereits als @Environment in DayView)
- Schema: FocusBloxApp.swift Schema-Array erweitern
- UI Tests: `launchInEveningMode()` Helper existiert bereits (setzt eveningStartHour=0)

### Open Questions
- Keine — Scope ist klar definiert, BPS-Integration bewusst ausgescoped
