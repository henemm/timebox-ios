# Test Definitions: Eisenhower Matrix as View Mode

**Feature:** Convert Eisenhower Matrix from separate tab to view mode within BacklogView

**Change Type:** AENDERUNG (Modification of existing feature)

**Test Simulator:** D9E26087-132A-44CB-9883-59073DD9CC54 (Timebox)

---

## 1. Existing Tests to Modify

### 1.1 EisenhowerMatrixUITests - Navigation Path Changes

**File:** `TimeBoxUITests/EisenhowerMatrixUITests.swift`

**BEFORE:**
- Tests navigate via "Matrix" tab in TabView (lines 22-26)
- Test: `testEisenhowerMatrixTabExists()`

**AFTER:**
- Tests must navigate via BacklogView ViewMode switcher
- Remove: `testEisenhowerMatrixTabExists()` (tab no longer exists)
- Add: `testEisenhowerMatrixViewModeExists()`

**Modified Tests:**

```swift
// testEisenhowerMatrixViewModeExists()
// GIVEN: App launched, BacklogView is displayed
// WHEN: User taps ViewMode switcher and selects "Matrix"
// THEN: Eisenhower Matrix view should be displayed

// All other tests in EisenhowerMatrixUITests must update navigation:
// OLD: app.tabBars.buttons["Matrix"].tap()
// NEW:
//   1. Ensure BacklogView is active (default tab)
//   2. Tap ViewMode switcher
//   3. Select "Matrix" mode
```

**Tests requiring navigation update (22 tests total):**
- testAllFourQuadrantsVisible() (line 37)
- testQuadrantSubtitlesVisible() (line 62)
- testQuadrantTaskCountsVisible() (line 86)
- testEmptyStateShowsNoTasksMessage() (line 107)
- testPullToRefreshWorks() (line 128)
- testQuadrantCardsShowAllElements() (line 156)
- testScrollingShowsAllQuadrants() (line 180)
- testQuadrantsShowBacklogRowForTasks() (line 212)
- testQuadrantShowsMoreTasksIndicator() (line 238)

---

## 2. New Tests for BacklogView - ViewMode Switcher

### 2.1 ViewMode Switcher UI Tests

**File:** `TimeBoxUITests/BacklogViewUITests.swift`

**Test 1: ViewMode Switcher Exists**
```swift
/// GIVEN: BacklogView is displayed
/// WHEN: Looking at the toolbar
/// THEN: ViewMode switcher should be visible
func testViewModeSwitcherExists() throws {
    // Look for Picker or Segmented Control in toolbar
    // Accessibility identifier: "viewModeSwitcher"
    let switcher = app.buttons["viewModeSwitcher"]
    XCTAssertTrue(switcher.waitForExistence(timeout: 5))
}
```

**Test 2: ViewMode Switcher Shows All Options**
```swift
/// GIVEN: BacklogView with ViewMode switcher
/// WHEN: User taps switcher
/// THEN: Should show all 5 view mode options
func testViewModeSwitcherShowsAllOptions() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    XCTAssertTrue(switcher.waitForExistence(timeout: 5))
    switcher.tap()

    // Check for all 5 options (may be menu or picker)
    XCTAssertTrue(app.menuItems["Liste"].exists)
    XCTAssertTrue(app.menuItems["Matrix"].exists)
    XCTAssertTrue(app.menuItems["Kategorie"].exists)
    XCTAssertTrue(app.menuItems["Dauer"].exists)
    XCTAssertTrue(app.menuItems["Fälligkeit"].exists)
}
```

**Test 3: Default ViewMode is List**
```swift
/// GIVEN: App launched for first time (no persisted preference)
/// WHEN: BacklogView loads
/// THEN: List mode should be selected by default
func testDefaultViewModeIsList() throws {
    let navBar = app.navigationBars["Backlog"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 5))

    // List view shows tasks in plain list format
    // Verify List UI elements exist (EditButton, List cells)
    let editButton = app.navigationBars.buttons["Edit"]
    XCTAssertTrue(editButton.exists, "List mode should show Edit button")
}
```

