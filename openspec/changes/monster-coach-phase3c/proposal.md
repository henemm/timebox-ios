# Proposal: Monster Coach Phase 3c — Abend-Spiegel (Evening Reflection Card)

> Erstellt: 2026-03-12
> Status: Zur Freigabe
> Bezug: User Story `docs/project/stories/monster-coach.md` — Section "Der Abend-Spiegel"

---

## Was und Warum

### Das Problem

Die Morgen-Intention und die Smart Notifications begleiten durch den Tag — aber abends passiert nichts. Der User hat keine Moeglichkeit zu sehen, ob er bekommen hat was er sich morgens gewuenscht hat. Es fehlt der Spiegel am Ende des Tages.

### Was diese Phase loest

Phase 3c schliesst den Tagesbogen: Morgen → Tag → **Abend**. Ab 18 Uhr erscheint im Review-Tab eine Karte die automatisch auswertet, ob die Morgen-Intention erfuellt wurde. Kein User-Input noetig — die Bewertung kommt komplett aus den Task-Daten.

Die Phase liefert:

1. **3-stufige Erfuellungsbewertung** — `evaluateFulfillment()` als neue Methode im `IntentionEvaluationService`. Drei Stufen: erfuellt / teilweise / nicht erfuellt. Granularer als das bestehende `isFulfilled()` (Bool).

2. **Block-Completion-Berechnung** — `blockCompletionPercentage()` Helper fuer die Fokus-Intention-Stufen (≥70% / 40-69% / <40%).

3. **EveningReflectionCard** — Neue SwiftUI View die pro gewaehlter Intention den Erfuellungsgrad zeigt. Mit Stimmungs-Farben (warm bei erfuellt, gedaempft bei teilweise, grau-blau bei nicht erfuellt) und Fallback-Template-Texten.

4. **Integration in DailyReviewView** — Card erscheint ab 18 Uhr wenn Coach-Modus aktiv und Intention gesetzt.

---

## Scope: Was gebaut wird

### 1. FulfillmentLevel Enum + evaluateFulfillment() (IntentionEvaluationService)

`Sources/Services/IntentionEvaluationService.swift`

Rein additive Erweiterung — `isFulfilled()` und `detectGap()` bleiben unangetastet.

**Neues Enum:**

```swift
enum FulfillmentLevel {
    case fulfilled
    case partial
    case notFulfilled
}
```

**Neue Methode:**

```swift
static func evaluateFulfillment(
    intention: IntentionOption,
    tasks: [LocalTask],
    focusBlocks: [FocusBlock],
    now: Date = Date()
) -> FulfillmentLevel
```

**Bewertungs-Logik pro Intention:**

| Intention | Fulfilled | Partial | Not Fulfilled |
|-----------|-----------|---------|---------------|
| `.survival` | ≥1 Task erledigt heute | — (kein Partial) | 0 Tasks heute erledigt |
| `.fokus` | Block-Completion ≥70% | Block-Completion 40-69% | <40% oder keine Blocks heute |
| `.bhag` | Task mit `importance == 3` erledigt heute | Tasks erledigt, aber keiner mit importance 3 | Keine Tasks erledigt heute |
| `.balance` | Tasks in ≥3 verschiedenen `taskType`-Kategorien | Tasks in genau 2 Kategorien | ≤1 Kategorie |
| `.growth` | Task mit `taskType == "learning"` erledigt heute | — (kein Partial) | Kein "learning" Task |
| `.connection` | Task mit `taskType == "giving_back"` erledigt heute | — (kein Partial) | Kein "giving_back" Task |

**Block-Completion Helper:**

```swift
static func blockCompletionPercentage(
    focusBlocks: [FocusBlock],
    now: Date = Date()
) -> Double
```

Berechnet: `completedTaskIDs.count / taskIDs.count` ueber alle heutigen Blocks (aggregiert). Gibt 0.0 zurueck wenn keine Blocks oder keine Tasks in Blocks.

---

### 2. EveningReflectionCard (neue View)

