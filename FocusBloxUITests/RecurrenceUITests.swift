import XCTest

/// UI Tests for Bug 19: Recurring Tasks in TaskFormSheet
///
/// Tests verify that recurrence options are available in the task form
/// and that weekly/monthly specific options appear when needed.
final class RecurrenceUITests: XCTestCase {
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

    // MARK: - Helper Methods

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

    // MARK: - Test: Recurrence Picker Exists

    /// GIVEN: TaskFormSheet is open (Create Mode)
    /// THEN: Recurrence picker should exist with "Wiederholt sich" label
    func testRecurrencePickerExists() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Scroll down to find recurrence section
        let scrollView = app.scrollViews["taskFormScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Task form scroll view should exist")

        // Look for recurrence section
        let recurrenceSection = app.otherElements["taskFormSection_recurrence"]

        // Swipe up to reveal recurrence section if needed
        if !recurrenceSection.exists {
            scrollView.swipeUp()
            sleep(1)
        }

        XCTAssertTrue(
            recurrenceSection.waitForExistence(timeout: 3),
            "Bug 19: Recurrence section should exist in TaskFormSheet"
        )

        // Check for recurrence picker
        let recurrencePicker = app.buttons["recurrencePicker"]
        XCTAssertTrue(
            recurrencePicker.exists || app.staticTexts["Wiederholt sich"].exists,
            "Bug 19: Recurrence picker should be visible"
        )

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RecurrenceSection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: TaskFormSheet is open
    /// WHEN: Recurrence = "Wöchentlich"
    /// THEN: 7 Weekday buttons should appear (Mo, Di, Mi, Do, Fr, Sa, So)
    func testWeekdayButtonsAppearForWeekly() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        let scrollView = app.scrollViews["taskFormScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Task form scroll view should exist")

        // Scroll to recurrence section
        scrollView.swipeUp()
        sleep(1)

        // Find and tap recurrence picker to open menu
        let recurrencePicker = app.buttons["recurrencePicker"]
        if recurrencePicker.waitForExistence(timeout: 3) {
            recurrencePicker.tap()
            sleep(1)

            // Select "Wöchentlich"
            let weeklyOption = app.buttons["Wöchentlich"]
            if weeklyOption.waitForExistence(timeout: 2) {
                weeklyOption.tap()
                sleep(1)
            }
        }

        // Check for weekday buttons
        let mondayButton = app.buttons["weekdayButton_1"]
        let sundayButton = app.buttons["weekdayButton_7"]

        let hasWeekdayButtons = mondayButton.waitForExistence(timeout: 3) || sundayButton.exists

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "WeeklyRecurrenceWithWeekdays"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(
            hasWeekdayButtons,
            "Bug 19: Weekday buttons should appear when recurrence is set to 'Wöchentlich'"
        )
    }

    /// GIVEN: TaskFormSheet is open
    /// WHEN: Recurrence = "Monatlich"
    /// THEN: Month day picker should appear
    func testMonthDayPickerAppearsForMonthly() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        let scrollView = app.scrollViews["taskFormScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Task form scroll view should exist")

        // Scroll to recurrence section
        scrollView.swipeUp()
        sleep(1)

        // Find and tap recurrence picker
        let recurrencePicker = app.buttons["recurrencePicker"]
        if recurrencePicker.waitForExistence(timeout: 3) {
            recurrencePicker.tap()
            sleep(1)

            // Select "Monatlich"
            let monthlyOption = app.buttons["Monatlich"]
            if monthlyOption.waitForExistence(timeout: 2) {
                monthlyOption.tap()
                sleep(1)
            }
        }

        // Check for month day picker
        let monthDayPicker = app.buttons["monthDayPicker"]
        let hasMonthDayPicker = monthDayPicker.waitForExistence(timeout: 3)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MonthlyRecurrenceWithDayPicker"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(
            hasMonthDayPicker,
            "Bug 19: Month day picker should appear when recurrence is set to 'Monatlich'"
        )
    }

    /// GIVEN: TaskFormSheet is open
    /// WHEN: Different recurrence patterns are selected
    /// THEN: The picker should display the correct pattern names
    func testRecurrencePatternOptions() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        let scrollView = app.scrollViews["taskFormScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Task form scroll view should exist")

        // Scroll to recurrence section
        scrollView.swipeUp()
        sleep(1)

        // Find and tap recurrence picker
        let recurrencePicker = app.buttons["recurrencePicker"]
        guard recurrencePicker.waitForExistence(timeout: 3) else {
            XCTFail("Recurrence picker not found")
            return
        }

        recurrencePicker.tap()
        sleep(1)

        // Take screenshot of options menu
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "RecurrencePatternOptions"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Check for expected options
        let expectedOptions = ["Nie", "Täglich", "Wöchentlich", "Zweiwöchentlich", "Monatlich"]
        for option in expectedOptions {
            let optionButton = app.buttons[option]
            XCTAssertTrue(
                optionButton.exists,
                "Bug 19: Recurrence option '\(option)' should be available"
            )
        }
    }
}