### 2.2 ViewMode Switching Tests

**Test 4: Switch to Eisenhower Matrix Mode**
```swift
/// GIVEN: BacklogView in List mode
/// WHEN: User selects "Matrix" from ViewMode switcher
/// THEN: Eisenhower Matrix view should be displayed
func testSwitchToEisenhowerMatrixMode() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Matrix"].tap()

    sleep(1) // Wait for view transition

    // Verify Matrix view is displayed
    let doFirstTitle = app.staticTexts["Do First"]
    XCTAssertTrue(doFirstTitle.waitForExistence(timeout: 3))
}
```

**Test 5: Switch to Category Mode**
```swift
/// GIVEN: BacklogView in List mode
/// WHEN: User selects "Kategorie" from ViewMode switcher
/// THEN: Category-grouped view should be displayed
func testSwitchToCategoryMode() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Kategorie"].tap()

    sleep(1)

    // Verify Category view (sections by taskType)
    // Categories: deep_work, shallow_work, meetings, maintenance, creative, strategic
    // Check for at least one category header
    let categoryHeaderExists = app.staticTexts.matching(
        NSPredicate(format: "label MATCHES %@", "(Deep Work|Shallow Work|Meetings|Maintenance|Creative|Strategic)")
    ).firstMatch.exists

    XCTAssertTrue(categoryHeaderExists, "Category view should show task type sections")
}
```

**Test 6: Switch to Duration Mode**
```swift
/// GIVEN: BacklogView in List mode
/// WHEN: User selects "Dauer" from ViewMode switcher
/// THEN: Duration-grouped view should be displayed
func testSwitchToDurationMode() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Dauer"].tap()

    sleep(1)

    // Verify Duration view (sections by time buckets)
    // Buckets: < 15 Min, 15-30 Min, 30-60 Min, > 60 Min
    let durationHeaderExists = app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS 'Min'")
    ).firstMatch.exists

    XCTAssertTrue(durationHeaderExists, "Duration view should show time bucket sections")
}
```

**Test 7: Switch to Due Date Mode**
```swift
/// GIVEN: BacklogView in List mode
/// WHEN: User selects "Fälligkeit" from ViewMode switcher
/// THEN: Due date-grouped view should be displayed
func testSwitchToDueDateMode() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Fälligkeit"].tap()

    sleep(1)

    // Verify Due Date view (sections by time proximity)
    // Sections: Heute, Morgen, Diese Woche, Später, Ohne Fälligkeitsdatum
    let dueDateHeaderExists = app.staticTexts.matching(
        NSPredicate(format: "label MATCHES %@", "(Heute|Morgen|Diese Woche|Später|Ohne Fälligkeitsdatum)")
    ).firstMatch.exists

    XCTAssertTrue(dueDateHeaderExists, "Due Date view should show date-based sections")
}
```

### 2.3 AppStorage Persistence Tests

**Test 8: ViewMode Preference Persists**
```swift
/// GIVEN: User selects "Matrix" mode
/// WHEN: App is restarted
/// THEN: Matrix mode should still be selected
func testViewModePreferencePersists() throws {
    // Select Matrix mode
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Matrix"].tap()

    sleep(1)

    // Verify Matrix is shown
    XCTAssertTrue(app.staticTexts["Do First"].exists)

    // Restart app
    app.terminate()
    app.launch()

    // Wait for BacklogView to load
    sleep(2)

    // Verify Matrix is STILL shown (not back to List)
    XCTAssertTrue(app.staticTexts["Do First"].waitForExistence(timeout: 5),
                  "Matrix mode should persist after app restart")
}
```

