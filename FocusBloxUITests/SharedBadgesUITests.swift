import XCTest

/// UI Tests fuer TD-02 Shared Badge Components
/// Verifizieren dass Badge-Interaktion nach Refactoring identisch funktioniert
final class SharedBadgesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    // MARK: - Importance Badge

    /// Verhalten: Importance Badge existiert und ist tappbar
    /// Bricht wenn: Badge accessibility ID sich aendert nach Refactoring
    func testImportanceBadgeExistsAndIsTappable() throws {
        navigateToBacklog()

        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Importance badge should exist")
        XCTAssertTrue(badge.isHittable, "Importance badge should be tappable")
    }

    /// Verhalten: Importance Badge Tap aendert die Darstellung (Cycling)
    /// Bricht wenn: Cycling-Logik im Shared Badge nicht korrekt verdrahtet
    func testImportanceBadgeTapCyclesValue() throws {
        navigateToBacklog()

        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("Importance badge not found")
            return
        }

        let labelBefore = badge.label
        badge.tap()
        sleep(1)

        let labelAfter = badge.label
        XCTAssertNotEqual(labelBefore, labelAfter,
            "Importance badge label should change after tap (cycling)")
    }

    // MARK: - Urgency Badge

    /// Verhalten: Urgency Badge existiert und ist tappbar
    /// Bricht wenn: Badge accessibility ID sich aendert nach Refactoring
    func testUrgencyBadgeExistsAndIsTappable() throws {
        navigateToBacklog()

        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        ).firstMatch

        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Urgency badge should exist")
        XCTAssertTrue(badge.isHittable, "Urgency badge should be tappable")
    }

    // MARK: - Priority Score Badge

    /// Verhalten: Priority Score Badge existiert fuer Tasks mit Score
    /// Bricht wenn: Badge accessibility ID sich aendert nach Refactoring
    func testPriorityScoreBadgeExists() throws {
        navigateToBacklog()

        let badge = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'priorityScoreBadge_'")
        ).firstMatch

        // Priority badge might be a static text or other element, try buttons too
        let badgeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'priorityScoreBadge_'")
        ).firstMatch

        let exists = badge.waitForExistence(timeout: 5) || badgeButton.waitForExistence(timeout: 3)
        XCTAssertTrue(exists, "Priority score badge should exist for tasks with score")
    }
}
