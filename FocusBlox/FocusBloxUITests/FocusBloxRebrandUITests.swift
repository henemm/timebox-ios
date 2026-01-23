//
//  FocusBloxRebrandUITests.swift
//  TimeBoxUITests
//
//  Created by Claude on 2026-01-23.
//

import XCTest

/// UI Tests for the FocusBlox rebrand
/// These tests verify that the app displays the new "FocusBlox" name
/// EXPECTED TO FAIL in RED phase: App still shows "TimeBox"
final class FocusBloxRebrandUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Name Tests

    /// Test: Navigation bar should display "FocusBlox" as app title
    /// EXPECTED TO FAIL: App currently shows "TimeBox" or other title
    func testNavigationBarShowsFocusBloxTitle() throws {
        // The main navigation should show "FocusBlox" somewhere
        // This could be in the navigation title or a header
        let focusBloxTitle = app.staticTexts["FocusBlox"]
        let exists = focusBloxTitle.waitForExistence(timeout: 5)

        XCTAssertTrue(exists, "App should display 'FocusBlox' title somewhere in the UI")
    }

    /// Test: App should NOT display old "TimeBox" branding prominently
    /// EXPECTED TO FAIL: App currently still shows "TimeBox"
    func testOldTimeBoxBrandingNotDisplayed() throws {
        // Wait for app to fully load
        let firstElement = app.staticTexts.firstMatch
        _ = firstElement.waitForExistence(timeout: 3)

        // Check that "TimeBox" is not displayed as a prominent title
        // Note: Internal identifiers may still use TimeBox, that's OK
        let timeBoxTitle = app.navigationBars["TimeBox"]

        XCTAssertFalse(timeBoxTitle.exists, "App should not display 'TimeBox' as navigation bar title after rebrand")
    }

    // MARK: - URL Scheme Tests

    /// Test: App responds to focusblox:// URL scheme
    /// EXPECTED TO FAIL: URL scheme not yet registered
    func testFocusBloxURLSchemeRegistered() throws {
        // This test verifies the URL scheme is registered by checking
        // if the app can be launched via the scheme
        // Note: Direct URL scheme testing is limited in UI tests,
        // but we can verify the app handles it by checking for specific behavior

        // For now, we just verify the app launches and is in a good state
        // The actual URL scheme will be tested via the Info.plist check
        XCTAssertTrue(app.state == .runningForeground, "App should be running")

        // Check for any "FocusBlox" branding which indicates rebrand is complete
        let anyFocusBloxText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'FocusBlox'")).firstMatch
        XCTAssertTrue(anyFocusBloxText.waitForExistence(timeout: 5), "App should contain 'FocusBlox' text somewhere after rebrand")
    }
}