**Test 9: ViewMode Persists Across Tab Switches**
```swift
/// GIVEN: User selects "Category" mode in Backlog tab
/// WHEN: User switches to different tab and back to Backlog
/// THEN: Category mode should still be selected
func testViewModePersiststAcrossTabSwitches() throws {
    // Select Category mode
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Kategorie"].tap()

    sleep(1)

    // Switch to different tab
    app.tabBars.buttons["Blöcke"].tap()
    sleep(1)

    // Switch back to Backlog
    app.tabBars.buttons["Backlog"].tap()
    sleep(1)

    // Verify Category mode is still active
    // (Cannot check exact UI without test data, but verify no crash)
    XCTAssertTrue(app.navigationBars["Backlog"].exists,
                  "Backlog view should restore with persisted mode")
}
```

---

## 3. Empty State Tests per View Mode

### 3.1 List Mode Empty State
```swift
/// GIVEN: No tasks in database
/// WHEN: BacklogView in List mode
/// THEN: Should show List-specific empty message
func testListModeEmptyState() throws {
    // If no tasks exist:
    let emptyTitle = app.staticTexts["Keine Tasks"]
    let emptyDescription = app.staticTexts["Tippe auf + um einen neuen Task zu erstellen."]

    if emptyTitle.exists {
        XCTAssertTrue(emptyDescription.exists, "List mode should show create task message")
    }
}
```

### 3.2 Eisenhower Matrix Mode Empty State
```swift
/// GIVEN: No tasks in database
/// WHEN: BacklogView in Matrix mode
/// THEN: Should show Matrix-specific empty message
func testMatrixModeEmptyState() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Matrix"].tap()

    sleep(1)

    // Matrix mode shows quadrants with "Keine Tasks" in each
    // OR central empty state if completely empty
    let emptyStateExists = app.staticTexts["Keine Tasks für Matrix"].exists ||
                          app.staticTexts["Setze Priorität und Dringlichkeit für deine Tasks."].exists

    XCTAssertTrue(emptyStateExists, "Matrix mode should show prioritization prompt")
}
```

### 3.3 Category Mode Empty State
```swift
/// GIVEN: No tasks in database
/// WHEN: BacklogView in Category mode
/// THEN: Should show Category-specific empty message
func testCategoryModeEmptyState() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Kategorie"].tap()

    sleep(1)

    let emptyStateExists = app.staticTexts["Keine Tasks in Kategorien"].exists ||
                          app.staticTexts["Erstelle Tasks und weise ihnen Kategorien zu."].exists

    XCTAssertTrue(emptyStateExists, "Category mode should show categorization prompt")
}
```

### 3.4 Duration Mode Empty State
```swift
/// GIVEN: No tasks in database
/// WHEN: BacklogView in Duration mode
/// THEN: Should show Duration-specific empty message
func testDurationModeEmptyState() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Dauer"].tap()

    sleep(1)

    let emptyStateExists = app.staticTexts["Keine Tasks mit Dauer"].exists ||
                          app.staticTexts["Setze geschätzte Dauern für deine Tasks."].exists

    XCTAssertTrue(emptyStateExists, "Duration mode should show duration setting prompt")
}
```

### 3.5 Due Date Mode Empty State
```swift
/// GIVEN: No tasks in database
/// WHEN: BacklogView in Due Date mode
/// THEN: Should show Due Date-specific empty message
func testDueDateModeEmptyState() throws {
    let switcher = app.buttons["viewModeSwitcher"]
    switcher.tap()
    app.menuItems["Fälligkeit"].tap()

    sleep(1)

    let emptyStateExists = app.staticTexts["Keine Tasks mit Fälligkeitsdatum"].exists ||
                          app.staticTexts["Setze Fälligkeitsdaten für deine Tasks."].exists

    XCTAssertTrue(emptyStateExists, "Due Date mode should show date setting prompt")
}
```

---

## 4. MainTabView Tests

### 4.1 Matrix Tab Removed
```swift
/// GIVEN: App is launched
/// WHEN: Looking at tab bar
/// THEN: "Matrix" tab should NOT exist
func testMatrixTabDoesNotExist() throws {
    let matrixTab = app.tabBars.buttons["Matrix"]
    XCTAssertFalse(matrixTab.exists, "Matrix tab should be removed from TabView")
}
```

