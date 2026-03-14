//
//  MacCoachSettingsUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED: Tests for Monster Coach settings tab in macOS preferences.
//  These tests MUST FAIL until the Coach tab is implemented in MacSettingsView.
//

import XCTest

final class MacCoachSettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func openSettings() {
        // Open macOS Settings window via keyboard shortcut Cmd+,
        app.typeKey(",", modifierFlags: .command)
        // Wait for settings window to appear
        let settingsWindow = app.windows["Settings"]
        if !settingsWindow.waitForExistence(timeout: 3) {
            // Fallback: try via menu bar
            app.menuItems["Settings…"].tap()
        }
    }

    private func relaunchWithCoachMode(nudgesEnabled: Bool = true, eveningEnabled: Bool = true) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1",
            "-coachDailyNudgesEnabled", nudgesEnabled ? "1" : "0",
            "-coachEveningReminderEnabled", eveningEnabled ? "1" : "0"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    // MARK: - Test 1: Coach Tab exists

    /// Verhalten: Settings hat einen "Monster Coach" Tab.
    /// Bricht wenn: coachTab nicht in MacSettingsView.TabView existiert.
    func test_settingsHasCoachTab() throws {
        openSettings()

        // macOS TabView renders tabs — look for the Monster Coach tab
        let coachTab = app.buttons["Monster Coach"]
        // Also try as tab group item
        if !coachTab.waitForExistence(timeout: 3) {
            let tabGroup = app.tabGroups.firstMatch
            let coachTabInGroup = tabGroup.buttons["Monster Coach"]
            XCTAssertTrue(coachTabInGroup.waitForExistence(timeout: 3),
                          "Settings should have a 'Monster Coach' tab")
            return
        }
        XCTAssertTrue(coachTab.exists, "Settings should have a 'Monster Coach' tab")
    }

    // MARK: - Test 2: Coach master toggle visible

    /// Verhalten: Coach-Tab zeigt den Master-Toggle "Monster Coach".
    /// Bricht wenn: Toggle oder accessibilityIdentifier fehlt in MacSettingsView.
    func test_coachTab_showsMasterToggle() throws {
        openSettings()

        // Navigate to Coach tab
        let coachTab = app.buttons["Monster Coach"]
        guard coachTab.waitForExistence(timeout: 3) else {
            XCTFail("Monster Coach tab not found")
            return
        }
        coachTab.tap()

        let toggle = app.switches["coachModeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Coach tab should show coachModeToggle")
    }

    // MARK: - Test 3: Sub-settings hidden when coach off

    /// Verhalten: Unter-Settings unsichtbar wenn Coach-Modus aus.
    /// Bricht wenn: Toggles immer sichtbar statt bedingt.
    func test_coachSubSettings_hiddenWhenCoachOff() throws {
        openSettings()

        let coachTab = app.buttons["Monster Coach"]
        guard coachTab.waitForExistence(timeout: 3) else {
            XCTFail("Monster Coach tab not found")
            return
        }
        coachTab.tap()

        // Coach mode is off by default — sub-settings should be hidden
        XCTAssertFalse(app.switches["intentionReminderToggle"].exists,
                       "Intention reminder toggle should be hidden when coach off")
        XCTAssertFalse(app.switches["coachDailyNudgesToggle"].exists,
                       "Nudges toggle should be hidden when coach off")
        XCTAssertFalse(app.switches["coachEveningReminderToggle"].exists,
                       "Evening reminder toggle should be hidden when coach off")
    }

    // MARK: - Test 4: Sub-settings visible when coach on

    /// Verhalten: Alle 3 Unter-Toggles sichtbar wenn Coach-Modus an.
    /// Bricht wenn: Conditional visibility nicht implementiert.
    func test_coachSubSettings_visibleWhenCoachOn() throws {
        relaunchWithCoachMode()
        openSettings()

        let coachTab = app.buttons["Monster Coach"]
        guard coachTab.waitForExistence(timeout: 3) else {
            XCTFail("Monster Coach tab not found")
            return
        }
        coachTab.tap()

        XCTAssertTrue(app.switches["intentionReminderToggle"].waitForExistence(timeout: 3),
                      "Intention reminder toggle should be visible when coach on")
        XCTAssertTrue(app.switches["coachDailyNudgesToggle"].waitForExistence(timeout: 3),
                      "Nudges toggle should be visible when coach on")
        XCTAssertTrue(app.switches["coachEveningReminderToggle"].waitForExistence(timeout: 3),
                      "Evening reminder toggle should be visible when coach on")
    }
}