`Sources/Views/EveningReflectionCard.swift`

**Parameter (keine eigenen Queries, rein data-driven):**

```swift
struct EveningReflectionCard: View {
    let intentions: [IntentionOption]
    let tasks: [LocalTask]
    let focusBlocks: [FocusBlock]
    var now: Date = Date()  // Testbarkeit
}
```

**Aufbau der Card:**

```
┌──────────────────────────────────────┐
│  "Dein Abend-Spiegel"      [Headline]│
│                                      │
│  ┌──────────────────────────────┐    │
│  │ 🎯 Fokus                    │    │  ← Pro Intention eine Row
│  │ ✓ Erfuellt                  │    │
│  │ "Du bist bei der Sache      │    │
│  │  geblieben. Stark."         │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │ ⚖ Balance                   │    │  ← Zweite Intention (Multi-Select)
│  │ ⚠ Teilweise                 │    │
│  │ "Zwei Bereiche abgedeckt —  │    │
│  │  fast ausgeglichen."        │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

**Pro Intention-Row:**
- Icon + Label der Intention (aus `IntentionOption.icon` / `.label`)
- Erfuellungs-Badge: checkmark.circle (fulfilled), exclamationmark.circle (partial), xmark.circle (not fulfilled)
- Fallback-Template-Text (statisch, pro Intention + FulfillmentLevel)
- Hintergrundfarbe basierend auf FulfillmentLevel:
  - `.fulfilled`: `intention.color.opacity(0.15)` (warm, leuchtend)
  - `.partial`: `intention.color.opacity(0.08)` (gedaempft)
  - `.notFulfilled`: `Color.secondary.opacity(0.08)` (grau)

**Card-Wrapper:** `.ultraThinMaterial` Background mit `RoundedRectangle(cornerRadius: 16)` — konsistent mit bestehendem Card-Stil.

**Fallback-Templates (statisch, alle auf Deutsch):**

| Intention | Fulfilled | Partial | Not Fulfilled |
|-----------|-----------|---------|---------------|
| survival | "Du hast es geschafft. Auch das zaehlt." | — | "Manchmal reicht es zu atmen. Morgen ist ein neuer Tag." |
| fokus | "Du bist bei der Sache geblieben. Stark." | "Nicht perfekt fokussiert — aber du warst dran." | "Viel dazwischen gekommen heute. Passiert." |
| bhag | "DU HAST ES GETAN! Weisst du was das bedeutet?!" | "Tasks erledigt — aber das grosse Ding wartet noch." | "Noch nicht dran gewesen. Morgen ist die Chance." |
| balance | "Was fuer ein runder Tag." | "Zwei Bereiche abgedeckt — fast ausgeglichen." | "Einseitig heute. Morgen mal was anderes probieren?" |
| growth | "Du bist heute klueger als gestern." | — | "Kein Lernen heute — auch okay. Neugier kommt wieder." |
| connection | "Du hast jemandem den Tag besser gemacht." | — | "Fuer dich heute. Fuer andere morgen." |

**Accessibility Identifiers:**
- Card Container: `eveningReflectionCard`
- Pro Intention-Row: `eveningResult_\(intention.rawValue)` (z.B. `eveningResult_fokus`)
- Erfuellungs-Badge: `fulfillmentBadge_\(intention.rawValue)`
- Template-Text: `reflectionText_\(intention.rawValue)`

---

### 3. Integration in DailyReviewView

`Sources/Views/DailyReviewView.swift`

**Minimale Aenderungen (3 Stellen):**

1. **Neues State-Var** (neben bestehendem `allTasks: [PlanItem]`):
```swift
@State private var allLocalTasks: [LocalTask] = []
```

2. **In `loadData()`** — zweite Zuweisung aus dem gleichen Fetch:
```swift
let localTasks = try modelContext.fetch(descriptor)
allTasks = localTasks.map { PlanItem(localTask: $0) }
allLocalTasks = localTasks  // NEU
```

3. **Card-Einbettung** — nach MorningIntentionView, vor dailyStatsHeader:
```swift
if coachModeEnabled, reviewMode == .today {
    MorningIntentionView()  // bestehend

    // NEU: Abend-Spiegel ab 18 Uhr
    if Calendar.current.component(.hour, from: Date()) >= 18,
       let intention = DailyIntention.load(),
       intention.isSet {
        EveningReflectionCard(
            intentions: intention.selections,
            tasks: allLocalTasks,
            focusBlocks: todayBlocks
        )
    }
}
```

---

## Dateien und Scoping

| Datei | Aenderung | Schaetzung |
|-------|-----------|-----------|
| `Sources/Services/IntentionEvaluationService.swift` | MODIFY (+) — FulfillmentLevel + evaluateFulfillment + blockCompletionPercentage | +40 LoC |
| `Sources/Views/EveningReflectionCard.swift` | **Neu** — Card View mit Intention-Rows | +80 LoC |
| `Sources/Views/DailyReviewView.swift` | MODIFY (+) — State-Var + Card-Einbettung | +15 LoC |

**Produktions-Code: 3 Dateien, ca. +135 LoC**

| Test-Datei | Aenderung | Schaetzung |
|------------|-----------|-----------|
| `FocusBloxTests/IntentionEvaluationServiceTests.swift` | MODIFY (+) — Tests fuer evaluateFulfillment + blockCompletionPercentage | +60 LoC |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | **Neu** — UI Tests fuer Card-Sichtbarkeit und Inhalte | +50 LoC |

**Test-Code: 2 Dateien, ca. +110 LoC**

**Gesamt: 5 Dateien, ca. +245 LoC — im Scope.**

---

## Architektur-Entscheidungen

### Warum evaluateFulfillment() statt isFulfilled() erweitern?

`isFulfilled()` wird von Phase 3b (Smart Notifications + Stille-Regel) aktiv genutzt. Eine Aenderung der Signatur oder des Verhaltens wuerde Phase 3b regressieren. `evaluateFulfillment()` ist eine neue Methode mit anderer Semantik (3 Stufen statt Bool). Kein Regressions-Risiko.

### Warum kein FulfillmentLevel als eigene Datei?

Das Enum gehoert semantisch zum IntentionEvaluationService — es ist Evaluation-Domain, nicht Model-Domain. Zusammen in einer Datei halten reduziert Dateien und haelt die Kohaesion hoch.

### Warum 18-Uhr-Guard in DailyReviewView und nicht in der Card?

Testbarkeit. Die Card kann in Tests mit beliebigen Daten instanziiert werden ohne Time-Injection. Die Card selbst weiss nicht wann sie sichtbar ist — die Entscheidung liegt beim Host.

### Warum allLocalTasks als zweites State-Var?

IntentionEvaluationService erwartet `[LocalTask]`, DailyReviewView arbeitet mit `[PlanItem]`. Statt einen Adapter oder Protocol zu bauen: gleicher Fetch, zweite Zuweisung. Minimaler Code, null Risiko.

### Warum kein macOS in dieser Phase?

`MacReviewView` hat noch keine Coach-Features in `DayReviewContent` (kein MorningIntentionView, kein Coach-Guard). Die macOS-Integration ist ein eigenes Ticket das alle Coach-Features auf macOS bringt — nicht nur den Abend-Spiegel.

---

## Was NICHT in Phase 3c enthalten ist

- **Foundation Models Text** (Phase 3d) — AI-generierter persoenlicher Abend-Text. Die Card hat einen Text-Bereich der in Phase 3c mit Fallback-Templates gefuellt wird.
- **Abend Push-Notification** (Phase 3e) — separater Notification-Typ fuer 20:00 Uhr.
- **Siri Integration** (Phase 3f) — "Hey Siri, wie war mein Tag?"
- **macOS** — MacReviewView Integration als separates Follow-up.
- **Bestehende Bugs** — BHAG-Gap duplicate case und FOKUS-Logik in `isFulfilled()` werden nicht angefasst (Phase 3b-Bestand, separates Ticket).
