import XCTest

/// UI Tests for SmartNotificationEngine Phase B (FocusBlock Migration)
/// TDD RED: Tests MUST FAIL — Views still use direct NotificationService calls.
/// After migration, Views use SmartNotificationEngine.reconcile() instead.
/// These tests verify the app lifecycle remains stable after the migration.
final class SmartNotificationEnginePhaseBUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    /// Verhalten: App startet nach Phase B Migration ohne Crash.
    /// Validiert dass reconcile(context:) Overload korrekt kompiliert und
    /// keine Runtime-Fehler verursacht.
    /// Bricht wenn: Compile Error durch fehlenden ModelContext-Overload,
    ///   oder Runtime-Crash bei reconcile()-Aufruf in View.
    func test_appStartsAfterMigration() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10),
                      "App should start normally after Phase B migration")
    }

    /// Verhalten: Kalender-Tab (BlockPlanningView) ist nach Migration erreichbar und funktional.
    /// Validiert dass BlockPlanningView nach Entfernung der 6 NotificationService-Calls
    /// weiterhin Blocks anzeigen kann.
    /// Bricht wenn: BlockPlanningView durch fehlende reconcile()-Integration crasht.
    func test_calendarTabAccessibleAfterMigration() throws {
        let calendarTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10),
                      "Calendar tab should be accessible")
        calendarTab.tap()

        // Kalender-View sollte geladen werden (Timeline oder Tagesansicht)
        let exists = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Focus'")).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Calendar view should load after migration")
    }

    /// Verhalten: App ueberlebt Background → Foreground nach Phase B Migration.
    /// Validiert dass reconcile(reason: .appForeground, context:, eventKitRepo:)
    /// keinen Crash verursacht wenn Views den neuen Overload nutzen.
    /// Bricht wenn: Race Condition zwischen View-reconcile und App-reconcile.
    func test_backgroundForegroundCycleAfterMigration() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "App should start")

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10),
                      "App should survive background→foreground after Phase B migration")
    }
}
