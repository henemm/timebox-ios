# Tests: Monster Coach Phase 3b — Smart Notifications

> Erstellt: 2026-03-12
> Status: Zur Freigabe
> Bezug: `proposal.md`

---

## Uebersicht

| Test-Typ | Anzahl | Ziel-File |
|----------|--------|-----------|
| Unit Tests | 22 | `FocusBloxTests/IntentionEvaluationServiceTests.swift` (neu) |
| Unit Tests | 8 | `FocusBloxTests/NotificationDailyNudgeTests.swift` (neu) |
| UI Tests | 5 | `FocusBloxUITests/CoachNotificationSettingsUITests.swift` (neu) |

---

## Unit Tests: IntentionEvaluationServiceTests

### isFulfilled — Survival

```swift
func test_isFulfilled_survival_alwaysTrue() {
    // Arrangement: keine Tasks, keine Blocks
    // Act: isFulfilled(intention: .survival, tasks: [], focusBlocks: [])
    // Assert: true
}
```

### isFulfilled — BHAG

```swift
func test_isFulfilled_bhag_whenImportance3TaskCompletedToday_returnsTrue() {
    // Arrangement: LocalTask mit importance=3, isCompleted=true, completedAt=heute
    // Act: isFulfilled(intention: .bhag, tasks: [task], focusBlocks: [])
    // Assert: true
}

func test_isFulfilled_bhag_whenImportance3TaskCompletedYesterday_returnsFalse() {
    // Arrangement: LocalTask mit importance=3, isCompleted=true, completedAt=gestern
    // Act: isFulfilled(intention: .bhag, tasks: [task], focusBlocks: [])
    // Assert: false
}

func test_isFulfilled_bhag_whenNoImportance3Task_returnsFalse() {
    // Arrangement: LocalTask mit importance=2, isCompleted=true, completedAt=heute
    // Act: isFulfilled(intention: .bhag, tasks: [task], focusBlocks: [])
    // Assert: false
}
```

### isFulfilled — Fokus

```swift
func test_isFulfilled_fokus_whenFocusBlockExistsToday_returnsTrue() {
    // Arrangement: FocusBlock mit startDate=heute, taskIDs=[id1], completedTaskIDs=[]
    // Act: isFulfilled(intention: .fokus, tasks: [], focusBlocks: [block])
    // Assert: true
}

func test_isFulfilled_fokus_whenNoFocusBlock_returnsFalse() {
    // Arrangement: leere focusBlocks
    // Act: isFulfilled(intention: .fokus, tasks: [], focusBlocks: [])
    // Assert: false
}
```

### isFulfilled — Growth

```swift
func test_isFulfilled_growth_whenLearningTaskCompletedToday_returnsTrue() {
    // Arrangement: LocalTask mit taskType="learning", isCompleted=true, completedAt=heute
    // Act: isFulfilled(intention: .growth, tasks: [task], focusBlocks: [])
    // Assert: true
}

func test_isFulfilled_growth_whenNoLearningTask_returnsFalse() {
    // Arrangement: LocalTask mit taskType="income", isCompleted=true, completedAt=heute
    // Act: isFulfilled(intention: .growth, tasks: [task], focusBlocks: [])
    // Assert: false
}
```

### isFulfilled — Connection

```swift
func test_isFulfilled_connection_whenGivingBackTaskCompletedToday_returnsTrue() {
    // Arrangement: LocalTask mit taskType="giving_back", isCompleted=true, completedAt=heute
    // Act: isFulfilled(intention: .connection, tasks: [task], focusBlocks: [])
    // Assert: true
}

func test_isFulfilled_connection_whenNoGivingBackTask_returnsFalse() {
    // Act: isFulfilled(intention: .connection, tasks: [], focusBlocks: [])
    // Assert: false
}
```

### isFulfilled — Balance

```swift
func test_isFulfilled_balance_whenThreeCategoriesCompletedToday_returnsTrue() {
    // Arrangement: 3 Tasks mit taskType=["income", "learning", "giving_back"], alle heute erledigt
    // Act: isFulfilled(intention: .balance, tasks: tasks, focusBlocks: [])
    // Assert: true
}

func test_isFulfilled_balance_whenOnlyTwoCategories_returnsFalse() {
    // Arrangement: 2 Tasks mit taskType=["income", "income"], heute erledigt
    // Act: isFulfilled(intention: .balance, tasks: tasks, focusBlocks: [])
    // Assert: false
}
```

