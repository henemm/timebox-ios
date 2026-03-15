---
entity_id: evening-reflection-macos
type: feature
created: 2026-03-15
updated: 2026-03-15
status: implemented
version: "1.0"
tags: [monster-coach, macos, phase-6d, evening-reflection]
---

# Feature Spec: Phase 6d — EveningReflectionCard in macOS

## Approval

- [x] Approved & Implemented (2026-03-15)

## Purpose

Der Abend-Spiegel (EveningReflectionCard) zeigt ab 18 Uhr eine Coach-spezifische Tages-Auswertung mit Fulfillment-Level, Monster-Icon und persoenlichem Reflexionstext (KI oder Fallback). Diese Funktion existiert auf iOS (CoachMeinTagView), fehlt aber auf macOS. Phase 6d schliesst diese Luecke, indem die shared EveningReflectionCard in MacCoachReviewView eingebettet wird.

## Source

- **File (MODIFY):** `FocusBloxMac/MacCoachReviewView.swift`
- **File (MODIFY):** `FocusBloxMacUITests/MacCoachReviewUITests.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `EveningReflectionCard` | Shared View | Wird direkt eingebettet (Sources/Views/) |
| `IntentionEvaluationService` | Shared Service | evaluateFulfillment() + fallbackTemplate() — intern von Card genutzt |
| `EveningReflectionTextService` | Shared Service | AI-Text-Generierung (Foundation Models) |
| `DailyCoachSelection` | Shared Model | Heutigen Coach laden |
| `EventKitRepository` | Shared Service | FocusBlocks laden (via Environment, bereits injiziert) |
| `FocusBlock` | Shared Model | Parameter fuer Fulfillment-Berechnung |
| `ContentView` | macOS View | Routing: Review-Tab conditional (bereits implementiert) |

## Implementation Details

### 1. MacCoachReviewView.swift (MODIFY, +30 LoC)

**Neue Properties:**

```swift
@Environment(\.eventKitRepository) private var eventKitRepo
@State private var todayBlocks: [FocusBlock] = []
@State private var aiReflectionText: String?
@AppStorage("intentionJustSet") private var intentionJustSet: Bool = false
```

**Neue Computed Property:**

```swift
private var showEveningReflection: Bool {
    if ProcessInfo.processInfo.arguments.contains("-ForceEveningReflection") {
        return true
    }
    return Calendar.current.component(.hour, from: Date()) >= 18
}
```

**View-Erweiterung (nach dayProgressSection):**

```
ScrollView > VStack(spacing: 16):
  1. MorningIntentionView()          (bestehend)
  2. dayProgressSection              (bestehend)
  3. EveningReflectionCard(...)      (NEU, conditional)
