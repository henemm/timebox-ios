import XCTest

/// Bug 102: Coach-Sync iOS↔macOS — UI Tests
/// Verifiziert dass ein via iCloud-Sync empfangener Coach korrekt angezeigt wird.
/// Nutzt -MockSyncedCoach Launch-Argument das pullFromCloud() simuliert
/// (schreibt selectedCoach + selectedCoachDate in UserDefaults.standard OHNE App Group).
final class CoachSyncUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helper

    /// Launches with coach mode + simulated sync pull.
    /// -MockSyncedCoach schreibt selectedCoach="troll" + selectedCoachDate in UserDefaults.standard
    /// Dies simuliert den Pfad: pullFromCloud() → UserDefaults → @AppStorage → View Update
    private func launchWithSyncedCoach() {
        app.launchArguments = [
            "-UITesting",
            "-CoachModeEnabled",
            "-MockSyncedCoach"
        ]
        app.launch()
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
    }

    // MARK: - Synced Coach Display

    /// Verhalten: Nach iCloud-Sync soll der Coach-Name im Monster Header erscheinen.
    /// Bricht wenn: -MockSyncedCoach Launch-Argument nicht implementiert (Coach bleibt leer).
    /// Verifizierte IDs: coachMonsterHeader (.contain), Text "Troll — Der Aufräumer"
    func test_syncedCoach_showsCoachNameInHeader() throws {
        launchWithSyncedCoach()
        navigateToBacklog()

        // MonsterIntentionHeader zeigt: "\(coach.displayName) — \(coach.subtitle)"
        // Fuer Troll: "Troll — Der Aufräumer"
        let coachHeader = app.staticTexts["Troll — Der Aufräumer"]
        XCTAssertTrue(coachHeader.waitForExistence(timeout: 5),
                      "Bug 102: Synced coach name should appear in Monster header")
    }

    /// Verhalten: Nach iCloud-Sync soll der Hint-Text verschwinden.
    /// Bricht wenn: -MockSyncedCoach Launch-Argument nicht implementiert.
    /// Verifizierte IDs: Text "Starte deinen Tag unter Mein Tag" (MonsterIntentionHeader.swift:30)
    func test_syncedCoach_hintTextDisappears() throws {
        launchWithSyncedCoach()
        navigateToBacklog()

        // Hint text should NOT appear when a coach is synced
        let hintText = app.staticTexts["Starte deinen Tag unter Mein Tag"]
        XCTAssertFalse(hintText.waitForExistence(timeout: 3),
                       "Bug 102: Hint text should NOT appear when coach is synced from another device")
    }
}
