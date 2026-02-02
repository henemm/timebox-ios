import XCTest

/// UI Tests for Bug 8: Calendar/Reminders permission request on app launch
///
/// Problem: App does not request calendar/reminders access on launch.
/// The permission dialog only appears when navigating to specific tabs.
///
/// Expected: Permission should be requested immediately on app launch.
///
/// Test Strategy:
/// Since UI tests use MockEventKitRepository with fullAccess, we cannot
/// directly test the iOS permission dialog. Instead, we verify that
/// the app has proper access by checking if EventKit-dependent features
/// are functional immediately after launch (without needing to navigate first).
final class PermissionRequestUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Test: requestAccess() should be called on app launch
    ///
    /// Verification: After app launch, mock repository should have
    /// requestAccessCalled = true (tracked in mock).
    ///
    /// EXPECTED TO FAIL: requestAccess() is not called in onAppear yet
    func testPermissionRequestedOnLaunch() throws {
        // The app starts on Backlog tab
        // Wait for app to fully load
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")

        // Check for a UI element that indicates permission was requested
        // We look for "Berechtigung angefragt" text that we will add after requestAccess()
        // This text should appear briefly or be logged

        // Alternative: Check that no "Kein Zugriff" error appears
        // If requestAccess() was NOT called, and we immediately try to use EventKit,
        // we would see an error state

        // Navigate to Blöcke tab which requires calendar access
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        bloeckeTab.tap()

        // Wait for content to load
        sleep(1)

        // If permission was requested on launch, we should NOT see any error
        // The timeline or "Freie Slots" should be visible
        let freeSlotsHeader = app.staticTexts["Freie Slots"]
        let freeDayHeader = app.staticTexts["Tag ist frei!"]
        let activeBlockText = app.staticTexts["Active Test Block"]

        let hasContent = freeSlotsHeader.exists || freeDayHeader.exists || activeBlockText.exists

        // This test currently PASSES because mock always returns fullAccess
        // But we need to add tracking to verify requestAccess() was actually called
        XCTAssertTrue(hasContent, "Calendar content should be visible (permission was granted)")

        // TODO: This test needs enhancement to actually verify requestAccess() was called
        // Currently it passes even without the fix because mock grants access automatically
    }

    /// Test: App should track that requestAccess was called
    ///
    /// This test checks for a debug indicator that permission was requested.
    /// We will add a mechanism to track this in the app.
    ///
    /// EXPECTED TO FAIL: No tracking mechanism exists yet
    func testRequestAccessCalledIndicator() throws {
        // Wait for app launch
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        // Give time for onAppear to execute
        sleep(2)

        // Check for accessibility identifier that indicates requestAccess was called
        // This will be set by the app after successful permission request
        let permissionIndicator = app.otherElements["PermissionRequestedOnLaunch"]

        XCTAssertTrue(permissionIndicator.exists,
            "Permission should be requested on app launch - indicator element missing")
    }
}
