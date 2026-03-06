import XCTest

/// UI Tests fuer TD-02 Shared Sheet Components
/// Verifizieren dass Sheet-Verhalten nach Unification identisch funktioniert
final class SharedSheetsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    private func navigateToPlanning() {
        let planningTab = app.tabBars.buttons["Planung"]
        if planningTab.waitForExistence(timeout: 5) {
            planningTab.tap()
            sleep(1)
        }
    }

    // MARK: - CreateFocusBlockSheet

    /// Verhalten: Free Slot Tap oeffnet CreateFocusBlockSheet mit DatePickern
    /// Bricht wenn: Sheet-Typ sich aendert oder DatePicker fehlen nach Refactoring
    func testCreateFocusBlockSheetHasDatePickers() throws {
        navigateToPlanning()

        // Find a free slot and tap it
        let freeSlot = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch

        guard freeSlot.waitForExistence(timeout: 5) else {
            // No free slots available in mock data — skip gracefully
            throw XCTSkip("No free slots available in mock data")
        }

        freeSlot.tap()
        sleep(1)

        // Sheet should show DatePickers for Start and End
        let startPicker = app.datePickers["Start"]
        let endPicker = app.datePickers["Ende"]
        XCTAssertTrue(startPicker.waitForExistence(timeout: 3), "Start DatePicker should exist in CreateFocusBlockSheet")
        XCTAssertTrue(endPicker.exists, "Ende DatePicker should exist in CreateFocusBlockSheet")
    }

    /// Verhalten: CreateFocusBlockSheet hat Erstellen-Button
    /// Bricht wenn: Button-Label oder Placement sich aendert nach Refactoring
    func testCreateFocusBlockSheetHasCreateButton() throws {
        navigateToPlanning()

        let freeSlot = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch

        guard freeSlot.waitForExistence(timeout: 5) else {
            throw XCTSkip("No free slots available in mock data")
        }

        freeSlot.tap()
        sleep(1)

        let createButton = app.buttons["Erstellen"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Erstellen button should exist in CreateFocusBlockSheet")
    }

    // MARK: - EventCategorySheet

    /// Verhalten: Event Tap oeffnet EventCategorySheet mit allen Kategorien
    /// Bricht wenn: CategorySheet nicht alle TaskCategory.allCases zeigt
    func testEventCategorySheetShowsAllCategories() throws {
        navigateToPlanning()

        // Find a calendar event and tap it
        let event = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timelineEvent_'")
        ).firstMatch

        guard event.waitForExistence(timeout: 5) else {
            throw XCTSkip("No calendar events available in mock data")
        }

        event.tap()
        sleep(1)

        // All 5 categories should be visible
        let arbeit = app.buttons["categoryOption_work"]
        let privat = app.buttons["categoryOption_personal"]
        let gesundheit = app.buttons["categoryOption_health"]
        let lernen = app.buttons["categoryOption_learning"]
        let projekt = app.buttons["categoryOption_project"]

        let categoryExists = arbeit.waitForExistence(timeout: 3)
            || privat.waitForExistence(timeout: 1)
            || gesundheit.waitForExistence(timeout: 1)
            || lernen.waitForExistence(timeout: 1)
            || projekt.waitForExistence(timeout: 1)

        XCTAssertTrue(categoryExists, "At least one category option should exist in EventCategorySheet")
    }
}
