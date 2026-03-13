---
entity_id: evening-reflection-text-service
type: service
created: 2026-03-13
updated: 2026-03-13
status: draft
version: "1.0"
tags: [monster-coach, foundation-models, ai, phase-3d]
---

# EveningReflectionTextService

## Approval

- [ ] Approved

## Purpose

Generiert personalisierte Abend-Reflexionstexte on-device per Apple Foundation Models (iOS 26+/macOS 26+). Der Service folgt dem TaskTitleEngine-Pattern: sofortige Darstellung des Fallback-Templates, AI-Text wird asynchron nachgeladen und ersetzt den Fallback ohne Spinner oder Ladeverzögerung.

## Source

- **File:** `Sources/Services/EveningReflectionTextService.swift`
- **Identifier:** `EveningReflectionTextService`
- **Pattern-Vorlage:** `Sources/Services/TaskTitleEngine.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FoundationModels` | Framework | On-Device KI (iOS 26+ / macOS 26+) — `LanguageModelSession`, `@Generable` |
| `IntentionEvaluationService` | Service | `evaluateFulfillment()` liefert `FulfillmentLevel`; `fallbackTemplate()` liefert Fallback-Text |
| `IntentionOption` | Model | Intention-Typ (survival, fokus, bhag, balance, growth, connection) |
| `FulfillmentLevel` | Enum | Auswertungs-Ergebnis: fulfilled / partial / notFulfilled |
| `LocalTask` | Model | Erledigte Tasks fuer Prompt-Konstruktion (Titel, completedAt, importance) |
| `FocusBlock` | Model | Focus-Block-Daten fuer Prompt-Konstruktion (completedTaskIDs, taskIDs) |
| `DailyIntention` | Model | Heutige Intention-Selektion des Users |
| `AppSettings.aiScoringEnabled` | Setting | User-Toggle — KI-Features aktiv/inaktiv |
| `EveningReflectionCard` | View | Konsumiert `aiTexts: [IntentionOption: String]` statt direkt `fallbackTemplate()` aufzurufen |
| `DailyReviewView` | View | Ladet AI-Texte async per `@State private var aiReflectionTexts` und reicht sie an die Card weiter |

## Implementation Details

### Service-Struktur (EveningReflectionTextService.swift)

