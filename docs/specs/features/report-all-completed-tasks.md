---
entity_id: report-all-completed-tasks
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.1"
tags: [review, report, completed-tasks]
---

# Report: Alle erledigten Tasks anzeigen

## Approval

- [ ] Approved

## Purpose

Der Tagesreport (iOS + macOS) soll ALLE am Tag erledigten Tasks anzeigen - unabhaengig davon, ob sie innerhalb oder ausserhalb eines FocusBlocks abgehakt wurden. Aktuell werden nur Tasks gezaehlt, deren ID in `block.completedTaskIDs` steht.

## Source

- **iOS:** `Sources/Views/DailyReviewView.swift`
- **macOS:** `FocusBloxMac/MacReviewView.swift` (DayReviewContent + WeekReviewContent)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| PlanItem | Model (existiert) | `completedAt: Date?`, `isCompleted: Bool` - bereits vorhanden |
| LocalTask | Model (existiert) | `completedAt: Date?`, `isCompleted: Bool` - bereits vorhanden |
| FocusBlock | Model (existiert) | `completedTaskIDs` - bleibt fuer Block-Cards |
| ReviewTaskRow | View (existiert) | Wiederverwendbar fuer Task-Zeilen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/DailyReviewView.swift` | MODIFY | Daily + Weekly: Stats und Kategorie-Stats auf completedAt-Filter |
| `FocusBloxMac/MacReviewView.swift` | MODIFY | DayReviewContent + WeekReviewContent: Stats auf completedAt-Filter |

## Implementation Details

### iOS: DailyReviewView.swift

**1. Neue computed properties (nach Zeile 28):**

```swift
/// Alle heute erledigten Tasks (Block + Backlog)
private var todayCompletedTasks: [PlanItem] {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    return allTasks.filter { task in
        guard task.isCompleted, let completedAt = task.completedAt else { return false }
        return completedAt >= startOfToday
    }
}

/// Alle diese Woche erledigten Tasks
private var weekCompletedTasks: [PlanItem] {
    let calendar = Calendar.current
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
    return allTasks.filter { task in
        guard task.isCompleted, let completedAt = task.completedAt else { return false }
        return completedAt >= weekInterval.start && completedAt < weekInterval.end
    }
}

