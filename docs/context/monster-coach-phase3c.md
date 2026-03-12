# Context: Monster Coach Phase 3c — Abend-Spiegel

## Request Summary
Abend-Spiegel: Automatische Karte im Review-Tab ab 18 Uhr, die zeigt ob die Morgen-Intention erfuellt wurde. 3-stufige Bewertung (erfuellt/teilweise/nicht erfuellt) aus Task-Daten, ohne User-Input. Fallback-Templates statt Foundation Models (kommt in Phase 3d).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/IntentionEvaluationService.swift` (116 LoC) | Muss erweitert werden: aktuell nur Bool `isFulfilled()`, braucht 3-stufigen Erfuellungsgrad + Block-Completion-Berechnung |
| `Sources/Views/DailyReviewView.swift` (631 LoC) | Host-View: EveningReflectionCard wird hier eingebettet (nach MorningIntentionView, vor Stats) |
| `Sources/Models/DailyIntention.swift` (110 LoC) | IntentionOption Enum mit 6 Cases + Farben/Icons, DailyIntention Persistence |
| `Sources/Views/MorningIntentionView.swift` (164 LoC) | UI-Pattern-Referenz: Chip-Grid, AccessibilityIdentifiers, Card-Stil |
| `Sources/Models/ReviewStatsCalculator.swift` (131 LoC) | Berechnet Kategorie-Stats, aehnliche Logik fuer Balance-Auswertung |
| `Sources/Models/LocalTask.swift` (225 LoC) | Task-Model: `isCompleted`, `completedAt`, `taskType`, `importance` |
| `Sources/Models/FocusBlock.swift` (227 LoC) | Block-Model: `taskIDs`, `completedTaskIDs` — Basis fuer Block-Completion |
| `Sources/Models/AppSettings.swift` (80 LoC) | `coachModeEnabled` und Coach-Notification-Settings |
| `Sources/Models/TaskCategory.swift` (51 LoC) | 5 Kategorien: income/maintenance/recharge/learning/giving_back |
| `Sources/Models/PlanItem.swift` (275 LoC) | Wrapper um LocalTask fuer UI, hat `completedAt`, `taskType`, `importance` |

## Existing Patterns
- **Card-Stil:** `RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)` + `.padding()`
- **Section Headlines:** `Text("...").font(.headline)`
- **Fortschritts-Ring:** `Circle().trim()` mit `.spring()` Animation
- **Coach-Mode Guard:** `if coachModeEnabled && reviewMode == .today`
- **Accessibility:** `camelCase + Suffix` (z.B. `morningIntentionCard`, `intentionChip_fokus`)
- **Completed-Tasks Filter:** `allTasks.filter { $0.isCompleted && $0.completedAt >= startOfToday }`

## Dependencies (Upstream)
- `IntentionEvaluationService` — Kern-Logik fuer Erfuellungsbewertung
- `DailyIntention.load()` — laedt heutige Intention aus UserDefaults
- `LocalTask` / `PlanItem` — Task-Daten (completedAt, taskType, importance)
- `FocusBlock` — Block-Daten (taskIDs, completedTaskIDs)
- `IntentionOption.color` / `.icon` / `.label` — visuelle Attribute

## Dependents (Downstream)
- Phase 3d (Foundation Models) baut auf EveningReflectionCard auf — Text-Bereich wird Placeholder
- Phase 3f (Siri) nutzt IntentionEvaluationService fuer "wie war mein Tag"

## Existing Specs
- `docs/project/stories/monster-coach.md` — User Story mit Abend-Spiegel Section (Zeile 142-198)
- `openspec/changes/monster-coach-phase3b/proposal.md` — Phase 3b Spec (IntentionEvaluationService Design)

## Bekannte Bugs im IntentionEvaluationService (aus Phase 3b Validation)
1. **FOKUS-Logik invertiert:** Nutzt AND statt OR, braucht Block-Completion ≥70%
2. **Block-Completion Helper fehlt:** `calculateBlockCompletion()` nicht implementiert
3. **BHAG Gap gibt gleichen Case zweimal zurueck**

## Kriterien fuer 3-stufige Bewertung (aus User Story)
| Intention | Erfuellt | Teilweise | Nicht erfuellt |
|-----------|----------|-----------|----------------|
| Survival | ≥1 Task erledigt | — (kein Teilweise) | 0 Tasks |
| Fokus | Block-Completion ≥70% | 40-69% | <40% oder keine Blocks |
| BHAG | Importance-3 Task erledigt | Tasks erledigt, aber kein BHAG | Nichts Nennenswertes |
| Balance | Tasks in ≥3 Kategorien | 2 Kategorien | ≤1 Kategorie |
| Growth | "learning" Task erledigt | — (kein Teilweise) | Kein "learning" Task |
| Connection | "giving_back" Task erledigt | — (kein Teilweise) | Kein "giving_back" Task |

## Fallback-Templates (statisch, pro Intention+Stufe)
| Intention | Erfuellt | Teilweise | Nicht erfuellt |
|-----------|----------|-----------|----------------|
| Survival | "Du hast es geschafft. Auch das zaehlt." | — | "Manchmal reicht es zu atmen. Morgen ist ein neuer Tag." |
| Fokus | "Du bist bei der Sache geblieben. Stark." | "Nicht perfekt fokussiert — aber du warst dran." | "Viel dazwischen gekommen heute. Passiert." |
| BHAG | "DU HAST ES GETAN! Weisst du was das bedeutet?!" | "Tasks erledigt — aber das grosse Ding wartet noch." | "Noch nicht dran gewesen. Morgen ist die Chance." |
| Balance | "Was fuer ein runder Tag." | "Zwei Bereiche abgedeckt — fast ausgeglichen." | "Einseitig heute. Morgen mal was anderes probieren?" |
| Growth | "Du bist heute klueger als gestern." | — | "Kein Lernen heute — auch okay. Neugier kommt wieder." |
| Connection | "Du hast jemandem den Tag besser gemacht." | — | "Fuer dich heute. Fuer andere morgen." |

## Analysis

### Type
Feature (Monster Coach Phase 3c — Abend-Spiegel)

### Affected Files (with changes)
| File | Change Type | Estimated LoC | Description |
|------|-------------|---------------|-------------|
| `Sources/Services/IntentionEvaluationService.swift` | MODIFY | +40 | `FulfillmentLevel` Enum + `evaluateFulfillment()` + `blockCompletionPercentage()` — rein additiv, kein Bestand aendern |
| `Sources/Views/EveningReflectionCard.swift` | CREATE | +80 | Neue SwiftUI Card: zeigt pro Intention den Erfuellungsgrad + Fallback-Template-Text |
| `Sources/Views/DailyReviewView.swift` | MODIFY | +15 | `allLocalTasks` State-Var + Card-Einbettung nach MorningIntentionView mit 18-Uhr-Guard |
| `FocusBloxTests/IntentionEvaluationServiceTests.swift` | MODIFY | +60 | Tests fuer 3-Stufen-Bewertung (6 Intentionen x 3 Stufen) |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | CREATE | +50 | UI Tests: Card-Sichtbarkeit, Inhalte |

### Scope Assessment
- **Files:** 5 (3 Produktion + 2 Test)
- **Estimated LoC:** +245 / -0
- **Risk Level:** LOW — rein additiver Code, kein Bestand wird geaendert

### Technical Approach
1. `FulfillmentLevel` Enum (.fulfilled/.partial/.notFulfilled) in IntentionEvaluationService.swift
2. `evaluateFulfillment()` als NEUE Methode — `isFulfilled()` bleibt unangetastet (Phase 3b nutzt es)
3. `blockCompletionPercentage()` Helper fuer Fokus-Stufen
4. `EveningReflectionCard` nimmt `[IntentionOption]`, `[LocalTask]`, `[FocusBlock]` als Parameter
5. Pro Intention wird `evaluateFulfillment()` aufgerufen → Ergebnis-Liste
6. 18-Uhr-Guard lebt in DailyReviewView, NICHT in der Card (Testbarkeit)
7. Type-Mismatch-Loesung: `@State var allLocalTasks: [LocalTask]` in DailyReviewView (gleicher Fetch, zwei Zuweisungen)

### Entscheidungen
- **BHAG-Gap-Bug (detectGap duplicate case):** Separates Ticket — nicht in Phase 3c bündeln
- **macOS MacReviewView:** Wird als Follow-up gemacht — iOS first, macOS hat aktuell noch keine Coach-Features in DayReviewContent
- **Multi-Select:** Card zeigt JEDE gewaehlte Intention einzeln mit eigenem Ergebnis — kein Aggregat
- **`isFulfilled()` wird NICHT geaendert** — neue Methode `evaluateFulfillment()` ersetzt sie fuer 3c-Zwecke

### Dependencies
- **Upstream:** IntentionEvaluationService (Phase 3b), DailyIntention Model, LocalTask, FocusBlock
- **Downstream:** Phase 3d (Foundation Models Text) baut auf EveningReflectionCard auf

### Risiken & Ueberlegungen
- **Kein Regressions-Risiko:** `isFulfilled()` und `detectGap()` bleiben unberuehrt
- **Multi-Select:** Card evaluiert jede Intention separat — kein komplexes Aggregat noetig
- **18-Uhr-Guard:** Nutzt `Calendar.current.component(.hour, from:)` — robust ueber Zeitzonen
- **Type-Mismatch:** Geloest durch zweites State-Var `allLocalTasks` — minimale Aenderung