```swift
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates personalized evening reflection texts using on-device AI (Foundation Models).
/// Falls back to IntentionEvaluationService.fallbackTemplate() when AI is unavailable.
/// Follows the TaskTitleEngine pattern: immediate fallback, async AI replacement.
@MainActor
final class EveningReflectionTextService {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - @Generable Struct

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ReflectionText {
        @Guide(description: "2-3 persoenliche Saetze ueber den Tag des Users. Empathisch, direkt, nie toxisch positiv, nie schuldzuweisend. Bezieht sich auf konkrete erledigte Task-Titel wenn vorhanden. Auf Deutsch. Max 200 Zeichen.")
        let text: String
    }
    #endif

    // MARK: - Public API

    /// Generiert AI-Text fuer eine einzelne Intention.
    /// Gibt nil zurueck wenn AI nicht verfuegbar oder disabled — Caller nutzt dann fallbackTemplate().
    func generateText(
        intention: IntentionOption,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) async -> String? {
        guard Self.isAvailable else { return nil }
        guard AppSettings.shared.aiScoringEnabled else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performGeneration(
                intention: intention,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )
        }
        #endif
        return nil
    }

    /// Batch: Generiert AI-Texte fuer alle gegebenen Intentions parallel.
    /// Gibt Dictionary [IntentionOption: String] zurueck — nur Eintraege wo AI erfolgreich.
    /// Caller merged mit fallbackTemplate() fuer fehlende Eintraege.
    func generateTexts(
        intentions: [IntentionOption],
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) async -> [IntentionOption: String] {
        guard Self.isAvailable else { return [:] }
        guard AppSettings.shared.aiScoringEnabled else { return [:] }

        var results: [IntentionOption: String] = [:]
        for intention in intentions {
            let level = IntentionEvaluationService.evaluateFulfillment(
                intention: intention,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )
            if let text = await generateText(
                intention: intention,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            ) {
                results[intention] = text
            }
        }
        return results
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performGeneration(
        intention: IntentionOption,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) async -> String? {
        do {
            let session = LanguageModelSession {
                "Du bist ein sympathisches Monster — Trainingspartner des Users."
                "Schreib 2-3 persoenliche Saetze ueber seinen heutigen Tag."
                "Regeln:"
                "- Nie toxisch positiv ('Du hast das grossartig gemacht!')"
                "- Nie schuldzuweisend ('Du haettest X tun sollen')"
                "- Empathisch und direkt — wie ein ehrlicher Freund"
                "- Bezieh dich auf konkrete Task-Titel wenn vorhanden"
                "- Immer auf Deutsch"
                "- Max 200 Zeichen"
            }

            let userPrompt = buildPrompt(
                intention: intention,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )

            let response = try await session.respond(to: userPrompt, generating: ReflectionText.self)
            let generated = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !generated.isEmpty else { return nil }
            return String(generated.prefix(300))
        } catch {
            // Fehler still — Caller nutzt fallbackTemplate()
            return nil
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func buildPrompt(
        intention: IntentionOption,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) -> String {
        let completedTasks = IntentionEvaluationService.completedToday(tasks, now: now)
        let todayBlocks = IntentionEvaluationService.focusBlocksToday(focusBlocks, now: now)

        var parts: [String] = []

        // Intention + Ergebnis
        parts.append("Intention: \(intention.label) (\(intention.rawValue))")
        parts.append("Ergebnis: \(levelDescription(level))")

        // Erledigte Tasks (max 5, mit Zeitstempel und Wichtigkeit)
        if !completedTasks.isEmpty {
            let taskLines = completedTasks.prefix(5).map { task -> String in
                let timeStr = formatTime(task.completedAt, now: now)
                let importanceStr = task.importance == 3 ? " [Wichtigkeit: hoch]" : ""
                return "- '\(task.title)'\(timeStr)\(importanceStr)"
            }
            parts.append("Erledigte Tasks heute:\n\(taskLines.joined(separator: "\n"))")
        } else {
            parts.append("Erledigte Tasks heute: keine")
        }

        // Focus-Block-Statistik
        let completedBlocks = todayBlocks.filter { !$0.completedTaskIDs.isEmpty }.count
        let totalBlocks = todayBlocks.count
        if totalBlocks > 0 {
            parts.append("Focus-Blocks: \(completedBlocks) von \(totalBlocks) bearbeitet")
        }

        return parts.joined(separator: "\n")
    }
    #endif

    // MARK: - Helpers

    private func levelDescription(_ level: FulfillmentLevel) -> String {
        switch level {
        case .fulfilled:    return "Erfuellt"
        case .partial:      return "Teilweise erfuellt"
        case .notFulfilled: return "Nicht erfuellt"
        }
    }

    private func formatTime(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return " (\(formatter.string(from: date)))"
    }
}
```

### View-Integration: EveningReflectionCard.swift

Der bestehende `intentionRow`-Helper liest aktuell direkt `IntentionEvaluationService.fallbackTemplate()`. Er wird um einen optionalen `aiTexts`-Parameter erweitert. Der AI-Text hat Vorrang — wenn keiner vorhanden, bleibt Fallback.

**Neuer Parameter:**

```swift
struct EveningReflectionCard: View {
    let intentions: [IntentionOption]
    let tasks: [LocalTask]
    let focusBlocks: [FocusBlock]
    var aiTexts: [IntentionOption: String] = [:]  // NEU — von DailyReviewView befuellt
    var now: Date = Date()
    // ... Rest unveraendert
}
```

