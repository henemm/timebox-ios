---
entity_id: daily-review
type: feature
created: 2026-01-23
status: draft
workflow: daily-review
version: "1.0"
tags: [sprint-5, review, statistics]
---

# Daily Review (Tages-Rückblick)

- [ ] Approved for implementation

## Purpose

"Was habe ich heute alles geschafft?" - Neuer Tab zeigt Übersicht aller erledigten Tasks des Tages, gruppiert nach Focus Blocks.

## Scope

### Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Views/DailyReviewView.swift` | Haupt-View für Tages-Rückblick |
| `FocusBloxUITests/DailyReviewUITests.swift` | UI Tests |

### Zu ändernde Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/MainTabView.swift` | 5. Tab "Rückblick" hinzufügen |

### Geschätzter Umfang

- **Neue LoC:** ~150
- **Geänderte LoC:** ~10
- **Dateien total:** 3

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBlock` | Model | Block-Daten mit `completedTaskIDs` |
| `EventKitRepository` | Service | `fetchFocusBlocks(for: date)` |
| `PlanItem` | Model | Task-Details (Titel, Dauer) |
| `StatItem` | Component | Wiederverwendbar aus SprintReviewSheet |
| `ReviewTaskRow` | Component | Wiederverwendbar aus SprintReviewSheet |

## Implementation Details

### 1. MainTabView (Änderung)

```swift
// Neuer 5. Tab
DailyReviewView()
    .tabItem {
        Label("Rückblick", systemImage: "clock.arrow.circlepath")
    }
```

### 2. DailyReviewView (Neu)

```swift
struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var blocks: [FocusBlock] = []
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = false

    // Aggregierte Stats
    private var totalCompleted: Int { ... }
    private var totalPlanned: Int { ... }
    private var completionPercentage: Int { ... }

    var body: some View {
        NavigationStack {
            ScrollView {
                if blocks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        dailyStatsHeader
                        blocksSection
                    }
                }
            }
            .navigationTitle("Rückblick")
            .withSettingsToolbar()
        }
        .task { await loadData() }
    }
}
```

### 3. UI Struktur

```
NavigationStack
├── dailyStatsHeader
│   ├── Datum (z.B. "Heute, 23. Januar")
│   ├── Completion Ring (Gesamt-%)
│   └── Stats: Erledigt | Offen | Blocks
│
├── blocksSection (ForEach block)
│   ├── Block-Header (Titel, Zeit, %)
│   └── Erledigte Tasks (ReviewTaskRow)
│
└── emptyState (wenn keine Blocks)
    └── "Heute noch keine Focus Blocks"
```

## Test Plan

### UI Tests (TDD RED)

```swift
// DailyReviewUITests.swift

/// GIVEN: App is launched
/// WHEN: User taps Rückblick tab
/// THEN: DailyReviewView should open
func testRueckblickTabOpens()

/// GIVEN: No focus blocks today
/// WHEN: DailyReviewView loads
/// THEN: Should show empty state message
func testEmptyStateShown()

/// GIVEN: DailyReviewView is displayed
/// WHEN: Settings button is tapped
/// THEN: Settings should open
func testSettingsButtonWorks()
```

### Manuelle Tests

- [ ] Tab "Rückblick" erscheint in Tab-Bar
- [ ] Tages-Statistik zeigt korrekte Zahlen
- [ ] Blocks werden mit erledigten Tasks angezeigt
- [ ] Empty State bei keinen Blocks

## Acceptance Criteria

- [ ] Neuer Tab "Rückblick" in MainTabView
- [ ] Zeigt alle Focus Blocks des heutigen Tages
- [ ] Aggregierte Tages-Statistik (erledigt/geplant/%)
- [ ] Jeder Block zeigt seine erledigten Tasks
- [ ] Empty State wenn keine Blocks vorhanden
- [ ] Settings-Button funktioniert
- [ ] UI Tests grün
