import XCTest

/// Bug #223: doNow-Tasks müssen im Backlog visuell rot markiert sein.
/// Prüft dass Tasks mit hohem Score eine sichtbare doNow-Markierung haben.
final class DoNowBadgeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-seedDoNowTask"]
        app.launch()
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab muss existieren")
        backlogTab.tap()
    }

    // MARK: - doNow Marker

    /// Verhalten: doNow-Tasks haben eine rote Markierung (doNowMarker)
    /// Bricht wenn: Markierung fehlt oder falschen Identifier hat
    func test_doNowTask_hasRedMarker() throws {
        navigateToBacklog()

        let marker = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'doNowMarker_'")
        ).firstMatch

        XCTAssertTrue(
            marker.waitForExistence(timeout: 5),
            "doNow-Tasks müssen einen roten Marker (doNowMarker_*) haben"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "doNow_marker_visible"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Verhalten: Nicht-doNow-Tasks haben KEINEN doNow-Marker
    /// Bricht wenn: Markierung fälschlicherweise an allen Tasks erscheint
    func test_lowScoreTask_hasNoDoNowMarker() throws {
        // Starte ohne seed — nur leere Tasks oder niedrige Scores
        let cleanApp = XCUIApplication()
        cleanApp.launchArguments = ["-UITesting", "-seedLowScoreTask"]
        cleanApp.launch()

        let backlogTab = cleanApp.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()

        let marker = cleanApp.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'doNowMarker_'")
        ).firstMatch

        // Marker sollte NICHT existieren bei niedrigen Scores
        XCTAssertFalse(
            marker.waitForExistence(timeout: 3),
            "Niedrig-Score-Tasks dürfen keinen doNow-Marker haben"
        )
    }
}
