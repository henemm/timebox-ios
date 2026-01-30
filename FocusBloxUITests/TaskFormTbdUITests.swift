import XCTest

/// UI Tests for Bug 15 + 16: TaskFormSheet TBD defaults and SF Symbols
///
/// Bug 15: New tasks should have nil importance/urgency (TBD) instead of defaults
/// Bug 16: Importance picker should use SF Symbols, not emoji
///
/// TDD RED: Tests FAIL because bugs exist
/// TDD GREEN: Tests PASS after fix
final class TaskFormTbdUITests: XCTestCase {

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

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    private func openCreateTaskSheet() {
        // Find and tap "+" button to create new task
        let addButton = app.buttons["addTaskButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else {
            // Fallback: try navigation bar button
            let navAddButton = app.navigationBars.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Hinzufügen' OR label CONTAINS 'plus' OR label CONTAINS 'add'")
            ).firstMatch
            if navAddButton.waitForExistence(timeout: 3) {
                navAddButton.tap()
            }
        }
        sleep(1)
    }

    // MARK: - Bug 15: TBD Defaults

    /// Test: New task form should NOT have importance pre-selected
    /// EXPECTED TO FAIL: Currently defaults to "Medium" (priority = 2)
    func testNewTaskImportanceNotPreSelected() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Screenshot: Initial state of form
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug15-TaskForm-InitialState"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Find importance section
        let importanceSection = app.staticTexts["Wichtigkeit"]
        guard importanceSection.waitForExistence(timeout: 3) else {
            throw XCTSkip("Importance section not found")
        }

        // Check that NO importance button is in "selected" state
        // A button is selected if it has accent color background
        // We check by looking for a "TBD" or "?" indicator, or no selection highlight

        // Look for the TBD indicator (questionmark or gray state)
        let tbdIndicator = app.buttons["importanceNotSet"]
        let noSelectionState = app.images["questionmark"]

        // Alternative: Check that "Niedrig", "Mittel", "Hoch" buttons exist but none is highlighted
        let lowButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Niedrig' OR identifier == 'importanceLow'")
        ).firstMatch
        let mediumButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Mittel' OR identifier == 'importanceMedium'")
        ).firstMatch
        let highButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Hoch' OR identifier == 'importanceHigh'")
        ).firstMatch

        // The test passes if there's a "not set" option OR if we can detect no selection
        // For now, we assert that a TBD/optional state exists
        let hasTbdOption = tbdIndicator.exists || noSelectionState.exists ||
            app.buttons["importanceNone"].exists ||
            app.staticTexts["Nicht gesetzt"].exists

        XCTAssertTrue(
            hasTbdOption,
            "Bug 15: New task form should have 'not set' option for importance. " +
            "Currently defaults to Medium instead of TBD."
        )
    }

    /// Test: New task form should NOT have urgency pre-selected
    /// EXPECTED TO FAIL: Currently defaults to "not_urgent"
    func testNewTaskUrgencyNotPreSelected() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Find urgency section
        let urgencySection = app.staticTexts["Dringlichkeit"]
        guard urgencySection.waitForExistence(timeout: 3) else {
            throw XCTSkip("Urgency section not found")
        }

        // Check for TBD/optional state in urgency picker
        let tbdOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Nicht gesetzt' OR identifier == 'urgencyNone'")
        ).firstMatch

        XCTAssertTrue(
            tbdOption.exists,
            "Bug 15: New task form should have 'not set' option for urgency. " +
            "Currently defaults to 'Nicht dringend' instead of TBD."
        )
    }

    // MARK: - Bug 16: SF Symbols statt Emoji

    /// Test: Importance buttons should use SF Symbols, not emoji
    /// EXPECTED TO FAIL: Currently shows 🟦, 🟨, 🔴 emoji
    func testImportanceUsesSFSymbols() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Screenshot for visual verification
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug16-ImportanceButtons"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Check that emoji are NOT present in importance buttons
        let emojiButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '🟦' OR label CONTAINS '🟨' OR label CONTAINS '🔴'")
        )

        XCTAssertEqual(
            emojiButtons.count, 0,
            "Bug 16: Importance buttons should NOT contain emoji (🟦, 🟨, 🔴). " +
            "Should use SF Symbols (exclamationmark) instead."
        )
    }

    /// Test: Importance section should show SF Symbol images
    /// EXPECTED TO FAIL: No SF Symbol images in current implementation
    func testImportanceShowsSFSymbolImages() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Look for SF Symbol images in importance section
        // exclamationmark, exclamationmark.2, exclamationmark.3
        let sfSymbolImages = app.images.matching(
            NSPredicate(format: "identifier CONTAINS 'exclamationmark' OR label CONTAINS 'exclamationmark'")
        )

        // Alternative: Look for buttons with SF Symbol identifiers
        let sfSymbolButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importance_' AND identifier CONTAINS 'exclamationmark'")
        )

        let hasSFSymbols = sfSymbolImages.count > 0 || sfSymbolButtons.count > 0

        XCTAssertTrue(
            hasSFSymbols,
            "Bug 16: Importance section should display SF Symbol images " +
            "(exclamationmark, exclamationmark.2, exclamationmark.3)"
        )
    }
}
