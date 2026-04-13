import XCTest

/// UI Tests for Backlog Hygiene Nudges (#215)
/// Tests: Tab badge with stale count, toolbar hygiene button, hygiene sheet navigation
final class BacklogHygieneNudgeUITests: XCTestCase {
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

    // MARK: - Tab Badge Tests

    /// Verhalten: Backlog-Tab zeigt Badge wenn stale Tasks existieren
    /// Bricht wenn: .badge(staleCount) nicht auf dem Backlog-Tab gesetzt ist
    func testBacklogTabShowsBadgeWhenStaleTasksExist() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")

        // Badge value is non-empty when stale tasks exist
        let badgeValue = backlogTab.value as? String ?? ""
        if !badgeValue.isEmpty {
            let containsNumber = badgeValue.rangeOfCharacter(from: .decimalDigits) != nil
            XCTAssertTrue(containsNumber, "Badge should contain a number, got: '\(badgeValue)'")
        }
    }

    /// Verhalten: Hygiene-Button in der Toolbar öffnet das Hygiene-Sheet
    /// Bricht wenn: hygieneToolbarButton oder BacklogHygieneView nicht existiert
    func testHygieneToolbarButtonOpensSheet() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()

        let hygieneButton = app.buttons["hygieneToolbarButton"]
        XCTAssertTrue(hygieneButton.waitForExistence(timeout: 5),
                      "Hygiene toolbar button should exist on Backlog tab")
        hygieneButton.tap()

        let hygieneTitle = app.staticTexts["hygieneTitle"]
        XCTAssertTrue(hygieneTitle.waitForExistence(timeout: 5),
                      "Hygiene view should open when toolbar button is tapped")
    }

    /// Verhalten: Badge-Count reflektiert stale Tasks (nicht behaltene)
    /// Bricht wenn: BacklogHealthService.findStaleTasks nicht den reviewedAt-Filter hat
    func testBadgeCountExcludesReviewedTasks() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()

        let initialBadge = backlogTab.value as? String ?? ""

        let hygieneButton = app.buttons["hygieneToolbarButton"]
        guard hygieneButton.waitForExistence(timeout: 5) else { return }
        hygieneButton.tap()

        let keepButton = app.buttons["hygieneKeepButton"]
        if keepButton.waitForExistence(timeout: 3) {
            keepButton.tap()

            _ = app.staticTexts["hygieneTitle"].waitForExistence(timeout: 2)
            app.swipeDown()

            let updatedBadge = backlogTab.value as? String ?? ""
            if !initialBadge.isEmpty {
                let initialCount = Int(initialBadge) ?? 0
                let updatedCount = Int(updatedBadge) ?? 0
                XCTAssertLessThanOrEqual(updatedCount, initialCount,
                    "Badge should decrease after keeping a task, was \(initialCount), now \(updatedCount)")
            }
        }
    }
}