### detectGap — Survival

```swift
func test_detectGap_survival_returnsNil() {
    // Act: detectGap(intention: .survival, tasks: [], focusBlocks: [])
    // Assert: nil (Survival braucht nie eine Notification)
}
```

### detectGap — BHAG

```swift
func test_detectGap_bhag_whenNoFocusBlockWithBhagTask_returnsNoBhagBlock() {
    // Arrangement: Kein Focus Block, morgens (9:00 Uhr)
    // Act: detectGap(intention: .bhag, tasks: [], focusBlocks: [], now: morning)
    // Assert: .noBhagBlockCreated
}

func test_detectGap_bhag_whenAfternoonAndBhagNotDone_returnsBhagNotStarted() {
    // Arrangement: FocusBlock existiert (z.B. mit normalem Task), aber kein importance=3 Task erledigt
    // now = 14:00 Uhr
    // Act: detectGap(intention: .bhag, tasks: [normalTask], focusBlocks: [block], now: afternoon)
    // Assert: .bhagTaskNotStarted
}

func test_detectGap_bhag_whenBhagTaskDone_returnsNil() {
    // Arrangement: Task mit importance=3 heute erledigt
    // Act: detectGap(intention: .bhag, tasks: [bhagTask], focusBlocks: [], now: now)
    // Assert: nil
}
```

### detectGap — Fokus

```swift
func test_detectGap_fokus_whenNoFocusBlock_returnsNoFocusBlockPlanned() {
    // Arrangement: Keine Focus Blocks heute
    // Act: detectGap(intention: .fokus, tasks: [], focusBlocks: [])
    // Assert: .noFocusBlockPlanned
}

func test_detectGap_fokus_whenTasksCompletedOutsideBlocks_returnsTasksOutsideBlocks() {
    // Arrangement: FocusBlock existiert, aber ein Task ist erledigt der NICHT in einem Block ist
    // (assignedFocusBlockID == nil && isCompleted && completedAt == heute)
    // Act: detectGap(intention: .fokus, tasks: [taskOutsideBlock, taskInBlock], focusBlocks: [block])
    // Assert: .tasksOutsideBlocks
}

func test_detectGap_fokus_whenFulfilledNoGap_returnsNil() {
    // Arrangement: Block existiert, alle erledigten Tasks sind in Blocks
    // Act: detectGap(intention: .fokus, tasks: tasksAllInBlocks, focusBlocks: [block])
    // Assert: nil
}
```

### completedToday Hilfsfunktion

```swift
func test_completedToday_filtersByCompletedAtDate() {
    // Arrangement: task1.completedAt = heute, task2.completedAt = gestern, task3.isCompleted = false
    // Act: completedToday([task1, task2, task3])
    // Assert: [task1]
}
```

---

## Unit Tests: NotificationDailyNudgeTests

### buildDailyNudgeRequests

