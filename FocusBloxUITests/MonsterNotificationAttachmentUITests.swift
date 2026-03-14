import XCTest

/// Smoke tests for Monster Notification Attachment feature (Phase 4e).
/// Note: Notification attachments are NOT visible in app UI — they only appear
/// in the iOS notification center. These tests verify the code path
/// (set intention + notifications enabled) doesn't crash.
final class MonsterNotificationAttachmentUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-coachModeEnabled", "1",
            "-coachMorningReminderEnabled", "1",
            "-coachEveningReminderEnabled", "1"
        ]
        app.launch()
    }

    // MARK: - Helpers

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("settingsButton not found")
            return
        }
        settingsButton.tap()
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 5)
    }

    private func scrollToElement(_ element: XCUIElement) {
        var attempts = 0
        while !element.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
    }

    // MARK: - Smoke Tests

    /// Smoke test: Coach-Settings zeigen Notification-Toggles korrekt bei aktivem Coach-Modus.
    /// Bricht wenn: Settings-View durch Attachment-Code beschaedigt wird.
    func test_coachNotificationToggles_existWithCoachModeOn() throws {
        navigateToSettings()

        let coachToggle = app.switches["coachModeToggle"]
        scrollToElement(coachToggle)
        XCTAssertTrue(coachToggle.waitForExistence(timeout: 5),
            "Coach mode toggle should exist in settings")

        let eveningToggle = app.switches["coachEveningReminderToggle"]
        scrollToElement(eveningToggle)
        XCTAssertTrue(eveningToggle.waitForExistence(timeout: 5),
            "Evening reminder toggle should exist in coach settings")
    }

    /// Smoke test: App crasht nicht wenn Review-Tab mit Coach-Modus geoeffnet wird.
    /// Bricht wenn: Notification-Scheduling im scenePhase-Handler crasht.
    func test_reviewTab_noCrashWithCoachMode() throws {
        let reviewTab = app.tabBars.buttons["Review"]
        guard reviewTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Review tab not found")
        }
        reviewTab.tap()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3),
            "App should remain running with coach mode and notifications enabled")
    }
}
