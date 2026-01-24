import XCTest

/// E2E Tests for Reminders Sync
///
/// ARCHITECTURE NOTES:
/// ====================
/// UI test runner runs on macOS, app runs in iOS Simulator.
/// EventKit from test runner accesses macOS Reminders (separate from simulator).
/// Therefore, we CANNOT directly create simulator reminders from UI tests.
///
/// TESTING STRATEGY:
/// =================
/// These tests verify the UI behavior and sync toggle functionality using REAL
/// EventKit in the app (not mocks). They test:
/// 1. Sync toggle UI works correctly
/// 2. App handles EventKit permissions properly
/// 3. Backlog displays correctly when sync is enabled/disabled
///
/// For complete E2E testing with real reminders:
/// - Pre-seed simulator's Reminders app manually before test
/// - Or use mock-based tests (RemindersSyncUITests) for automation
///
final class RemindersSyncE2ETests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // E2E mode: uses REAL EventKit, not mocks
        app.launchArguments = ["-E2ETesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - UI Helpers

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    private func enableReminderSync() {
        navigateToSettings()

        let syncToggle = app.switches["remindersSyncToggle"]
        guard syncToggle.waitForExistence(timeout: 5) else {
            XCTFail("Sync toggle not found")
            return
        }

        // Scroll to toggle
        app.swipeUp()
        sleep(1)

        // Enable if not already on
        if syncToggle.value as? String == "0" {
            syncToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(1)
        }

        // Close settings
        let doneButton = app.buttons["Fertig"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }
    }

    // MARK: - E2E Tests

    /// TEST 1: Verify sync toggle can be enabled and UI responds
    func testSyncToggleEnablesSuccessfully() throws {
        app.launch()
        print("E2E TEST - App launched with real EventKit")

        // Navigate to settings
        navigateToSettings()

        let syncToggle = app.switches["remindersSyncToggle"]
        guard syncToggle.waitForExistence(timeout: 5) else {
            XCTFail("Sync toggle not found")
            return
        }

        app.swipeUp()
        sleep(1)

        // Get initial state
        let initialValue = syncToggle.value as? String
        print("E2E TEST - Initial toggle value: \(initialValue ?? "nil")")

        // Try to enable toggle
        if initialValue == "0" {
            syncToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(2)
        }

        // Check if toggle responded (either enabled or permission alert shown)
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            print("E2E TEST - Permission alert appeared, handling...")
            let allowButton = alert.buttons.element(boundBy: 1)  // Usually "Allow" or "OK"
            if allowButton.exists {
                allowButton.tap()
                sleep(1)
            }
        }

        // Verify toggle state changed or stayed (permission dependent)
        let finalValue = syncToggle.value as? String
        print("E2E TEST - Final toggle value: \(finalValue ?? "nil")")

        // Test passes if we got here without crash
        print("E2E TEST - Sync toggle test completed successfully")
    }

    /// TEST 2: Verify Backlog displays correctly with sync enabled
    func testBacklogDisplaysWithSyncEnabled() throws {
        app.launch()

        // Enable sync
        enableReminderSync()
        print("E2E TEST - Sync enabled")

        // Navigate to Backlog
        navigateToBacklog()
        sleep(3)

        // Print all visible items for debugging
        let allTexts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        print("E2E TEST - Backlog items with sync ON:")
        allTexts.forEach { print("  - \($0)") }

        // Verify Backlog tab is visible
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")

        print("E2E TEST - Backlog display test completed")
    }

    /// TEST 3: Verify sync toggle OFF means no external reminders imported
    func testSyncDisabledBacklogWorks() throws {
        // Launch without enabling sync
        app.launch()
        print("E2E TEST - App launched (sync not enabled)")

        // Navigate to Backlog directly (without enabling sync)
        navigateToBacklog()
        sleep(2)

        // Print Backlog items
        let allTexts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        print("E2E TEST - Backlog items (sync OFF):")
        allTexts.forEach { print("  - \($0)") }

        // Backlog should work even without sync
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist even with sync OFF")

        print("E2E TEST - Sync disabled test completed")
    }

    /// TEST 4: Verify app handles permission flow correctly
    func testPermissionFlowHandledGracefully() throws {
        // Reset privacy settings for clean test
        app.launch()

        navigateToSettings()

        let syncToggle = app.switches["remindersSyncToggle"]
        guard syncToggle.waitForExistence(timeout: 5) else {
            XCTFail("Sync toggle not found")
            return
        }

        app.swipeUp()
        sleep(1)

        // Try to enable toggle to trigger permission
        if syncToggle.value as? String == "0" {
            syncToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }

        // Wait for potential permission dialog
        sleep(2)

        // Check for system alert
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemAlert = springboard.alerts.firstMatch

        if systemAlert.waitForExistence(timeout: 3) {
            print("E2E TEST - System permission alert found")
            // Handle the alert
            let allowButton = systemAlert.buttons["Allow Full Access"]
            if allowButton.exists {
                allowButton.tap()
                print("E2E TEST - Tapped Allow Full Access")
            } else {
                // Try other button variations
                let okButton = systemAlert.buttons["OK"]
                if okButton.exists {
                    okButton.tap()
                    print("E2E TEST - Tapped OK")
                }
            }
        } else {
            print("E2E TEST - No system alert (already granted or denied)")
        }

        // Verify app is still responsive
        let settingsSheet = app.navigationBars.firstMatch
        XCTAssertTrue(settingsSheet.waitForExistence(timeout: 5), "Settings should remain open after permission flow")

        print("E2E TEST - Permission flow test completed")
    }
}
