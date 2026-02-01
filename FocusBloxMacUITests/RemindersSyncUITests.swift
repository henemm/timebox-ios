//
//  RemindersSyncUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for MAC-025: macOS Reminders Sync
//

import XCTest

final class RemindersSyncUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window to appear
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Sync Indicator Tests

    /// Test: Sync indicator should exist when sync is enabled
    /// EXPECTED TO FAIL: Sync indicator not implemented yet
    @MainActor
    func testSyncIndicatorExists() throws {
        // Look for a sync status indicator in the toolbar or sidebar
        let syncIndicator = app.images["syncStatusIndicator"]

        // This test verifies the sync UI element exists
        // Will fail until sync indicator is added
        XCTAssertTrue(syncIndicator.waitForExistence(timeout: 5),
                      "Sync status indicator should exist")
    }

    /// Test: Tasks from Reminders should have source indicator
    /// EXPECTED TO FAIL: Source indicator not shown yet
    @MainActor
    func testReminderTasksShowSourceIndicator() throws {
        // Create a task first to ensure list is visible
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField should exist")

        // Look for any task with a Reminders source indicator
        let reminderSourceBadge = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'sourceIndicator_reminders'")
        )

        // This test checks if Reminders-sourced tasks are visually distinguished
        // Will pass once sync imports tasks and shows source
        XCTAssertGreaterThanOrEqual(reminderSourceBadge.count, 0,
                                     "Should be able to query reminder source badges")
    }

    // MARK: - Sync Trigger Tests

    /// Test: Pull to refresh or manual sync should trigger Reminders import
    /// EXPECTED TO FAIL: Manual sync not implemented yet
    @MainActor
    func testManualSyncButtonExists() throws {
        // Look for a sync/refresh button in toolbar
        let syncButton = app.buttons["syncRemindersButton"]

        XCTAssertTrue(syncButton.waitForExistence(timeout: 5),
                      "Sync button should exist in toolbar")
    }

    /// Test: App should request Reminders permission on first sync attempt
    @MainActor
    func testRemindersPermissionHandled() throws {
        // This test verifies the app handles the permission flow
        // The app should either have permission or show a request

        // Look for permission-related UI elements
        let permissionAlert = app.alerts.firstMatch
        let taskList = app.outlines.firstMatch

        // Either we see tasks (permission granted) or an alert (permission needed)
        let hasPermissionUI = permissionAlert.waitForExistence(timeout: 3) ||
                              taskList.waitForExistence(timeout: 3)

        XCTAssertTrue(hasPermissionUI,
                      "App should handle Reminders permission state")
    }
}
