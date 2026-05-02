import XCTest

/// Bug #223 (legacy) — der "doNow"-Marker wurde im Zuge der Issues #288/#294/#296
/// durch den uhrzeit-praezisen `overdueMarker_` ersetzt. Diese Datei haelt nur
/// noch einen Smoke-Test, damit die Test-Suite nicht regrediert. Die echten
/// Pruefungen leben in OverdueMarkerUITests.swift.
final class DoNowBadgeUITests: XCTestCase {

    /// Verhalten: App startet im UI-Test-Modus und der Backlog-Tab ist sichtbar.
    /// Bricht wenn: Backlog-Tab nicht mehr existiert (Tab-Navigation kaputt).
    func test_backlog_tab_exists_underUITestArgs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()

        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(
            backlogTab.waitForExistence(timeout: 10),
            "Backlog-Tab muss im UI-Test-Modus existieren"
        )
    }
}