**Geaenderte Text-Aufloesung in intentionRow:**

```swift
// Vorher:
let template = IntentionEvaluationService.fallbackTemplate(intention: intention, level: level)

// Nachher:
let template = aiTexts[intention]
    ?? IntentionEvaluationService.fallbackTemplate(intention: intention, level: level)
```

Kein Spinner, keine Lade-Indikation — der Text wechselt still wenn AI-Text ankommt (SwiftUI State-Update).

### View-Integration: DailyReviewView.swift

**Neuer State:**

```swift
@State private var aiReflectionTexts: [IntentionOption: String] = [:]
```

**Async Loading nach loadData():**

```swift
// In .task { await loadData() } erweitern:
.task {
    await loadData()
    await loadAIReflectionTexts()
}

private func loadAIReflectionTexts() async {
    guard showEveningReflection && DailyIntention.load().isSet else { return }
    let service = EveningReflectionTextService()
    let intention = DailyIntention.load()
    let texts = await service.generateTexts(
        intentions: intention.selections,
        tasks: allLocalTasks,
        focusBlocks: todayBlocks
    )
    aiReflectionTexts = texts
}
```

**EveningReflectionCard-Aufruf (aiTexts hinzugefuegt):**

```swift
EveningReflectionCard(
    intentions: DailyIntention.load().selections,
    tasks: allLocalTasks,
    focusBlocks: todayBlocks,
    aiTexts: aiReflectionTexts   // NEU
)
```

### Vollstaendiges Prompt-Beispiel

**System:**
```
Du bist ein sympathisches Monster — Trainingspartner des Users.
Schreib 2-3 persoenliche Saetze ueber seinen heutigen Tag.
Regeln:
- Nie toxisch positiv ('Du hast das grossartig gemacht!')
- Nie schuldzuweisend ('Du haettest X tun sollen')
- Empathisch und direkt — wie ein ehrlicher Freund
- Bezieh dich auf konkrete Task-Titel wenn vorhanden
- Immer auf Deutsch
- Max 200 Zeichen
```

**User:**
```
Intention: Das grosse haessliche Ding geschafft (bhag)
Ergebnis: Erfuellt
Erledigte Tasks heute:
- 'Steuererklaerung' (15:23) [Wichtigkeit: hoch]
- 'Emails beantworten' (10:15)
- 'Code Review' (14:00)
Focus-Blocks: 2 von 3 bearbeitet
```

**Erwarteter Output:**
```
Die Steuererklaerung lag schon lange da. Jetzt ist sie weg. Das zaehlt mehr als drei 'kleine' Tasks.
```

### Rendering-Strategie (kein Spinner)

```
1. DailyReviewView laedt Daten (loadData)
   → EveningReflectionCard zeigt sofort mit fallbackTemplate()

2. Parallel dazu: loadAIReflectionTexts() laeuft async
   → aiReflectionTexts = [:]  (leer)
   → Card zeigt Fallback

3. AI-Generierung abgeschlossen
   → aiReflectionTexts wird gesetzt
   → SwiftUI re-rendert EveningReflectionCard
   → Text wechselt still zu AI-Text
   → Kein Spinner, kein Flackern
```

### Settings Gate

Der Service prueft `AppSettings.shared.aiScoringEnabled` (bestehender Toggle). Kein neuer Toggle noetig — AI-Texte sind Teil der bestehenden "Apple Intelligence"-Einstellung.

## Expected Behavior

### Input

- `intentions: [IntentionOption]` — ein oder mehrere Intentions (max 6)
- `tasks: [LocalTask]` — alle Tasks des Users (Service filtert selbst auf heute)
- `focusBlocks: [FocusBlock]` — alle Blocks (Service filtert selbst auf heute)
- `now: Date` — aktuelle Zeit (injectable fuer Tests)

### Output

