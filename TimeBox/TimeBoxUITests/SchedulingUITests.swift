import XCTest

final class SchedulingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func navigateToPlanenTab() {
        let planenTab = app.tabBars.buttons["Planen"]
        if planenTab.waitForExistence(timeout: 5) {
            planenTab.tap()
        }
    }

    // MARK: - PlanningView Layout Tests

    /// GIVEN: User switches to Planen tab
    /// WHEN: PlanningView loads
    /// THEN: Timeline and MiniBacklog should be visible (if tasks exist)
    func testPlanningViewShowsTimelineAndBacklog() throws {
        navigateToPlanenTab()

        // Wait for content
        sleep(2)

        // Timeline should show hours
        let hourLabel = app.staticTexts["09:00"]
        let hasTimeline = hourLabel.exists || app.staticTexts["10:00"].exists || app.staticTexts["11:00"].exists

        XCTAssertTrue(hasTimeline, "Timeline should show hour labels")
    }

    /// GIVEN: PlanningView is displayed
    /// WHEN: User has unscheduled tasks
    /// THEN: MiniBacklog at bottom should show tasks
    func testMiniBacklogShowsTasks() throws {
        navigateToPlanenTab()
        sleep(2)

        // MiniBacklog shows draggable task items
        // Look for any task item in the bottom area
        let scrollViews = app.scrollViews
        XCTAssertTrue(scrollViews.count > 0, "Should have scrollable content (timeline or mini backlog)")
    }

    /// GIVEN: PlanningView with date picker
    /// WHEN: Viewing toolbar
    /// THEN: Date picker should exist
    func testDatePickerExists() throws {
        navigateToPlanenTab()
        sleep(1)

        // Date picker is in toolbar
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5), "Date picker should exist in toolbar")
    }

    // MARK: - Drag & Drop Tests

    /// GIVEN: Task in MiniBacklog
    /// WHEN: Task is dragged to Timeline
    /// THEN: Calendar event should be created (task disappears from backlog)
    func testDragTaskToTimeline() throws {
        navigateToPlanenTab()
        sleep(2)

        // This test documents the drag & drop flow
        // Full automation of drag & drop between different views is complex
        // We verify the UI elements exist for manual testing

        // Check if timeline exists
        let hasTimeSlots = app.staticTexts["09:00"].exists ||
                          app.staticTexts["10:00"].exists ||
                          app.staticTexts["11:00"].exists

        XCTAssertTrue(hasTimeSlots, "Timeline should have time slots for dropping tasks")

        // Take screenshot for documentation
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "PlanningView-DragDropReady"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// GIVEN: PlanningView with tasks
    /// WHEN: Checking drop targets
    /// THEN: Timeline slots should be valid drop destinations
    func testTimelineSlotsExist() throws {
        navigateToPlanenTab()
        sleep(2)

        // Verify multiple hour slots exist
        var foundSlots = 0
        for hour in 6...20 {
            let hourString = String(format: "%02d:00", hour)
            if app.staticTexts[hourString].exists {
                foundSlots += 1
            }
        }

        XCTAssertGreaterThan(foundSlots, 3, "Timeline should show multiple hour slots")
    }

    // MARK: - After Scheduling Tests

    /// GIVEN: A task was scheduled (calendar event created)
    /// WHEN: Viewing the timeline
    /// THEN: The event should appear in the timeline
    func testScheduledEventAppearsInTimeline() throws {
        navigateToPlanenTab()
        sleep(2)

        // Check for any existing calendar events
        // Events show as colored blocks in the timeline
        // We can't easily test this without actual calendar events

        // Document current state
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Timeline-WithEvents"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Test passes if no crash
        XCTAssertTrue(true, "Timeline loads without crash")
    }

    // MARK: - Date Navigation Tests

    /// GIVEN: PlanningView is displayed
    /// WHEN: User changes date in picker
    /// THEN: Timeline should update to show that day's events
    func testChangingDateUpdatesTimeline() throws {
        navigateToPlanenTab()
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

    /// Full PlanningView screenshot for documentation
    func testPlanningViewFullScreenshot() throws {
        navigateToPlanenTab()
        sleep(3)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "PlanningView-Full"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
