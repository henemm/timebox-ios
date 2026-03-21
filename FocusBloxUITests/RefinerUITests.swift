import XCTest

final class RefinerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-InjectRawTasks"]
        app.launch()
    }

    // MARK: - Navigation

    /// EXPECTED TO FAIL: Refiner tab doesn't exist yet
    /// Bricht wenn: AppTab.refiner Case oder RefinerView() Tab-Eintrag entfernt wird
    func testRefinerTab_isVisible() {
        let refinerTab = app.tabBars.buttons["Refiner"]
        XCTAssertTrue(refinerTab.exists, "Refiner tab must exist in tab bar")
    }

    /// EXPECTED TO FAIL: Refiner tab and view don't exist yet
    /// Bricht wenn: RefinerView NavigationTitle nicht "Refiner" ist
    func testRefinerTab_navigatesToRefinerView() {
        let refinerTab = app.tabBars.buttons["Refiner"]
        XCTAssertTrue(refinerTab.waitForExistence(timeout: 3), "Refiner tab must exist")
        refinerTab.tap()
        XCTAssertTrue(
            app.navigationBars["Refiner"].waitForExistence(timeout: 3),
            "Tapping Refiner tab must show RefinerView with navigation title 'Refiner'"
        )
    }

    // MARK: - Task List

    /// Bricht wenn: refiner_taskList accessibilityIdentifier entfernt oder List entfernt wird
    func testRefinerView_showsRawTasks() {
        app.tabBars.buttons["Refiner"].tap()
        // SwiftUI List renders as collectionView in accessibility tree
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3), "Task list must be visible when raw tasks exist")
    }

    /// EXPECTED TO FAIL: RefinerTaskCard doesn't exist yet
    /// Bricht wenn: refinerCard_title accessibilityIdentifier entfernt wird
    func testRefinerView_showsTaskTitle() {
        app.tabBars.buttons["Refiner"].tap()
        let title = app.staticTexts["refinerCard_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Each task card must show the raw title")
    }

    /// EXPECTED TO FAIL: Suggestion chips don't exist yet
    /// Bricht wenn: SuggestionChip mit refinerCard_chip_category ID entfernt wird
    func testRefinerView_showsSuggestionChips() {
        app.tabBars.buttons["Refiner"].tap()
        let chip = app.staticTexts["refinerCard_chip_category"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3), "AI suggestion chips must appear on task card")
    }

    // MARK: - Confirm All

    /// EXPECTED TO FAIL: Confirm all button doesn't exist yet
    /// Bricht wenn: refiner_confirmAllButton accessibilityIdentifier entfernt wird
    func testRefinerView_confirmAllButtonExists() {
        app.tabBars.buttons["Refiner"].tap()
        let btn = app.buttons["refiner_confirmAllButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 3), "'Alle bestätigen' button must be visible when tasks exist")
    }

    /// EXPECTED TO FAIL: Confirm all + empty state don't exist yet
    /// Bricht wenn: confirmAll() oder emptyState aus RefinerView entfernt wird
    func testRefinerView_confirmAllShowsEmptyState() {
        app.tabBars.buttons["Refiner"].tap()
        let btn = app.buttons["refiner_confirmAllButton"]
        guard btn.waitForExistence(timeout: 3) else {
            XCTFail("Confirm all button must exist")
            return
        }
        btn.tap()
        let emptyState = app.staticTexts["refiner_emptyState"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3), "Empty state must appear after confirming all")
    }

    // MARK: - Empty State

    /// EXPECTED TO FAIL: RefinerView and empty state don't exist yet
    /// Bricht wenn: emptyState View oder refiner_emptyState ID entfernt wird
    func testRefinerView_emptyStateWhenNoRawTasks() {
        // Launch WITHOUT --inject-raw-tasks
        let cleanApp = XCUIApplication()
        cleanApp.launchArguments = ["-UITesting"]
        cleanApp.launch()

        let refinerTab = cleanApp.tabBars.buttons["Refiner"]
        guard refinerTab.waitForExistence(timeout: 3) else {
            XCTFail("Refiner tab must exist")
            return
        }
        refinerTab.tap()
        let emptyState = cleanApp.staticTexts["refiner_emptyState"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3), "Empty state must show when no raw tasks exist")
    }
}
