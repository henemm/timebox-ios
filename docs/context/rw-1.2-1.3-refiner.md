# Context: RW_1.2 + RW_1.3 — AI Context Extraction + The Refiner

## Request Summary

Kombiniertes Feature: AI-Enrichment fuer Raw-Tasks (RW_1.2) + dedizierter Refiner-Tab als Inbox-View (RW_1.3). Raw-Tasks aus Quick Dump werden automatisch mit AI-Vorschlaegen angereichert und im Refiner-Tab zur Bestaetigung/Korrektur angezeigt.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | + `suggested*`-Felder hinzufuegen |
| `Sources/Services/SmartTaskEnrichmentService.swift` | Enrichment-Logik umbauen: `suggested*` statt Hauptfelder |
| `Sources/Views/MainTabView.swift` | + Refiner-Tab mit Badge einfuegen |
| `FocusBloxMac/SidebarView.swift` | + Refiner-Eintrag in macOS Sidebar |
| `Sources/Views/QuickCaptureView.swift` | Setzt `lifecycleStatus = "raw"` (Trigger fuer Enrichment) |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Filtert `.raw` aus Backlog (Zeile 43) |
| `Sources/Intents/CreateTaskIntent.swift` | Setzt `.raw` bei Siri-Erfassung |
| `Sources/Models/PlanItem.swift` | Kopiert lifecycleStatus — evtl. `suggested*` relevant |

## Neue Dateien (laut Spec)

| Datei | Beschreibung |
|------|-----------|
| `Sources/Views/RefinerView.swift` | Hauptview: Liste der Raw-Tasks mit AI-Vorschlaegen |
| `Sources/Views/RefinerTaskCard.swift` | Einzelkarte: Rohtext + Vorschlaege-Badges + Swipe |

## Existing Patterns

- **Tab-Struktur:** `AppTab` enum + `TabView(selection:)` in `MainTabView.swift`
- **macOS Sidebar:** `MainSection` enum + `SidebarView` mit Badge-Counts
- **Enrichment:** `SmartTaskEnrichmentService` nutzt `@Generable` + `LanguageModelSession`
- **Lifecycle-Filter:** `LocalTaskSource.fetchIncompleteTasks()` filtert `lifecycleStatus != "raw"` (Zeile 43)
- **Quick Capture setzt `.raw`:** `QuickCaptureView` Zeile 362, `CreateTaskIntent` Zeile 19

## Dependencies

**Upstream (was wir nutzen):**
- `FoundationModels` Framework (Apple Intelligence)
- `SwiftData` / `ModelContext` fuer Persistenz
- `TaskLifecycleStatus` enum (bereits vorhanden)
- `TaskCategory` enum (fuer Kategorie-Mapping)

**Downstream (was uns nutzt):**
- Backlog sieht nur `.active`/`.refined` Tasks
- PlanItem kopiert lifecycleStatus

## Existing Specs

- `docs/specs/rework/1.2-ai-context-extraction.md` — AI Extraction Spec
- `docs/specs/rework/1.3-the-refiner.md` — Refiner UI Spec
- `docs/specs/rework/1.1-quick-dump.md` — Quick Dump (Vorgaenger, ERLEDIGT)

## Kern-Aenderungen

### 1. Model: `LocalTask.swift`
Neue `suggested*`-Felder:
```swift
var suggestedCategory: String?
var suggestedDuration: Int?
var suggestedImportance: Int?
var suggestedUrgency: Int?
var suggestedEnergyLevel: Int?
```
Plus Uebernahme-Methode: `suggested*` → Hauptfelder, Status → `.active`

### 2. Service: `SmartTaskEnrichmentService.swift`
- `enrichRawTask()` — Ergebnisse in `suggested*` statt Hauptfelder
- Automatischer Trigger nach Task-Erstellung mit `.raw`
- 5-Sekunden-Timeout
- Guardrail-Violation Handling

