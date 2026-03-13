# Context: Monster Coach Phase 3d — Foundation Models Abend-Text

## Request Summary
On-Device AI (Apple Foundation Models) soll personalisierte Abend-Reflexionstexte generieren, die konkrete Tasks beim Namen nennen. Fallback auf bestehende Template-Sprueche fuer Geraete ohne Apple Intelligence.

## Related Files

### Direkt betroffen
| File | Relevance |
|------|-----------|
| `Sources/Services/IntentionEvaluationService.swift` | Enthaelt `fallbackTemplate()` — wird durch AI-Text ersetzt/ergaenzt |
| `Sources/Views/EveningReflectionCard.swift` | Zeigt aktuell `fallbackTemplate()` Text an — muss AI-Text anzeigen |

### Foundation Models Pattern (bestehend)
| File | Relevance |
|------|-----------|
| `Sources/Services/TaskTitleEngine.swift` | Etabliertes Pattern: `@Generable`, `LanguageModelSession`, Fallback |
| `Sources/Services/SmartTaskEnrichmentService.swift` | Gleiches Pattern mit Kontext-Building |
| `Sources/Services/AITaskScoringService.swift` | Gleiches Pattern |

### Monster Coach System
| File | Relevance |
|------|-----------|
| `Sources/Models/DailyIntention.swift` | IntentionOption enum + DailyIntention struct |
| `Sources/Views/DailyReviewView.swift` | Integration: Zeigt EveningReflectionCard ab 18 Uhr |
| `Sources/Models/AppSettings.swift` | `coachModeEnabled`, AI-Settings (`aiScoringEnabled`) |
| `Sources/FocusBloxApp.swift` | Foreground-Check + Silence Rule |

### Tests
| File | Relevance |
|------|-----------|
| `FocusBloxTests/IntentionEvaluationServiceTests.swift` | 40+ Tests, `fallbackTemplate()` Tests vorhanden |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | 5 UI Tests, pruefen `reflectionText_<intention>` |

## Existing Patterns

### Foundation Models Pattern (3x bewaehrt)
```swift
// 1. Conditional Import
#if canImport(FoundationModels)
import FoundationModels
#endif

// 2. Availability Check
static var isAvailable: Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
        return SystemLanguageModel.default.availability == .available
    }
    #endif
    return false
}

// 3. Structured Output
@Generable
struct Result {
    @Guide(description: "...") let field: String
}

// 4. Session + Prompt
let session = LanguageModelSession { "System prompt..." }
let response = try await session.respond(to: userPrompt, generating: Result.self)

// 5. Error Handling: Silent catch, task keeps original state
```

### Fallback-Strategie
- Alle 3 bestehenden Services: AI nicht verfuegbar → Feature wird no-op
- TaskTitleEngine: Titel bleibt unveraendert
- SmartEnrichment: Felder bleiben nil
- **Fuer Phase 3d:** Fallback auf bestehende `fallbackTemplate()` Strings

### Settings Gate
- `AppSettings.shared.aiScoringEnabled` steuert alle AI-Features
- Kann in Settings UI getoggelt werden

## Dependencies

### Upstream (was unser Code nutzt)
- `FoundationModels` Framework (iOS 26+ / macOS 26+)
- `IntentionEvaluationService.evaluateFulfillment()` — liefert FulfillmentLevel
- `IntentionEvaluationService.completedToday()` — liefert erledigte Tasks
- `DailyIntention.load()` — liefert heutige Intentionen
- `LocalTask` Model — Task-Titel, taskType, importance, completedAt

### Downstream (was unseren Code nutzt)
- `EveningReflectionCard` — zeigt den generierten Text an
- `DailyReviewView` — bettet die Card ein

## Existing Specs
- `docs/project/stories/monster-coach.md` — Gesamtvision inkl. Phase 3d Beschreibung
- `openspec/changes/monster-coach-phase3c/proposal.md` — Vorgaenger-Phase
- `docs/specs/services/task-title-engine.md` — Foundation Models Service Spec

## Kontext: Was Phase 3d tun soll (aus User Story)

> On-Device AI generiert persoenlichen Text der konkrete Tasks beim Namen nennt.
> Fallback auf handgeschriebene Template-Sprueche.

**Beispiel-Prompt (aus Story):**
```
"Du bist ein sympathisches Monster. Die Intention war BHAG. Der User hat
um 15:23 'Steuererklaerung' (importance 3) erledigt plus 4 weitere Tasks.
Schreib 2-3 persoenliche Saetze ohne toxische Positivitaet."
```