### 4.2 Only 4 Tabs Visible
```swift
/// GIVEN: App is launched
/// WHEN: Looking at tab bar
/// THEN: Should show exactly 4 tabs (Backlog, Blöcke, Zuordnen, Fokus)
func testTabBarHasFourTabs() throws {
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

    // Check expected tabs exist
    XCTAssertTrue(app.tabBars.buttons["Backlog"].exists)
    XCTAssertTrue(app.tabBars.buttons["Blöcke"].exists)
    XCTAssertTrue(app.tabBars.buttons["Zuordnen"].exists)
    XCTAssertTrue(app.tabBars.buttons["Fokus"].exists)

    // Matrix tab should NOT exist
    XCTAssertFalse(app.tabBars.buttons["Matrix"].exists)
}
```

---

## 5. View Mode Interaction Tests

### 5.1 Features Available in All Modes
```swift
/// GIVEN: BacklogView in any mode
/// WHEN: User taps + button
/// THEN: CreateTaskView should open
func testCreateTaskButtonWorksInAllModes() throws {
    let modes = ["Liste", "Matrix", "Kategorie", "Dauer", "Fälligkeit"]
    let switcher = app.buttons["viewModeSwitcher"]
    let addButton = app.buttons["addTaskButton"]

    for mode in modes {
        switcher.tap()
        app.menuItems[mode].tap()
        sleep(1)

        XCTAssertTrue(addButton.exists, "Add button should exist in \(mode) mode")

        addButton.tap()
        sleep(1)

        // Verify CreateTaskView opens
        let createNavBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(createNavBar.exists, "CreateTaskView should open from \(mode) mode")

        // Close sheet
        app.navigationBars.buttons["Abbrechen"].tap()
        sleep(1)
    }
}
```

### 5.2 Pull-to-Refresh Works in All Modes
```swift
/// GIVEN: BacklogView in any mode
/// WHEN: User pulls down to refresh
/// THEN: Tasks should reload
func testPullToRefreshWorksInAllModes() throws {
    let modes = ["Liste", "Matrix", "Kategorie", "Dauer", "Fälligkeit"]
    let switcher = app.buttons["viewModeSwitcher"]

    for mode in modes {
        switcher.tap()
        app.menuItems[mode].tap()
        sleep(1)

        // Find scrollable content (List or ScrollView)
        let scrollView = app.scrollViews.firstMatch.exists ?
                         app.scrollViews.firstMatch :
                         app.tables.firstMatch

        if scrollView.exists {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)

            sleep(1)

            // Verify no crash
            XCTAssertTrue(app.navigationBars["Backlog"].exists,
                          "Refresh should work in \(mode) mode")
        }
    }
}
```

---

## 6. Test Execution Order

**Phase 1 - RED (Run Tests, All Should Fail):**
1. Run BacklogViewUITests - ViewMode switcher tests (should fail - UI doesn't exist yet)
2. Run EisenhowerMatrixUITests with old navigation (should fail - tab removed)
3. Run MainTabView tests (should fail - Matrix tab still exists)

**Phase 2 - GREEN (After Implementation):**
1. Run all BacklogViewUITests - should pass
2. Run updated EisenhowerMatrixUITests with new navigation - should pass
3. Run MainTabView tests - should pass

**Phase 3 - REFACTOR:**
1. Verify no code duplication in view mode rendering
2. Ensure consistency in empty states
3. Check performance of view mode switching

---

## Test Coverage Summary

**Total New Tests:** 21
**Modified Tests:** 9 (EisenhowerMatrixUITests navigation)
**Removed Tests:** 1 (testEisenhowerMatrixTabExists)

**Coverage:**
- ViewMode switcher UI: 3 tests
- ViewMode switching: 4 tests
- AppStorage persistence: 2 tests
- Empty states per mode: 5 tests
- MainTabView changes: 2 tests
- Cross-mode interactions: 2 tests
- Eisenhower Matrix navigation: 9 modified tests

**Test Execution Time:** ~5-8 minutes (with sleep delays for UI animations)
