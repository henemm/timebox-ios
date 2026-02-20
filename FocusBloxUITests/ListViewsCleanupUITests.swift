import XCTest

final class ListViewsCleanupUITests: XCTestCase {

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

    // MARK: - Default ViewMode

    /// GIVEN: App launches fresh
    /// WHEN: Looking at the Backlog toolbar
    /// THEN: The default view mode should be "Priorität" (not "Liste")
    /// BREAKS AT: staticTexts["Priorität"] — default is currently "Liste"
    @MainActor
    func test_defaultViewMode_isPriority() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5), "ViewMode switcher should exist")

        // The switcher label should show "Priorität" as default
        let priorityLabel = switcher.staticTexts["Priorität"]
        XCTAssertTrue(priorityLabel.exists, "Default view mode should be 'Priorität', not 'Liste'")
    }

    // MARK: - New ViewMode Options

    /// GIVEN: App is on Backlog tab
    /// WHEN: Opening the ViewMode picker
    /// THEN: "Zuletzt" option should exist
    /// BREAKS AT: buttons["Zuletzt"] — this ViewMode doesn't exist yet
    @MainActor
    func test_viewModePicker_hasRecentOption() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()

        sleep(1)

        let recentOption = app.buttons["Zuletzt"]
        XCTAssertTrue(recentOption.waitForExistence(timeout: 3), "'Zuletzt' option should exist in ViewMode picker")
    }

    /// GIVEN: App is on Backlog tab
    /// WHEN: Opening the ViewMode picker
    /// THEN: "Überfällig" option should exist
    /// BREAKS AT: buttons["Überfällig"] — this ViewMode doesn't exist yet
    @MainActor
    func test_viewModePicker_hasOverdueOption() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()

        sleep(1)

        let overdueOption = app.buttons["Überfällig"]
        XCTAssertTrue(overdueOption.waitForExistence(timeout: 3), "'Überfällig' option should exist in ViewMode picker")
    }

    // MARK: - Removed ViewMode Options

    /// GIVEN: App is on Backlog tab
    /// WHEN: Opening the ViewMode picker
    /// THEN: "Liste" option should NOT exist (removed)
    /// BREAKS AT: XCTAssertFalse — "Liste" still exists in current picker
    @MainActor
    func test_viewModePicker_noListOption() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()

        sleep(1)

        let listOption = app.buttons["Liste"]
        XCTAssertFalse(listOption.exists, "'Liste' option should be removed from ViewMode picker")
    }

    /// GIVEN: App is on Backlog tab
    /// WHEN: Opening the ViewMode picker
    /// THEN: "Matrix" option should NOT exist (removed)
    /// BREAKS AT: XCTAssertFalse — "Matrix" still exists in current picker
    @MainActor
    func test_viewModePicker_noMatrixOption() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()

        sleep(1)

        let matrixOption = app.buttons["Matrix"]
        XCTAssertFalse(matrixOption.exists, "'Matrix' option should be removed from ViewMode picker")
    }

    /// GIVEN: App is on Backlog tab
    /// WHEN: Opening the ViewMode picker
    /// THEN: Only 5 options should exist (Priorität, Zuletzt, Überfällig, Wiederkehrend, Erledigt)
    /// BREAKS AT: count check — currently 9 options exist
    @MainActor
    func test_viewModePicker_hasFiveOptions() throws {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()

        sleep(1)

        // Verify the 5 expected options exist
        let expectedOptions = ["Priorität", "Zuletzt", "Überfällig", "Wiederkehrend", "Erledigt"]
        for option in expectedOptions {
            let button = app.buttons[option]
            XCTAssertTrue(button.waitForExistence(timeout: 2), "'\(option)' should exist in picker")
        }

        // Verify removed options don't exist
        let removedOptions = ["Liste", "Matrix", "Kategorie", "Dauer", "Fälligkeit", "TBD"]
        for option in removedOptions {
            let button = app.buttons[option]
            XCTAssertFalse(button.exists, "'\(option)' should NOT exist in picker (removed)")
        }
    }
}
