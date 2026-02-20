import XCTest

final class BacklogSearchUITests: XCTestCase {

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

    // MARK: - Search Field Existence

    /// GIVEN: App is launched on Backlog tab
    /// WHEN: User looks at the Backlog view
    /// THEN: A search field should be accessible
    /// BREAKS AT: searchField.waitForExistence — .searchable() not on BacklogView
    @MainActor
    func testSearchFieldExists() throws {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Backlog should be loaded")

        // Pull down to reveal search bar (iOS standard pattern)
        app.swipeDown()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist in Backlog view")
    }

    // MARK: - Search Filtering

    /// GIVEN: A task exists in the backlog
    /// WHEN: User searches for part of the task title
    /// THEN: The task should remain visible (not filtered out)
    /// BREAKS AT: searchField.waitForExistence — .searchable() not on BacklogView
    @MainActor
    func testSearchFiltersByTitle() throws {
        // First create a task with a unique title
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Try accessibility ID first, fall back to placeholder text
        let titleField = app.textFields["taskTitle"].exists
            ? app.textFields["taskTitle"]
            : app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Task title field should appear")
        titleField.tap()
        titleField.typeText("UniqueSearchTestTask")

        // Save the task (toolbar button "Speichern")
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        saveButton.tap()

        // Wait for backlog to reload
        sleep(2)

        // Pull down to reveal search
        app.swipeDown()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")

        // Type search query
        searchField.tap()
        searchField.typeText("UniqueSearch")

        // The task should still be visible
        let taskCell = app.staticTexts["UniqueSearchTestTask"]
        XCTAssertTrue(taskCell.waitForExistence(timeout: 3), "Task matching search should be visible")
    }

    /// GIVEN: Backlog has tasks
    /// WHEN: User searches for a string that matches no task
    /// THEN: No tasks should be visible
    /// BREAKS AT: searchField.waitForExistence — .searchable() not on BacklogView
    @MainActor
    func testSearchNoResults() throws {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))

        // Pull down to reveal search
        app.swipeDown()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")

        // Search for something that definitely doesn't exist
        searchField.tap()
        searchField.typeText("ZZZYYYXXXNOMATCH999")

        // Wait for filter to apply
        sleep(1)

        // No task cells should match
        let anyCells = app.cells.count
        XCTAssertEqual(anyCells, 0, "No tasks should match nonsense search query")
    }
}