### 3. UI: `RefinerView.swift` + `RefinerTaskCard.swift`
- Liste aller `.raw` Tasks (neueste zuerst)
- Pro Task: Rohtext + AI-Vorschlaege als editierbare Chips
- Swipe rechts = Bestaetigen (→ `.active`)
- Swipe links = Loeschen
- Tap auf Vorschlag = Inline-Picker
- "Alle bestaetigen"-Button
- Leerer State mit Motivations-Nachricht

### 4. Navigation
- iOS: Neuer Tab in `MainTabView` mit Badge (Anzahl `.raw` Tasks)
- macOS: Neuer Eintrag in `SidebarView`

## Risks & Considerations

1. **Foundation Models Verfuegbarkeit:** Nur auf Apple Silicon + iOS 26+. Fallback noetig (leere Vorschlaege)
2. **CloudKit-Kompatibilitaet:** Neue `suggested*`-Felder brauchen Default-Werte (nil/Optional)
3. **Bestehende Enrichment-Logik:** Aktuell schreibt Service direkt in Hauptfelder — muss auf `suggested*` umgebaut werden, ohne bestehende Batch-Enrichment-Funktion zu brechen
4. **enrichAllTbdTasks() Konflikt:** App-Start-Enrichment laeuft auf ALLEN Tasks inkl. `.raw` — ohne Guard wuerden `.raw` Tasks direkt in Hauptfelder geschrieben → Refiner-UX nutzlos
5. **VoiceOver:** Swipe-Gesten brauchen Button-Fallback fuer Accessibility

## Analysis

### Type
Feature (kombiniert RW_1.2 + RW_1.3)

### Splitting-Plan (3 Schritte)

**Schritt 1 — RW_1.2a: Schema-Erweiterung** (~55 LoC, 2 Dateien)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/LocalTask.swift` | MODIFY | +5 `suggested*` Felder (Optional mit nil-Default) |
| `Sources/Models/PlanItem.swift` | MODIFY | +5 korrespondierende `let suggested*` + init-Mapping |

**Schritt 2 — RW_1.2b: Service-Umbau** (~90 LoC, 2 Dateien)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | MODIFY | `enrichRawTask()` neu, `@Generable` erweitern, Guard in Batch |
| `FocusBloxTests/SmartTaskEnrichmentServiceTests.swift` | MODIFY | Tests fuer suggested*-Logik anpassen |

**Schritt 3 — RW_1.3: Refiner UI** (~385 LoC, 5 Dateien)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/RefinerView.swift` | CREATE | Liste aller .raw Tasks + leerer State + "Alle bestaetigen" |
| `Sources/Views/RefinerTaskCard.swift` | CREATE | Karte mit Swipe-Actions + AI-Vorschlags-Chips |
| `Sources/Views/MainTabView.swift` | MODIFY | `AppTab.refiner` + 5. Tab mit Badge (+15 LoC) |
| `FocusBloxMac/SidebarView.swift` | MODIFY | `MainSection.refiner` + Sidebar-Row mit Badge (+20 LoC) |
| `FocusBloxUITests/RefinerUITests.swift` | CREATE | TDD RED Tests fuer Refiner UI |

### Scope Assessment
- Total Files: 9 (3 CREATE, 6 MODIFY)
- Estimated LoC: +530 / -10
- Risk Level: MEDIUM (CloudKit-Migration + Service-Umbau)
- Splitting: 3 Schritte innerhalb Scoping-Limits

### Technical Approach
1. Schema zuerst (sicherster Schritt, CloudKit-Migration nur einmal)
2. Service-Umbau danach (enrichRawTask() + Guard fuer enrichAllTbdTasks())
3. UI als letztes (baut auf Schema + Service auf)

### Dependencies
- **Upstream:** FoundationModels, SwiftData, TaskLifecycleStatus, TaskCategory
- **Downstream:** Backlog (filtert .raw), PlanItem (kopiert suggested*), enrichAllTbdTasks() (braucht Guard)
- **Kein Aenderungsbedarf:** QuickCaptureView, CreateTaskIntent, ShareExtensions, VoiceInputSheet (setzen alle bereits .raw)

### Open Questions
- keine — alle Informationen vorhanden