```swift
func test_buildDailyNudgeRequests_survival_returnsEmpty() {
    // Act: buildDailyNudgeRequests(intention: .survival, gap: .noBhagBlockCreated, ...)
    // Assert: requests.isEmpty
}

func test_buildDailyNudgeRequests_maxCount2_returnsTwoRequests() {
    // Arrangement: windowStart = 10:00 heute, windowEnd = 18:00 heute, now = 08:00 heute
    // Act: buildDailyNudgeRequests(intention: .bhag, gap: .noBhagBlockCreated, ..., maxCount: 2)
    // Assert: requests.count == 2
}

func test_buildDailyNudgeRequests_fireDatesAreWithinWindow() {
    // Arrangement: windowStart = 10:00, windowEnd = 18:00, maxCount = 3, now = 08:00
    // Act: buildDailyNudgeRequests(...)
    // Assert: alle FireDates >= 10:00 && <= 18:00
}

func test_buildDailyNudgeRequests_whenWindowAlreadyPast_returnsEmpty() {
    // Arrangement: windowEnd = 09:00, now = 20:00 (Fenster bereits vorbei)
    // Act: buildDailyNudgeRequests(...)
    // Assert: requests.isEmpty
}

func test_buildDailyNudgeRequests_bhagNoBhagBlock_hasCorrectBodyText() {
    // Arrangement: intention = .bhag, gap = .noBhagBlockCreated
    // Act: buildDailyNudgeRequests(...)
    // Assert: requests[0].content.body == "Du wolltest das grosse Ding anpacken. Wann legst du los?"
}

func test_buildDailyNudgeRequests_identifiersHaveCorrectPrefix() {
    // Act: buildDailyNudgeRequests(maxCount: 2, ...)
    // Assert: requests[0].identifier == "coach-nudge-0", requests[1].identifier == "coach-nudge-1"
}

func test_buildDailyNudgeRequests_maxCount1_returnsOneRequest() {
    // Act: buildDailyNudgeRequests(maxCount: 1, ...)
    // Assert: requests.count == 1
}

func test_buildDailyNudgeRequests_fireDatesAreEvenlyDistributed() {
    // Arrangement: windowStart = 10:00, windowEnd = 18:00, maxCount = 3
    // 8h Fenster / 3 = ~2h40min Abstand
    // Assert: Abstand zwischen requests[0] und requests[1] ~== Abstand zwischen requests[1] und requests[2]
    // Toleranz: +/- 60 Sekunden
}
```

---

## UI Tests: CoachNotificationSettingsUITests

Datei: `FocusBloxUITests/CoachNotificationSettingsUITests.swift`

**Voraussetzung:** SettingsView muss geoeffnet sein, coachModeEnabled = true.

```swift
func test_coachNotificationSettings_areHiddenWhenCoachModeOff() {
    // Arrangement: coachModeEnabled = false
    // Assert: Element mit ID "coachDailyNudgesToggle" existiert NICHT
}

func test_coachDailyNudgesToggle_isVisibleWhenCoachModeOn() {
    // Arrangement: coachModeEnabled = true
    // Assert: Element "coachDailyNudgesToggle" exists && isHittable
}

func test_coachNudgeSettings_areHiddenWhenNudgesDisabled() {
    // Arrangement: coachModeEnabled = true, coachDailyNudgesEnabled = false
    // Assert: "coachNudgesMaxCountPicker" existiert NICHT
    // Assert: "coachNudgeWindowStartPicker" existiert NICHT
    // Assert: "coachNudgeWindowEndPicker" existiert NICHT
}

func test_coachNudgeSettings_areVisibleWhenNudgesEnabled() {
    // Arrangement: coachModeEnabled = true, coachDailyNudgesEnabled = true
    // Assert: "coachNudgesMaxCountPicker" exists
    // Assert: "coachNudgeWindowStartPicker" exists
    // Assert: "coachNudgeWindowEndPicker" exists
}

func test_coachNudgesMaxCountPicker_hasThreeOptions() {
    // Arrangement: coachModeEnabled = true, coachDailyNudgesEnabled = true
    // Act: Picker oeffnen
    // Assert: Optionen "1", "2", "3" sind vorhanden
}
```

---

## Accessibility Identifiers (neu)

Diese IDs muessen in `SettingsView.swift` gesetzt werden:

| Element | Identifier |
|---------|-----------|
| Toggle "Tages-Erinnerungen" | `"coachDailyNudgesToggle"` |
| Picker "Max. Erinnerungen" | `"coachNudgesMaxCountPicker"` |
| DatePicker "Von" | `"coachNudgeWindowStartPicker"` |
| DatePicker "Bis" | `"coachNudgeWindowEndPicker"` |

---

## TDD-Reihenfolge

1. `IntentionEvaluationServiceTests` schreiben (RED) — Service existiert noch nicht
2. `NotificationDailyNudgeTests` schreiben (RED) — Build-Funktion existiert noch nicht
3. `CoachNotificationSettingsUITests` schreiben (RED) — neue Controls existieren noch nicht
4. `IntentionEvaluationService.swift` implementieren → Unit Tests GREEN
5. `NotificationService` Daily Nudges MARK-Block implementieren → Unit Tests GREEN
6. `AppSettings` + `SettingsView` implementieren → UI Tests GREEN
7. `MorningIntentionView` + `FocusBloxApp` Foreground-Check implementieren
8. Alle Tests erneut durchlaufen → alles GREEN