- `[IntentionOption: String]` — Dictionary mit AI-Texten fuer jede Intention wo Generierung erfolgreich war
- Fehlende Eintraege: Caller nutzt `IntentionEvaluationService.fallbackTemplate()`
- Max-Laenge pro Text: 300 Zeichen (nach `.prefix(300)`)

### Side Effects

- Kein SwiftData-Schreiben
- Kein CloudKit-Sync
- Nur lokale Foundation Models-Nutzung (on-device, kein Netzwerk)
- Keine persistierten Texte — bei jedem Abend-Spiegel-Aufruf neu generiert

### Verhalten ohne Apple Intelligence

- `isAvailable` gibt `false` zurueck
- `generateTexts()` gibt `[:]` zurueck (sofort, kein async-Warten)
- EveningReflectionCard zeigt unveraendert `fallbackTemplate()`-Texte
- Keine Fehlermeldung, keine UI-Aenderung

### Verhalten bei aiScoringEnabled == false

- Service gibt `[:]` zurueck (sofort)
- Fallback-Templates bleiben sichtbar
- User kann KI jederzeit in Settings aktivieren

### Verhalten bei Generierungs-Fehler

- Exception wird gefangen (try/catch in `performGeneration`)
- Fehler wird per `print()` geloggt (kein Crash, kein Alert)
- Rueckgabe: `nil` → Caller nutzt Fallback

## Test Plan

### Unit Tests (FocusBloxTests/EveningReflectionTextServiceTests.swift)

| Test | Beschreibung | Setup |
|------|-------------|-------|
| `test_isAvailable_returnsBool` | Prueft dass `isAvailable` einen Bool zurueckgibt (true oder false — je nach Simulator) | — |
| `test_generateText_returnsNilWhenNotAvailable` | Kein AI-Call wenn `isAvailable == false` — gibt `nil` zurueck | `isAvailable` mocken / Test laeuft auf Simulator ohne AI |
| `test_generateText_returnsNilWhenAiDisabled` | Kein AI-Call wenn `aiScoringEnabled == false` | `AppSettings.shared.aiScoringEnabled = false` |
| `test_generateTexts_returnsEmptyWhenAiDisabled` | Batch gibt `[:]` zurueck wenn disabled | `AppSettings.shared.aiScoringEnabled = false` |
| `test_generateTexts_returnsEmptyWhenNotAvailable` | Batch gibt `[:]` zurueck wenn nicht verfuegbar | Simulator ohne AI |
| `test_buildPrompt_includesIntentionLabel` | Prompt enthaelt Intention-Label (z.B. "bhag") | `buildPrompt()` internal call via Reflexion oder exposte test-helper |
| `test_buildPrompt_includesCompletedTaskTitles` | Prompt enthaelt Task-Titel erledigter Tasks | Tasks mit `isCompleted=true`, `completedAt=today` |
| `test_buildPrompt_limitsTasksToFive` | Prompt enthaelt max 5 Task-Titel | 7 erledigte Tasks uebergeben |
| `test_buildPrompt_excludesFutureTasks` | Nur heute erledigte Tasks im Prompt | Mix aus heute und gestern erledigten Tasks |
| `test_buildPrompt_includesFulfillmentLevel` | Prompt enthaelt "Erfuellt"/"Teilweise"/"Nicht erfuellt" | Alle drei FulfillmentLevel testen |
| `test_buildPrompt_includesFocusBlockStats` | Prompt enthaelt Focus-Block-Statistik wenn Blocks vorhanden | 3 Blocks, 2 mit completedTaskIDs |
| `test_buildPrompt_emptyTasksCase` | Prompt ist valide wenn keine Tasks erledigt | `tasks = []` |
| `test_fallbackIntegration_cardShowsFallbackWhenAiEmpty` | Card zeigt Fallback wenn `aiTexts` leer | `aiTexts = [:]` auf EveningReflectionCard |
| `test_fallbackIntegration_cardShowsAiTextWhenProvided` | Card zeigt AI-Text wenn in `aiTexts` vorhanden | `aiTexts = [.fokus: "AI-Text"]` |
| `test_fallbackIntegration_cardPreservesAiTextPriority` | AI-Text hat Vorrang vor Fallback | Beide vorhanden — AI-Text gewinnt |

