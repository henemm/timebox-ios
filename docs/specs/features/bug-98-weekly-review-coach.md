---
entity_id: bug-98-weekly-review-coach
type: feature
created: 2026-03-15
updated: 2026-03-15
status: draft
version: "1.0"
tags: [bug-98, coach, weekly, mein-tag]
---

# Bug 98: Wochen-Review mit motivierenden Coach-Texten

## Approval

- [x] Approved (2026-03-15)

## Purpose

Zwei Probleme fixen:
1. DailyReviewView (Non-Coach): Wochenansicht zeigt leeren Zustand wenn keine Focus-Blocks existieren, obwohl Tasks ohne Sprint erledigt wurden.
2. CoachMeinTagView (Coach-Modus): Hat keine Wochenansicht — nur "heute" wird angezeigt. Soll Wochen-Fortschritt + motivierende Coach-Texte zeigen.

## Source

- **Files:**
  - `Sources/Views/DailyReviewView.swift` — Bug-Fix weekBlocks.isEmpty Guard
  - `Sources/Views/CoachMeinTagView.swift` — ReviewMode Picker + Weekly Content
  - `Sources/Services/IntentionEvaluationService.swift` — completedThisWeek(), evaluateWeeklyFulfillment()
  - `Sources/Services/EveningReflectionTextService.swift` — generateWeeklyTextForCoach(), Weekly-Fallback-Templates

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CoachType | Model | 4 Coaches (Troll, Feuer, Eule, Golem) |
| LocalTask | Model | completedAt, isCompleted, rescheduleCount, importance, taskType |
| FocusBlock | Model | completedTaskIDs, taskIDs, startDate |
| EveningReflectionCard | View | Bestehende Tages-Reflection (bleibt unveraendert) |
| DayProgressSection | Component | Zeigt "X Tasks erledigt" (wird fuer Wochen-Modus erweitert) |

## Implementation Details

### Teil 1: DailyReviewView Bug-Fix

```swift
// VORHER (Zeile 181-191):
case .week:
    if weekBlocks.isEmpty {
        weeklyEmptyState
    } else {
        VStack(spacing: 24) {
            weeklyStatsHeader
            categoryStatsSection
            planningAccuracySection(blocks: weekBlocks)
        }
    }

// NACHHER:
case .week:
    if weekBlocks.isEmpty && weekCompletedTasks.isEmpty {
        weeklyEmptyState
    } else {
        VStack(spacing: 24) {
            weeklyStatsHeader
            categoryStatsSection
            if !weekBlocks.isEmpty {
                planningAccuracySection(blocks: weekBlocks)
            }
            if !weekOutsideSprintTasks.isEmpty {
                weeklyOutsideSprintSection
            }
        }
    }
```

Neue Property `weekOutsideSprintTasks`:
```swift
private var weekOutsideSprintTasks: [PlanItem] {
    let blockCompletedIDs = Set(weekBlocks.flatMap { $0.completedTaskIDs })
    return weekCompletedTasks.filter { !blockCompletedIDs.contains($0.id) }
}
```

### Teil 2: CoachMeinTagView Weekly Mode

```swift
// ReviewMode enum (in CoachMeinTagView oder shared):
enum ReviewMode: String, CaseIterable {
    case today = "Heute"
    case week = "Diese Woche"
}

// Neuer Picker + Switch in content:
Picker("Zeitraum", selection: $reviewMode) {
    ForEach(ReviewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
}
.pickerStyle(.segmented)

switch reviewMode {
case .today:
    // Bestehender Content (MorningIntention, DayProgress, EveningReflection)
case .week:
    weekProgressSection           // "X Tasks diese Woche erledigt"
    WeeklyReflectionCard(...)     // Coach-motivierender Wochen-Text
}
```

### Teil 3: Weekly Fulfillment + AI-Text

IntentionEvaluationService:
```swift
static func completedThisWeek(_ tasks: [LocalTask], now: Date = Date()) -> [LocalTask]
static func focusBlocksThisWeek(_ focusBlocks: [FocusBlock], now: Date = Date()) -> [FocusBlock]
static func evaluateWeeklyFulfillment(coach:tasks:focusBlocks:now:) -> FulfillmentLevel
```

Wochen-Schwellenwerte:
| Coach | fulfilled | partial |
|-------|-----------|---------|
| Troll | 3+ aufgeschobene Tasks erledigt | 1-2 aufgeschobene Tasks |
| Feuer | 3+ wichtige Tasks erledigt | 1-2 wichtige Tasks |
| Eule | 70%+ Block-Completion | 40%+ Block-Completion |
| Golem | 4+ Kategorien abgedeckt | 2-3 Kategorien |

EveningReflectionTextService:
```swift
func generateWeeklyTextForCoach(coach:tasks:focusBlocks:now:) async -> String?
func buildWeeklyPrompt(coach:level:tasks:focusBlocks:now:) -> String
static func weeklyFallbackTemplate(coach:level:) -> String
```

Weekly-Fallback-Templates (12 Stueck: 4 Coaches x 3 Levels):
- Troll fulfilled: "Eine ganze Woche lang hast du dich den Dingen gestellt..."
- Troll partial: "Ein paar aufgeschobene Sachen angegangen..."
- Troll notFulfilled: "Diese Woche hast du die unangenehmen Dinge..."
- (etc. fuer Feuer, Eule, Golem)

## Expected Behavior

- **Coach AN + Heute:** Unveraendert (MorningIntention, DayProgress, EveningReflection)
- **Coach AN + Diese Woche:** Wochen-Fortschritt + Coach-motivierender Wochen-Text
- **Coach AUS + Heute:** Unveraendert
- **Coach AUS + Diese Woche:** Bug gefixt — zeigt auch Tasks ohne Sprint + outsideSprintSection
- **Plattform:** iOS + macOS (CoachMeinTagView ist shared, DailyReviewView ist iOS-only)

## Known Limitations

- macOS MacReviewView (Non-Coach) wird NICHT in diesem Ticket gefixt (separates Ticket)
- Wochen-AI-Text nutzt Foundation Models (wie Tages-Text) — nicht auf allen Geraeten verfuegbar, Fallback-Templates greifen

## Changelog

- 2026-03-15: Initial spec created from Bug 98 analysis
