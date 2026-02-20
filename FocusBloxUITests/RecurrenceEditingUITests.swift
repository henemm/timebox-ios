import XCTest

/// UI Tests for Recurrence Editing in TaskFormSheet (Feature: recurrence-editing Phase 1)
/// Tests that new recurrence pattern options are available in the picker.
/// EXPECTED TO FAIL: New picker options do not exist yet.
final class RecurrenceEditingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - New Recurrence Options in TaskFormSheet

    /// GIVEN: User opens create-task sheet
    /// WHEN: User scrolls to recurrence section
    /// THEN: Picker should contain "An Wochentagen" option
    func testRecurrencePicker_containsWeekdaysOption() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToRecurrenceSection()

        let picker = app.buttons["recurrencePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Recurrence picker should exist")
        picker.tap()
        sleep(1)

        // Look for the new "An Wochentagen" option in the picker
        let weekdaysOption = app.buttons["An Wochentagen"]
        XCTAssertTrue(weekdaysOption.waitForExistence(timeout: 3),
            "Recurrence picker should contain 'An Wochentagen' option")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RecurrencePicker_Weekdays"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: User opens create-task sheet
    /// WHEN: User opens recurrence picker
    /// THEN: Picker should contain "An Wochenenden" option
    func testRecurrencePicker_containsWeekendsOption() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToRecurrenceSection()

        let picker = app.buttons["recurrencePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Recurrence picker should exist")
        picker.tap()
        sleep(1)

        let weekendsOption = app.buttons["An Wochenenden"]
        XCTAssertTrue(weekendsOption.waitForExistence(timeout: 3),
            "Recurrence picker should contain 'An Wochenenden' option")
    }

    /// GIVEN: User opens create-task sheet
    /// WHEN: User opens recurrence picker
    /// THEN: Picker should contain "Alle 3 Monate" option
    func testRecurrencePicker_containsQuarterlyOption() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToRecurrenceSection()

        let picker = app.buttons["recurrencePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Recurrence picker should exist")
        picker.tap()
        sleep(1)

        let quarterlyOption = app.buttons["Alle 3 Monate"]
        XCTAssertTrue(quarterlyOption.waitForExistence(timeout: 3),
            "Recurrence picker should contain 'Alle 3 Monate' option")
    }

    /// GIVEN: User opens create-task sheet
    /// WHEN: User opens recurrence picker
    /// THEN: Picker should contain "Jährlich" option
    func testRecurrencePicker_containsYearlyOption() throws {
        navigateToBacklog()
        openCreateTaskSheet()
        scrollToRecurrenceSection()

        let picker = app.buttons["recurrencePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Recurrence picker should exist")
        picker.tap()
        sleep(1)

        let yearlyOption = app.buttons["Jährlich"]
        XCTAssertTrue(yearlyOption.waitForExistence(timeout: 3),
            "Recurrence picker should contain 'Jährlich' option")
    }

    // MARK: - Helpers

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    private func openCreateTaskSheet() {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        addButton.tap()
        sleep(1)
    }

    private func scrollToRecurrenceSection() {
        let scrollView = app.scrollViews["taskFormScrollView"]
        if scrollView.waitForExistence(timeout: 3) {
            scrollView.swipeUp()
            sleep(1)
        }
    }
}