### UI Tests — Erweiterung EveningReflectionCardUITests.swift

Bestehende Tests (Phase 3c) bleiben unveraendert. Neue Tests fuer Phase 3d:

| Test | Beschreibung | Launch Args |
|------|-------------|-------------|
| `test_eveningCard_showsTextWhenAiDisabled_fallbackVisible` | Fallback-Text sichtbar wenn AI disabled | `-UITesting -CoachModeEnabled -ForceEveningReflection -AIDisabled` |
| `test_eveningCard_textNotEmpty_afterLoad` | Reflection-Text (Fallback oder AI) ist nie leer | `-UITesting -CoachModeEnabled -ForceEveningReflection` |

**Hinweis zu AI-Text in UI Tests:** Der konkrete AI-generierte Text ist nicht deterministisch und kann nicht per `XCTAssertEqual` geprueft werden. UI Tests pruefen nur:
1. Ist ein Text vorhanden (nicht leer)?
2. Ist der Fallback-Text sichtbar wenn AI disabled?

Das ist absichtlich — AI-Output-Korrektheit ist Aufgabe der Unit Tests ueber Mock-Sessions.

### Neue Launch-Argumente

| Argument | Zweck |
|----------|-------|
| `-AIDisabled` | Setzt `AppSettings.shared.aiScoringEnabled = false` in UITests |

In `FocusBloxApp.swift` / `DailyReviewView.swift` in `.onAppear` oder App-Init:
```swift
if ProcessInfo.processInfo.arguments.contains("-AIDisabled") {
    AppSettings.shared.aiScoringEnabled = false
}
```

## Affected Files

| File | Change Type | Geschaetzte LoC |
|------|-------------|-----------------|
| `Sources/Services/EveningReflectionTextService.swift` | CREATE | ~120 |
| `Sources/Views/EveningReflectionCard.swift` | MODIFY | +3 (Parameter + Text-Aufloesung) |
| `Sources/Views/DailyReviewView.swift` | MODIFY | +15 (State + loadAIReflectionTexts) |
| `FocusBloxTests/EveningReflectionTextServiceTests.swift` | CREATE | ~150 |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | MODIFY | +20 (2 neue Tests + -AIDisabled) |

**Total:** 5 Dateien, ~308 LoC

## Known Limitations

1. **Nicht deterministisch:** AI-generierter Text variiert bei gleichem Input — kein reproduzierbarer Output fuer Snapshot-Tests.
2. **Latenz:** Foundation Models-Aufruf kann 1-5 Sekunden dauern. User sieht in dieser Zeit den Fallback-Text.
3. **Kein Caching:** Texte werden nicht gespeichert — bei jedem Tab-Wechsel zum Review-Tab wird neu generiert. Koennte spaeter optimiert werden.
4. **Sprache:** AI-Modell gibt manchmal englische Texte bei englischen Task-Titeln — der System-Prompt schreibt Deutsch vor, ist aber kein hartes Enforcement.
5. **Tokens-Limit:** Bei sehr vielen Tasks (>5) werden nur die ersten 5 in den Prompt eingebaut, um Token-Limits zu respektieren.
6. **macOS-Parity:** `EveningReflectionCard` ist ein Shared-View in `Sources/`. Da `DailyReviewView` auch Shared ist, gilt die AI-Integration automatisch fuer beide Plattformen — keine separate macOS-Implementierung noetig.
7. **App Extensions:** FoundationModels ist in Share Extension / Watch / Siri nicht verfuegbar — irrelevant, da Evening Reflection nur in der Hauptapp sichtbar ist.

## Changelog

- 2026-03-13: Initial spec created
