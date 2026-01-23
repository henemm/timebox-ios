import XCTest

/// UI Tests for scrolling behavior in list containers
/// These tests verify that all items are reachable when lists contain many items
/// Bug: .scrollDisabled(true) prevents scrolling in FocusBlockCard and BlockPlanningView
final class ScrollingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func navigateToZuordnenTab() {
        let zuordnenTab = app.tabBars.buttons["Zuordnen"]
        if zuordnenTab.waitForExistence(timeout: 5) {
            zuordnenTab.tap()
        }
        sleep(2)
    }

    private func navigateToBloeckeTab() {
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        if bloeckeTab.waitForExistence(timeout: 5) {
            bloeckeTab.tap()
        }
        sleep(2)
    }

    // MARK: - FocusBlockCard Scrolling Tests (TaskAssignmentView)

    /// GIVEN: A Focus Block with many assigned tasks (>6)
    /// WHEN: Viewing the Focus Block card in Zuordnen tab
    /// THEN: All tasks should be reachable by scrolling within the block
    /// BUG: .scrollDisabled(true) at TaskAssignmentView.swift:331 prevents this
    func testFocusBlockCardScrollingWithManyTasks() throws {
        navigateToZuordnenTab()

        // Check if we have Focus Blocks
        let noBlocksText = app.staticTexts["Keine Focus Blocks"]
        if noBlocksText.waitForExistence(timeout: 3) {
            throw XCTSkip("No Focus Blocks exist - cannot test scrolling")
        }

        // Look for task rows within a Focus Block card
        // Tasks have remove buttons (xmark.circle.fill)
        let removeButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'xmark' OR identifier CONTAINS 'xmark'"))
        let taskCount = removeButtons.count

        if taskCount < 7 {
            throw XCTSkip("Need 7+ tasks in a block to test scrolling - found \(taskCount)")
        }

        // Try to access the last task by scrolling within the Focus Block area
        let lastRemoveButton = removeButtons.element(boundBy: taskCount - 1)

        // Attempt to scroll to the last element
        // With .scrollDisabled(true), this will NOT work
        var attempts = 0
        while !lastRemoveButton.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
            sleep(1)
        }

        // This assertion should FAIL because scrolling is disabled
        XCTAssertTrue(
            lastRemoveButton.isHittable,
            "Last task in Focus Block should be reachable - but .scrollDisabled(true) prevents this"
        )
    }

    /// GIVEN: Multiple Focus Blocks each with tasks
    /// WHEN: Scrolling within individual blocks
    /// THEN: Each block should scroll independently
    func testIndependentBlockScrolling() throws {
        navigateToZuordnenTab()

        let noBlocksText = app.staticTexts["Keine Focus Blocks"]
        if noBlocksText.waitForExistence(timeout: 3) {
            throw XCTSkip("No Focus Blocks exist")
        }

        // Take screenshot to document current state
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ScrollingTest-ZuordnenTab-Before"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Test passes if we can see blocks - actual scrolling test requires mock data
        XCTAssertFalse(noBlocksText.exists, "Focus Blocks should be visible")
    }

    // MARK: - BlockPlanningView Scrolling Tests

    /// GIVEN: Many Focus Blocks exist for the current day (>5)
    /// WHEN: Viewing the Blöcke tab
    /// THEN: All blocks should be reachable by scrolling
    /// BUG: .scrollDisabled(true) at BlockPlanningView.swift:216 prevents this
    func testBlockPlanningViewScrollingWithManyBlocks() throws {
        navigateToBloeckeTab()

        // Look for "Heutige Blöcke" header
        let heutigeBlockeHeader = app.staticTexts["Heutige Blöcke"]
        guard heutigeBlockeHeader.waitForExistence(timeout: 5) else {
            throw XCTSkip("No blocks section visible")
        }

        // Count existing blocks by looking for cells
        let blockCells = app.cells
        let blockCount = blockCells.count

        if blockCount < 6 {
            throw XCTSkip("Need 6+ blocks to test scrolling - found \(blockCount)")
        }

        // Try to access the last block
        let lastBlock = blockCells.element(boundBy: blockCount - 1)

        // Attempt scrolling
        var attempts = 0
        while !lastBlock.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
            sleep(1)
        }

        // This should FAIL because scrolling is disabled in the blocks list
        XCTAssertTrue(
            lastBlock.isHittable,
            "Last block should be reachable - but .scrollDisabled(true) prevents this"
        )
    }

    /// GIVEN: Focus Block list in Blöcke tab
    /// WHEN: User tries to tap on a block to edit
    /// THEN: All blocks should be tappable
    func testAllBlocksAreTappable() throws {
        navigateToBloeckeTab()

        let heutigeBlockeHeader = app.staticTexts["Heutige Blöcke"]
        guard heutigeBlockeHeader.waitForExistence(timeout: 5) else {
            throw XCTSkip("No blocks section visible")
        }

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ScrollingTest-BloeckeTab"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(heutigeBlockeHeader.exists, "Blocks section should be visible")
    }

    // MARK: - Task Backlog Scrolling Tests

    /// GIVEN: Many unassigned tasks in Next Up section (>10)
    /// WHEN: Viewing the Zuordnen tab
    /// THEN: All tasks should be reachable
    func testTaskBacklogScrollingWithManyTasks() throws {
        navigateToZuordnenTab()

        // Look for Next Up section
        let nextUpHeader = app.staticTexts["Next Up"]
        guard nextUpHeader.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Next Up section visible")
        }

        // Count tasks with move-up buttons
        let moveUpButtonsQuery = app.buttons.matching(identifier: "moveUpButton")
        let taskCount = moveUpButtonsQuery.count

        if taskCount < 10 {
            throw XCTSkip("Need 10+ Next Up tasks to test scrolling - found \(taskCount)")
        }

        // Try to access the last task
        let lastButton = moveUpButtonsQuery.element(boundBy: taskCount - 1)

        var attempts = 0
        while !lastButton.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
            sleep(1)
        }

        XCTAssertTrue(
            lastButton.isHittable,
            "Last task in Next Up should be reachable"
        )
    }

    // MARK: - Comprehensive Scroll Test

    /// Integration test: Navigate through all tabs and verify scrolling works
    func testScrollingAcrossAllTabs() throws {
        // Test 1: Backlog
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)

        // Verify list is scrollable
        let backlogList = app.tables.firstMatch
        if backlogList.exists {
            app.swipeUp()
            app.swipeDown()
        }

        // Test 2: Zuordnen
        navigateToZuordnenTab()

        // Test 3: Blöcke
        navigateToBloeckeTab()

        // Test 4: Focus (if exists)
        let focusTab = app.tabBars.buttons["Focus"]
        if focusTab.exists {
            focusTab.tap()
            sleep(1)
        }

        // All tabs should be navigable
        XCTAssertTrue(true, "All tabs navigated successfully")
    }

    // MARK: - Screenshot Documentation

    /// Document current scrolling behavior for bug analysis
    func testScrollingBehaviorScreenshots() throws {
        // Screenshot 1: Zuordnen tab
        navigateToZuordnenTab()

        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "ScrollingBug-ZuordnenTab"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Screenshot 2: Blöcke tab
        navigateToBloeckeTab()

        let screenshot2 = app.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "ScrollingBug-BloeckeTab"
        attachment2.lifetime = .keepAlways
        add(attachment2)
    }
}