/// Tasks die heute erledigt wurden aber in KEINEM Block stehen
private var todayOutsideSprintTasks: [PlanItem] {
    let blockCompletedIDs = Set(todayBlocks.flatMap { $0.completedTaskIDs })
    return todayCompletedTasks.filter { !blockCompletedIDs.contains($0.id) }
}
```

**2. `totalCompleted` aendern (Zeile 111-113):**
```swift
// ALT: todayBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
// NEU:
private var totalCompleted: Int { todayCompletedTasks.count }
```

**3. `weeklyTotalCompleted` aendern (Zeile 98-99):**
```swift
// ALT: weekBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
// NEU:
private var weeklyTotalCompleted: Int { weekCompletedTasks.count }
```

**4. `dailyCategoryStatsSection` - `computeCategoryStats` anpassen:**
Statt `completedIDs` aus Blocks direkt `todayCompletedTasks` nutzen:
```swift
private var dailyCategoryStats: [CategoryStat] {
    var taskStats: [String: Int] = [:]
    for task in todayCompletedTasks {
        taskStats[task.taskType, default: 0] += task.effectiveDuration
    }
    let combined = statsCalculator.computeCategoryMinutes(
        taskMinutesByCategory: taskStats, calendarEvents: todayCalendarEvents
    )
    return TaskCategory.allCases.compactMap { config in
        guard let minutes = combined[config.rawValue], minutes > 0 else { return nil }
        return CategoryStat(config: config, minutes: minutes)
    }.sorted { $0.minutes > $1.minutes }
}
```

Analog fuer `categoryStats` (weekly): `weekCompletedTasks` statt Block-Filter.

**5. `computeCategoryStats(blocks:events:)` entfernen** - wird durch die direkten computed properties ersetzt.

**6. Empty State anpassen (Zeile 146):**
```swift
// ALT: if todayBlocks.isEmpty { emptyState }
// NEU: if todayBlocks.isEmpty && todayCompletedTasks.isEmpty { emptyState }
```

**7. Sektion "Ohne Sprint" nach blocksSection (Zeile 153):**
```swift
// Nach blocksSection, vor Ende des VStack
if !todayOutsideSprintTasks.isEmpty {
    outsideSprintSection
}
```

Neue View:
```swift
private var outsideSprintSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Ohne Sprint erledigt")
                .font(.headline)
            Spacer()
            Text("\(todayOutsideSprintTasks.count)")
                .font(.headline)
                .foregroundStyle(.green)
        }
        VStack(spacing: 8) {
            ForEach(todayOutsideSprintTasks) { task in
                ReviewTaskRow(task: task, isCompleted: true)
            }
        }
    }
    .padding()
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(.background)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
    )
}
```

### macOS: MacReviewView.swift

**1. DayReviewContent.totalCompleted aendern (Zeile 160-162):**
```swift
// ALT: blocks.reduce(0) { $0 + $1.completedTaskIDs.count }
// NEU:
private var totalCompleted: Int { completedTasks.count }
```
macOS hat bereits `completedTasks: [LocalTask]` mit allen heute erledigten Tasks via `@Query`.

**2. DayReviewContent: Sektion fuer Nicht-Block-Tasks nach blocksSection:**
```swift
private var outsideSprintTasks: [LocalTask] {
    let blockTaskIDs = Set(blocks.flatMap { $0.taskIDs })
    return completedTasks.filter { !blockTaskIDs.contains($0.id) }
}
```
Anzeige analog iOS - Card mit Titel "Ohne Sprint erledigt" + Task-Rows.

**3. DayReviewContent: Empty State anpassen (Zeile 196):**
```swift
// ALT: if blocks.isEmpty && completedTasks.isEmpty && calendarEvents.isEmpty
// Bleibt: macOS prueft bereits completedTasks - korrekt
```

**4. WeekReviewContent.totalCompleted aendern (Zeile 375-376):**
```swift
// ALT: blocks.reduce(0) { $0 + $1.completedTaskIDs.count }
// NEU:
private var totalCompleted: Int { completedTasks.count }
```

## Expected Behavior

### Szenario 1: Nur Block-Tasks erledigt
- Report zeigt 3/5 Tasks, Block-Cards wie bisher. Keine "Ohne Sprint" Sektion.

### Szenario 2: Tasks im Backlog + im Block erledigt
- Stats zeigen 5 total (3 Block + 2 Backlog).
- Block-Cards zeigen die 3 Block-Tasks.
- "Ohne Sprint erledigt" Card zeigt die 2 Backlog-Tasks.

### Szenario 3: Nur Backlog-Tasks erledigt (kein Block heute)
- Report zeigt erledigte Tasks statt leerem State.
- Nur "Ohne Sprint erledigt" Card sichtbar.

### Szenario 4: Weekly View
- Wochen-Stats zaehlen alle erledigten Tasks der Woche, nicht nur Block-basierte.

## Scope Assessment

- **Files:** 2
- **Estimated LoC:** +50/-10
- **Risk Level:** LOW - bestehende Block-Cards bleiben unveraendert

## Test Plan

### Unit Tests (FocusBloxTests/ReviewOutsideSprintTests.swift)

1. `testTodayCompletedTasks_includesAllCompleted` - PlanItem mit completedAt=heute + isCompleted=true wird gezaehlt
2. `testTodayCompletedTasks_excludesYesterday` - PlanItem mit completedAt=gestern wird NICHT gezaehlt
3. `testTodayCompletedTasks_excludesIncomplete` - PlanItem mit isCompleted=false wird NICHT gezaehlt
4. `testOutsideSprintFilter_excludesBlockTasks` - Task mit ID in block.completedTaskIDs wird aus "Ohne Sprint" Liste gefiltert

### UI Tests (FocusBloxUITests/ReviewCompletedTasksUITests.swift)

1. `testReviewShowsCompletedCount` - "Erledigt" StatItem zeigt Zahl > 0 wenn Tasks mit completedAt heute existieren
2. `testOutsideSprintSectionVisible` - Text "Ohne Sprint erledigt" sichtbar wenn Backlog-Tasks erledigt

## Known Limitations

- Weekly View zeigt keine separate "Ohne Sprint" Sektion (nur angepasste Stats-Zahlen)
- Block-Cards zeigen weiterhin nur ihre eigenen Tasks (korrekt und gewuenscht)

## Changelog

- 2026-02-16: v1.0 Initial spec
- 2026-02-16: v1.1 Validator-Feedback eingearbeitet: Weekly View spezifiziert, Implementation konkretisiert
