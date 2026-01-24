---
entity_id: weekly-review
type: feature
created: 2026-01-23
status: draft
workflow: weekly-review
version: "1.0"
tags: [sprint-6, review, statistics, categories]
---

# Weekly Review (Wochen-Rückblick)

- [ ] Approved for implementation

## Purpose

"Womit habe ich meine Woche verbracht?" - Zeit-Analyse nach Kategorie. Erweitert den bestehenden Rückblick-Tab um Wochen-Ansicht.

## Scope

### Zu ändernde Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/DailyReviewView.swift` | Segmented Picker + Weekly Stats + Category Chart |
| `FocusBloxUITests/DailyReviewUITests.swift` | Tests für Wochen-Ansicht erweitern |

### Geschätzter Umfang

- **Geänderte LoC:** ~150
- **Dateien total:** 2

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBlock` | Model | Block-Daten mit `completedTaskIDs`, `startDate` |
| `PlanItem` | Model | `taskType`, `effectiveDuration` |
| `EventKitRepository` | Service | `fetchFocusBlocks(for: date)` |
| `StatItem` | Component | Wiederverwendbar |

## Implementation Details

### 1. ReviewMode Enum

```swift
enum ReviewMode: String, CaseIterable {
    case today = "Heute"
    case week = "Diese Woche"
}
```

### 2. DailyReviewView Erweiterung

```swift
struct DailyReviewView: View {
    @State private var reviewMode: ReviewMode = .today

    var body: some View {
        NavigationStack {
            ScrollView {
                // Segmented Picker
                Picker("Zeitraum", selection: $reviewMode) {
                    ForEach(ReviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on mode
                switch reviewMode {
                case .today:
                    dailyContent
                case .week:
                    weeklyContent
                }
            }
            .navigationTitle("Rückblick")
        }
    }
}
```

### 3. Weekly Stats Berechnung

```swift
private var weekBlocks: [FocusBlock] {
    // Mo-So der aktuellen Woche
    let calendar = Calendar.current
    let today = Date()
    guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
        return []
    }

    var allBlocks: [FocusBlock] = []
    for dayOffset in 0..<7 {
        if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
            allBlocks += (try? eventKitRepo.fetchFocusBlocks(for: date)) ?? []
        }
    }
    return allBlocks
}

private var categoryStats: [(category: String, minutes: Int, color: Color)] {
    // Gruppiere completed tasks nach taskType
    // Summiere effectiveDuration pro Kategorie
}
```

### 4. UI Struktur (Weekly Mode)

```
weeklyContent
├── weeklyStatsHeader
│   ├── Datum-Range (z.B. "20. - 26. Januar")
│   ├── Completion Ring (Gesamt-%)
│   └── Stats: Tasks | Blocks | Minuten
│
├── categoryChart
│   ├── income-Bar (Geld verdienen)
│   ├── maintenance-Bar (Schneeschaufeln)
│   ├── recharge-Bar (Energie aufladen)
│   ├── learning-Bar (Lernen)
│   └── giving_back-Bar (Weitergeben)
│
└── emptyState (wenn keine Blocks)
```

### 5. Category Bar Component

```swift
struct CategoryBar: View {
    let category: String
    let minutes: Int
    let maxMinutes: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(categoryName)
            Spacer()
            // Horizontal bar proportional to time
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * ratio)
            }
            Text("\(minutes) min")
        }
    }
}
```

### 6. Kategorie-Mapping

```swift
let categoryInfo: [String: (name: String, icon: String, color: Color)] = [
    "income": ("Geld verdienen", "dollarsign.circle", .green),
    "maintenance": ("Schneeschaufeln", "wrench.and.screwdriver", .orange),
    "recharge": ("Energie aufladen", "battery.100", .blue),
    "learning": ("Lernen", "book", .purple),
    "giving_back": ("Weitergeben", "gift", .pink)
]
```

## Test Plan

### UI Tests

```swift
// Erweitere DailyReviewUITests.swift

/// GIVEN: Rückblick view is open
/// WHEN: User sees the segmented picker
/// THEN: "Heute" and "Diese Woche" options should exist
func testSegmentedPickerExists()

/// GIVEN: Rückblick view is open
/// WHEN: User taps "Diese Woche"
/// THEN: Weekly stats should be displayed
func testWeeklyViewShown()

/// GIVEN: Weekly view is displayed
/// WHEN: No blocks exist this week
/// THEN: Should show empty state
func testWeeklyEmptyState()
```

## Acceptance Criteria

- [ ] Segmented Picker mit "Heute" | "Diese Woche"
- [ ] "Heute" zeigt bisherige Tages-Ansicht
- [ ] "Diese Woche" zeigt:
  - [ ] Wochen-Datum-Range
  - [ ] Gesamt-Statistik (Tasks, Blocks, Zeit)
  - [ ] Kategorie-Balken mit Zeit pro Kategorie
- [ ] Empty State wenn keine Blocks in der Woche
- [ ] UI Tests grün
