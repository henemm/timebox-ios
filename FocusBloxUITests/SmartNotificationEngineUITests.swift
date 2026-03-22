import XCTest

/// UI Tests for SmartNotificationEngine integration (RW_0.1 Phase A)
/// TDD RED: Tests MUST FAIL — SmartNotificationEngine doesn't exist yet,
/// so FocusBloxApp can't compile with the reconcile() call.
///
/// These tests verify that the Engine integration in FocusBloxApp
/// doesn't break the app lifecycle (start, background, foreground).
final class SmartNotificationEngineUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// EXPECTED TO FAIL (RED): App startet und Backlog-Tab ist erreichbar.
    /// Validiert dass SmartNotificationEngine.reconcile() im scenePhase-Handler
    /// den App-Start nicht blockiert oder crasht.
    /// Bricht wenn: reconcile() synchron auf Main Thread laeuft und blockiert,
    ///   oder wenn die Engine-Integration in FocusBloxApp einen Compile-Error verursacht.
    func test_appStartsWithReconciliation() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10),
                      "App should start and show Backlog tab after Engine integration")
    }

    /// EXPECTED TO FAIL (RED): App überlebt Background → Foreground Cycle.
    /// Validiert dass reconcile(reason: .appForeground) bei Rückkehr aus Background
    /// keine Race Condition oder Crash verursacht.
    /// Bricht wenn: Die async reconcile() Task in FocusBloxApp.onChange(scenePhase)
    ///   nicht korrekt auf @MainActor dispatched wird.
    func test_appSurvivesBackgroundForegroundCycle() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "App should start")

        // Background simulieren via Home Button
        XCUIDevice.shared.press(.home)

        // Foreground: App wieder öffnen — warten bis UI verfügbar
        app.activate()

        // App muss nach Foreground noch funktionieren (reconcile wurde getriggert)
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10),
                      "App should survive background→foreground with reconciliation")
    }
}