```

```swift
if showEveningReflection, let coach = DailyCoachSelection.load().coach {
    EveningReflectionCard(
        coach: coach,
        tasks: allLocalTasks,
        focusBlocks: todayBlocks,
        aiText: aiReflectionText
    )
    .padding(.horizontal)
}
```

**loadData() erweitern:**

```swift
// Bestehend: LocalTask fetch
// NEU: FocusBlock fetch
do {
    let today = Calendar.current.startOfDay(for: Date())
    todayBlocks = try eventKitRepo.fetchFocusBlocks(for: today)
} catch {
    todayBlocks = []
}
```

**Neue Funktion — loadAIReflectionText():**

```swift
private func loadAIReflectionText() async {
    guard showEveningReflection else { return }
    let selection = DailyCoachSelection.load()
    guard let coach = selection.coach else { return }

    let service = EveningReflectionTextService()
    aiReflectionText = await service.generateTextForCoach(
        coach: coach,
        tasks: allLocalTasks,
        focusBlocks: todayBlocks
    )
}
```

**Task + onChange erweitern:**

```swift
.task {
    await loadData()
    await loadAIReflectionText()
}
.onChange(of: intentionJustSet) {
    if intentionJustSet {
        Task { await loadAIReflectionText() }
    }
}
```

### 2. MacCoachReviewUITests.swift (MODIFY, +25 LoC)

3 neue Tests:

**Test 5: Evening Card sichtbar bei ForceEveningReflection + Coach gesetzt**
- Launch mit `-coachModeEnabled 1 -ForceEveningReflection -MockIntentionSet`
- Navigiere zu Review-Tab
- Assert: `eveningReflectionCard` existiert

**Test 6: Evening Card NICHT sichtbar ohne Coach**
- Launch mit `-coachModeEnabled 1 -ForceEveningReflection` (KEIN MockIntentionSet)
- Navigiere zu Review-Tab
- Assert: `eveningReflectionCard` existiert NICHT

**Test 7: Evening Card zeigt Coach-spezifischen Inhalt**
- Launch mit `-coachModeEnabled 1 -ForceEveningReflection -MockIntentionSet`
- Navigiere zu Review-Tab
- Assert: `eveningResult_*` existiert (Coach-Ergebnis-Row)

## Expected Behavior

- **Coach OFF:** Review-Tab zeigt MacReviewView (unveraendert, keine EveningReflectionCard)
- **Coach ON, vor 18 Uhr:** Review-Tab zeigt MorningIntentionView + DayProgress (keine Card)
- **Coach ON, ab 18 Uhr, Coach gesetzt:** EveningReflectionCard erscheint unter DayProgress
- **Coach ON, ab 18 Uhr, KEIN Coach gesetzt:** Keine Card (guard: `coach != nil`)
- **AI verfuegbar:** Card zeigt KI-generierten persoenlichen Reflexionstext
- **AI nicht verfuegbar:** Card zeigt Fallback-Template (z.B. "Fokus gehalten. Nur das Geplante...")
- **Side effects:**
  - FocusBlocks werden via EventKitRepository geladen (Kalender-Zugriff noetig)
  - AI-Text wird on-device generiert (Foundation Models, kein Netzwerk)

## Accessibility Identifiers

| Element | Identifier | Herkunft |
|---------|-----------|----------|
| Card Container | `eveningReflectionCard` | shared EveningReflectionCard |
| Coach-Ergebnis-Row | `eveningResult_<coach>` | shared EveningReflectionCard |
| Monster-Icon | `monsterIcon_<coach>` | shared EveningReflectionCard |
| Reflexionstext | `reflectionText_<coach>` | shared EveningReflectionCard |
| Fulfillment-Badge | `fulfillmentBadge_<coach>` | shared EveningReflectionCard |

Alle IDs kommen aus der shared EveningReflectionCard — keine neuen IDs in MacCoachReviewView noetig.

## Known Limitations

- AI-Text ist nicht deterministisch — UI Tests pruefen nur Existenz, nicht Inhalt
- EveningReflectionCard wird nur angezeigt wenn ein Coach gewaehlt ist (bewusstes Design)
- Kein voller CoachMeinTagView-Ausbau auf macOS — kommt in Phase 6e

## Testplan

3 UI Tests (macOS), erweitern bestehende MacCoachReviewUITests.swift:

| # | Test | Launch Args | Assert |
|---|------|-------------|--------|
| 5 | Evening Card sichtbar | `-coachModeEnabled 1 -ForceEveningReflection -MockIntentionSet` | `eveningReflectionCard` exists |
| 6 | Evening Card unsichtbar ohne Coach | `-coachModeEnabled 1 -ForceEveningReflection` | `eveningReflectionCard` NOT exists |
| 7 | Coach-Ergebnis sichtbar | `-coachModeEnabled 1 -ForceEveningReflection -MockIntentionSet` | `eveningResult_*` exists |

## Scope

- Files: 2 (beide MODIFY)
- Estimated LoC: +55 (30 View + 25 Tests)
- Risk Level: LOW

## Changelog

- 2026-03-15: Implementation completed — EveningReflectionCard embedded in MacCoachReviewView, shown after 18:00. Shared Card displays Coach-Fulfillment with Monster-Icon and fallback reflection text. AI text not available on macOS (EveningReflectionTextService excluded from macOS target). 7 UI Tests green (4 existing Phase 6c + 3 new Phase 6d). -MockIntentionSet launch argument support added to FocusBloxMacApp.
- 2026-03-15: Initial spec created
