# Bug: Watch-Tasks werden auf iPhone nicht enriched

## Symptom
Tasks via Apple Watch Ultra 3 angelegt zeigen auf iPhone: `? ? (?) ?` und Score `0`.
Enrichment (Kategorie, Prioritaet, Dauer, Energie-Level) passiert NIE.

## Root Cause

**Watch-Tasks umgehen die Enrichment-Pipeline komplett.**

Watch erstellt Tasks via `VoiceInputSheet.saveTask()`:
```swift
let task = LocalTask(title: title)
task.needsTitleImprovement = true
modelContext.insert(task)  // <-- Direkt in SwiftData, KEINE Enrichment-Pipeline
```

iPhone-Tasks laufen ueber `LocalTaskSource.createTask()`:
```swift
// Hier wird Enrichment aufgerufen:
let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
await enrichment.enrichTask(task)  // <-- NUR HIER
let titleEngine = TaskTitleEngine(modelContext: modelContext)
await titleEngine.improveTitleIfNeeded(task)
```

**Watch-Tasks kommen via CloudKit zum iPhone, aber es gibt KEINEN Trigger der Enrichment auslöst:**
- `BacklogView.refreshLocalTasks()` holt die Tasks nur ab, enriched sie nicht
- `FocusBloxApp.onAppear` ruft nur `titleEngine.improveAllPendingTitles()` auf — KEIN `enrichAllTbdTasks()`
- Es gibt keinen Observer der bei CloudKit-Import Enrichment triggert

## Was die Tests tatsaechlich testen (und warum das wertlos ist)

### SmartTaskEnrichmentServiceTests (238 Zeilen, 15 Tests)
| Test | Was getestet wird | Problem |
|------|-------------------|---------|
| `test_enrichTask_skipsWhenDisabled` | "Wenn AI aus, passiert nichts" | Guard-Test, nicht Feature-Test |
| `test_enrichTask_preservesUserSetImportance` | "User-Wert bleibt erhalten" | Tautologie: X=3, assert X==3 |
| `test_createTask_enrichesAttributes_whenAvailable` | Der EINZIGE echte Test | **Passt IMMER**: `if isAvailable { assertNotNil } else { assertNil }` — Auf CI ist AI nicht verfuegbar, also wird nur `assertNil` geprueft |

### TaskTitleEngineTests (396 Zeilen, 45 Tests)
| Test | Was getestet wird | Problem |
|------|-------------------|---------|
| Guard-Tests (4) | "Wenn Bedingung falsch, nichts passieren" | Beweisen nur dass Guards funktionieren |
| Keyword-Stripping (7) | "(dringend)" wird entfernt | OK, aber testet nur deterministische Logik, nicht AI |
| AI-Tests | Titel-Verbesserung | `XCTSkip` wenn AI nicht verfuegbar — laufen NIE auf CI |

### AITaskScoringServiceTests (171 Zeilen, 15 Tests)
| Test | Was getestet wird | Problem |
|------|-------------------|---------|
| `test_localTask_hasAIScoring_trueAfterScoring` | `task.aiScore = 75; assert == 75` | Tautologie — testet Property-Assignment |
| Alle anderen | Default-Werte, Property-Mapping | Kein einziger Test ruft den Scoring-Service auf |

### Was KOMPLETT FEHLT
- **0 Tests** fuer Watch → iPhone Sync → Enrichment
- **0 Tests** fuer CloudKit Remote Change → Enrichment-Trigger
- **0 Tests** die beweisen dass Enrichment tatsaechlich Werte FUELLT (nicht nur "nichts kaputt macht")
- **0 Tests** fuer den Pfad: Task ohne Attribute kommt via Sync an → wird enriched

## Hypothesen

### H1: Enrichment wird bei Watch-Tasks nie getriggert (HOECHSTE WAHRSCHEINLICHKEIT)
- **Beweis dafuer:** `enrichTask()` wird NUR in `LocalTaskSource.createTask()` aufgerufen. Watch nutzt `modelContext.insert()` direkt.
- **Beweis dagegen:** Keiner. Der Code ist eindeutig.
- **Wahrscheinlichkeit:** 99%

### H2: App-Start enriched Watch-Tasks nachtraeglich
- **Beweis dafuer:** `FocusBloxApp.onAppear` ruft `improveAllPendingTitles()` auf
- **Beweis dagegen:** `improveAllPendingTitles()` verbessert NUR Titel — ruft SmartTaskEnrichmentService NICHT auf. Die Attribute (importance, urgency, taskType, aiEnergyLevel) bleiben nil.
- **Wahrscheinlichkeit:** 0% — der Code ist klar

### H3: CloudKit-Sync-Monitor triggert Enrichment
- **Beweis dafuer:** Keiner
- **Beweis dagegen:** `CloudKitSyncMonitor.checkForChanges()` loggt nur, enriched nicht. `BacklogView.refreshLocalTasks()` fetcht nur, enriched nicht.
- **Wahrscheinlichkeit:** 0%

## Blast Radius
Gleiche Problem betrifft ALLE nicht-lokalen Task-Erstellungswege:
- Watch Quick Capture
- Siri Shortcuts (falls Tasks direkt in SwiftData landen)
- Share Extension
- Reminders Import

NUR iPhone/macOS-lokale Erstellung via `createTask()` funktioniert.

## Warum die Tests das nicht gefangen haben

**Fundamentales Problem:** Die Tests testen nur die lokale iPhone-Erstellung, nie den Sync-Pfad.

1. **`if isAvailable`-Falle:** Test passt in BEIDEN Faellen — wenn AI verfuegbar ist UND wenn nicht. Wertloser Assertion-Pattern.
2. **Tautologie-Tests:** "Setze X=3, pruefe X==3" beweist nur dass Swift Properties funktionieren
3. **Guard-Tests:** "Wenn Feature aus, passiert nichts" — ok, aber testet nicht ob Feature AN funktioniert
4. **Kein Integration-Test:** Kein Test simuliert "Task kommt via CloudKit an → Enrichment muss laufen"
5. **XCTSkip auf CI:** AI-abhaengige Tests werden uebersprungen → Core-Logik nie getestet