**Bestehende Fallback-Templates (14 Stueck):**
- Pro IntentionOption x FulfillmentLevel ein Template
- Deutsch, kurz, empathisch, nie schuldzuweisend
- Werden BEIBEHALTEN als Fallback

## Analysis

### Type
Feature (neue Funktionalitaet auf bestehendem System)

### Technischer Ansatz

**Architektur-Entscheidung: Neuer Service statt Extension**

Neuen `EveningReflectionTextService` erstellen (wie TaskTitleEngine-Pattern), NICHT IntentionEvaluationService erweitern. Gruende:
- IntentionEvaluationService ist reine Business-Logik (`import Foundation` only) — AI-Code wuerde es verschmutzen
- Alle 3 bestehenden AI-Services sind eigenstaendige Klassen — bewaehrtes Pattern
- Separation of Concerns: Bewertung (FulfillmentLevel) vs. Text-Generierung

**Datenfluss:**
```
DailyReviewView (hat ModelContext)
  │
  ├─ .task { await loadAITexts() }
  │   └─ EveningReflectionTextService.generateTexts(intentions:tasks:blocks:)
  │       ├─ AI verfuegbar → LanguageModelSession → personalisierter Text
  │       └─ AI nicht verfuegbar → fallbackTemplate()
  │
  └─ EveningReflectionCard(intentions:tasks:focusBlocks:aiTexts:)
      └─ Zeigt aiTexts[intention] ?? fallbackTemplate()
```

**Sofort-Rendering:** Card zeigt SOFORT fallbackTemplate(). Wenn AI-Text fertig → swap via @State. Kein Spinner, kein Loading.

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/EveningReflectionTextService.swift` | CREATE | Neuer AI-Service: @Generable, LanguageModelSession, Prompt-Building |
| `Sources/Views/EveningReflectionCard.swift` | MODIFY | Neuer Parameter `aiTexts: [IntentionOption: String]`, Anzeige-Logik |
| `Sources/Views/DailyReviewView.swift` | MODIFY | .task-Modifier fuer async AI-Text-Loading, @State fuer aiTexts |
| `FocusBloxTests/EveningReflectionTextServiceTests.swift` | CREATE | Unit Tests: Fallback, Guard-Bedingungen, Prompt-Building |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | MODIFY | Verify reflectionText anzeigt (Fallback oder AI) |

### Scope Assessment
- Files: 5 (2 CREATE, 3 MODIFY)
- Estimated LoC: +150 / ~20 modified
- Risk Level: LOW (bewaehrtes Pattern, klarer Fallback, keine Breaking Changes)

### @Generable Struct (Entwurf)
```swift
@Generable
struct EveningReflection {
    @Guide(description: "2-3 persoenliche Saetze. Empathisch, nie schuldzuweisend. Nenne konkrete Task-Titel.")
    let text: String
}
```

### Prompt-Strategie
- System: "Du bist ein sympathisches Monster, Trainingspartner. Nie toxisch positiv, nie schuldzuweisend."
- User: Intention + FulfillmentLevel + konkrete Task-Namen + Uhrzeiten
- Sprache: Deutsch
- Max 2-3 Saetze

### Dependencies
- Upstream: FoundationModels (iOS 26+), IntentionEvaluationService, LocalTask, FocusBlock
- Downstream: EveningReflectionCard (konsumiert generierten Text)

### Open Questions
- Soll es einen eigenen Settings-Toggle geben ("AI Abend-Text") oder reicht der bestehende `aiScoringEnabled`?

## Risiken & Considerations

1. **Latenz:** Foundation Models brauchen ~1-3 Sekunden. Card muss sofort mit Fallback-Text rendern und AI-Text nachladen.
2. **Async in View:** EveningReflectionCard ist aktuell synchron. Muss async werden oder einen Service vorschalten.
3. **Prompt-Qualitaet:** Text muss empathisch sein, keine toxische Positivitaet, keine Schuldzuweisung (Design-Prinzip).
4. **Datenschutz:** Alles on-device — kein Netzwerk. Apple Foundation Models = lokal.
5. **Geraete-Kompatibilitaet:** Nur Apple Silicon Geraete mit iOS 26+ haben Foundation Models. Aeltere Geraete → Fallback.
6. **Scope-Risiko:** Nur Text-Generierung. KEIN Monster-Character, KEINE Animation, KEINE neue UI.
7. **macOS:** EveningReflectionCard ist in `Sources/` (shared). Aenderungen gelten fuer beide Plattformen — aber macOS hat noch keine Coach-Integration in der UI.
