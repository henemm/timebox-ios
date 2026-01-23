---
entity_id: live-activity
type: feature
created: 2026-01-23
status: done
workflow: live-activity
version: "1.0"
tags: [sprint-4, lockscreen, dynamic-island, activitykit]
---

# Live Activity (Sprint 4)

## Approval

- [x] Approved for implementation (2026-01-23)

## Purpose

Zeigt den aktiven Focus Block auf dem Lock Screen und in der Dynamic Island an, damit der User den Timer-Countdown sehen kann ohne die App zu oeffnen.

## Scope

### Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Models/FocusBlockActivityAttributes.swift` | ActivityKit Datenmodell |
| `Sources/Services/LiveActivityManager.swift` | Activity Lifecycle Management |
| `FocusBloxWidgets/FocusBlockLiveActivity.swift` | Lock Screen + Dynamic Island UI |

### Zu aendernde Dateien

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` | Live Activity registrieren |
| `FocusBloxWidgets/Info.plist` | `NSSupportsLiveActivities = YES` |
| `Sources/Views/FocusLiveView.swift` | LiveActivityManager aufrufen |

### Geschaetzter Umfang

- **Neue LoC:** ~180
- **Geaenderte LoC:** ~20
- **Dateien total:** 6

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBlock` | Model | Block-Daten (Start, Ende, Tasks) |
| `FocusLiveView` | View | Integration Point fuer Activity Start/End |
| `ActivityKit` | Framework | Apple Live Activity API |
| `WidgetKit` | Framework | Lock Screen Widget UI |

## Implementation Details

### 1. FocusBlockActivityAttributes

```swift
import ActivityKit

struct FocusBlockActivityAttributes: ActivityAttributes {
    /// Statische Daten (aendern sich nicht waehrend Activity)
    let blockTitle: String
    let startDate: Date
    let endDate: Date
    let totalTaskCount: Int

    /// Dynamische Daten (koennen sich aendern)
    struct ContentState: Codable, Hashable {
        let currentTaskTitle: String?
        let completedCount: Int
    }
}
```

### 2. LiveActivityManager

```swift
import ActivityKit

@Observable
final class LiveActivityManager {
    private var currentActivity: Activity<FocusBlockActivityAttributes>?

    /// Startet Live Activity fuer einen Focus Block
    func startActivity(for block: FocusBlock, currentTask: String?) async throws

    /// Aktualisiert den aktuellen Task
    func updateActivity(currentTask: String?, completedCount: Int) async

    /// Beendet die Activity
    func endActivity() async
}
```

**Lifecycle:**
1. `FocusLiveView.onAppear` → `startActivity()` wenn Block aktiv
2. Task completed → `updateActivity()` mit neuem Task
3. Block endet → `endActivity()`

### 3. Lock Screen + Dynamic Island UI

**Compact View (Dynamic Island - minimal):**
```
[Icon] 23:45
```

**Minimal View (Dynamic Island - expanded edges):**
```
Leading: [Block Icon]
Trailing: 23:45
```

**Expanded View (Dynamic Island - tapped):**
```
┌─────────────────────────────┐
│ Focus Block                 │
│ "E-Mails beantworten"       │
│ ━━━━━━━━━━━━━━━━━━ 23:45   │
│ 2/5 Tasks                   │
└─────────────────────────────┘
```

**Lock Screen View:**
```
┌─────────────────────────────┐
│ 🎯 Focus Block        23:45 │
│ ─────────────────────────── │
│ E-Mails beantworten         │
│ 2/5 Tasks erledigt          │
└─────────────────────────────┘
```

### 4. Timer-Anzeige

Verwendet `Text(timerInterval:)` fuer automatischen Countdown:
```swift
Text(timerInterval: Date()...endDate, countsDown: true)
    .monospacedDigit()
```

**Vorteil:** Zaehlt automatisch ohne App-Updates.

## Expected Behavior

### Input
- Aktiver `FocusBlock` mit `startDate`, `endDate`, `taskIDs`
- Aktueller Task (erster nicht-erledigter)

### Output
- Live Activity auf Lock Screen sichtbar
- Dynamic Island zeigt Countdown
- Updates bei Task-Completion

### Side Effects
- Activity wird bei App-Termination automatisch beendet (iOS Verhalten)
- Maximal eine Activity gleichzeitig aktiv

## Test Plan

### UI Tests (TDD RED)

```swift
// FocusBloxUITests/LiveActivityUITests.swift

func testLiveActivityStartsWhenBlockActive() {
    // GIVEN: App is open, Focus Block is active
    // WHEN: FocusLiveView appears
    // THEN: Live Activity should be visible (check via Activity.activities)
}

func testLiveActivityUpdatesOnTaskCompletion() {
    // GIVEN: Live Activity is running with Task A
    // WHEN: User completes Task A
    // THEN: Activity shows next task (Task B)
}

func testLiveActivityEndsWhenBlockEnds() {
    // GIVEN: Live Activity is running
    // WHEN: Block end time is reached
    // THEN: Activity should end
}
```

### Unit Tests (TDD RED)

```swift
// FocusBloxTests/LiveActivityManagerTests.swift

func testStartActivityCreatesActivity() async {
    // GIVEN: LiveActivityManager, valid FocusBlock
    // WHEN: startActivity() called
    // THEN: currentActivity is not nil
}

func testUpdateActivityChangesState() async {
    // GIVEN: Active Live Activity
    // WHEN: updateActivity() with new task
    // THEN: Activity state reflects new task
}

func testEndActivityClearsActivity() async {
    // GIVEN: Active Live Activity
    // WHEN: endActivity() called
    // THEN: currentActivity is nil
}
```

**Hinweis:** Live Activity UI selbst ist schwer automatisiert zu testen. Unit Tests fokussieren auf Manager-Logik.

## Acceptance Criteria

- [ ] Live Activity erscheint automatisch wenn Focus Block aktiv wird
- [ ] Lock Screen zeigt: Block-Titel, aktuellen Task, Countdown Timer
- [ ] Dynamic Island zeigt: Countdown Timer (compact), Task + Timer (expanded)
- [ ] Activity aktualisiert sich wenn Task als erledigt markiert wird
- [ ] Activity verschwindet wenn Block endet
- [ ] Keine Activity wenn kein Block aktiv
- [ ] Build kompiliert ohne Errors
- [ ] Alle Unit Tests GRUEN
- [ ] UI Tests GRUEN (soweit testbar)

## Known Limitations

1. **Simulator:** Live Activity funktioniert nur auf echtem Device
2. **Max Duration:** iOS limitiert Activities auf 8h (kein Problem, Blocks sind kuerzer)
3. **Background Updates:** Ohne Push-Server keine Updates wenn App im Background - Timer laeuft aber automatisch via `Text(timerInterval:)`
4. **Quick Actions:** Keine Buttons auf Lock Screen in v1 (spaeter)

## Changelog

- 2026-01-23: Initial spec created
