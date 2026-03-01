import XCTest

/// UI Tests for SiriTipView integration (ITB-G4).
/// Verifies that native Apple SiriTipView appears in BacklogView.
final class ITB_G_SiriTipUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    /// EXPECTED TO FAIL: SiriTipView not yet added to BacklogView
    /// Verhalten: SiriTipView fuer CreateTaskIntent ist in BacklogView sichtbar
    /// Bricht wenn: SiriTipView(intent: CreateTaskIntent()) nicht in BacklogView eingebaut wird
    func test_siriTip_visibleInBacklog() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.exists {
            backlogTab.tap()
        }

        // SiriTipView renders with the Siri phrase text from FocusBloxShortcuts
        // Apple's SiriTipView contains the phrase "Task erstellen"
        let tipText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Task erstellen'")
        )
        XCTAssertTrue(
            tipText.firstMatch.waitForExistence(timeout: 5),
            "SiriTipView with 'Task erstellen' phrase should be visible in BacklogView"
        )
    }
}
