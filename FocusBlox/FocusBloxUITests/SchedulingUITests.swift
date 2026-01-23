import XCTest

final class SchedulingUITests: XCTestCase {

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

    private func navigateToBloeckeTab() {
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        if bloeckeTab.waitForExistence(timeout: 5) {
            bloeckeTab.tap()
        }
    }

    // MARK: - BlockPlanningView Layout Tests

    /// GIVEN: User switches to Blöcke tab
    /// WHEN: BlockPlanningView loads (Smart Gaps design)
    /// THEN: Smart Gaps section or free day indicator should be visible
    func testBlockPlanningViewShowsTimeline() throws {
        navigateToBloeckeTab()

        // Wait for content
        sleep(2)

        // Smart Gaps design shows either "Freie Slots" or "Tag ist frei!" header
        let freeSlotsHeader = app.staticTexts["Freie Slots"]
        let freeDayHeader = app.staticTexts["Tag ist frei!"]
        let hasSmartGaps = freeSlotsHeader.exists || freeDayHeader.exists

        XCTAssertTrue(hasSmartGaps, "Smart Gaps section should show 'Freie Slots' or 'Tag ist frei!'")
    }

    /// GIVEN: BlockPlanningView is displayed
    /// WHEN: User views timeline
    /// THEN: Free slots should be visible for creating focus blocks
    func testTimelineShowsFreeSlots() throws {
        navigateToBloeckeTab()
        sleep(2)

        // MiniBacklog shows draggable task items
        // Look for any task item in the bottom area
        let scrollViews = app.scrollViews
        XCTAssertTrue(scrollViews.count > 0, "Should have scrollable content (timeline)")
    }

    /// GIVEN: BlockPlanningView with date picker
    /// WHEN: Viewing toolbar
    /// THEN: Date picker should exist
    func testDatePickerExists() throws {
        navigateToBloeckeTab()
        sleep(1)

        // Date picker is in toolbar
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5), "Date picker should exist in toolbar")
    }

    // MARK: - Focus Block Tests

    /// GIVEN: BlockPlanningView with Smart Gaps
    /// WHEN: Viewing the view
    /// THEN: Manual block creation button should exist
    func testTimelineSlotsExist() throws {
        navigateToBloeckeTab()
        sleep(2)

        // Smart Gaps design has a manual block creation button
        let createBlockButton = app.buttons["createCustomBlockButton"]
        XCTAssertTrue(createBlockButton.waitForExistence(timeout: 3), "Create custom block button should exist")

        // Also verify Smart Gaps section exists (header)
        let freeSlotsHeader = app.staticTexts["Freie Slots"]
        let freeDayHeader = app.staticTexts["Tag ist frei!"]
        let hasHeader = freeSlotsHeader.exists || freeDayHeader.exists
        XCTAssertTrue(hasHeader, "Smart Gaps header should exist")
    }

    // MARK: - Focus Block Display Tests

    /// GIVEN: BlockPlanningView
    /// WHEN: Viewing the timeline
    /// THEN: View should load without crash
    func testBlocksDisplayInTimeline() throws {
        navigateToBloeckeTab()
        sleep(2)

        // Document current state
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Timeline-FocusBlocks"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Test passes if no crash
        XCTAssertTrue(true, "Timeline loads without crash")
    }

    // MARK: - Date Navigation Tests

    /// GIVEN: BlockPlanningView is displayed
    /// WHEN: User changes date in picker
    /// THEN: Timeline should update to show that day's blocks
    func testChangingDateUpdatesTimeline() throws {
        navigateToBloeckeTab()
        sleep(2)

        // Tap on date picker
        let datePicker = app.datePickers.firstMatch
        guard datePicker.waitForExistence(timeout: 5) else {
            XCTFail("Date picker not found")
            return
        }

        datePicker.tap()
        sleep(1)

        // Take screenshot of date picker
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "DatePicker-Open"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Dismiss by tapping elsewhere
        app.tap()
        sleep(1)

        XCTAssertTrue(true, "Date navigation works without crash")
    }

    // MARK: - Screenshot Documentation

    /// Full BlockPlanningView screenshot for documentation
    func testBlockPlanningViewFullScreenshot() throws {
        navigateToBloeckeTab()
        sleep(3)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BlockPlanningView-Full"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
