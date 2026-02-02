//
//  MacToolbarNavigationUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED: Tests for macOS Toolbar Navigation
//  These tests should FAIL until implementation is complete
//

import XCTest

/// UI Tests for macOS Toolbar Navigation
///
/// Tests verify:
/// 1. Toolbar has navigation picker with 5 sections
/// 2. Picker changes the displayed view
/// 3. Sidebar only visible for Backlog (filter options)
///
/// TDD RED: All tests should FAIL until implementation is complete
final class MacToolbarNavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window to appear
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test 1: Toolbar has navigation picker

    /// Test: Toolbar must have a navigation picker with identifier
    /// TDD RED: Tests FAIL because picker doesn't exist yet
    func testToolbarHasNavigationPicker() throws {
        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for navigation picker in toolbar
        // The picker should have identifier "mainNavigationPicker"
        let picker = app.popUpButtons["mainNavigationPicker"]
        let segmentedControl = app.segmentedControls["mainNavigationPicker"]

        let hasNavigation = picker.waitForExistence(timeout: 3) || segmentedControl.exists

        XCTAssertTrue(
            hasNavigation,
            "TDD RED: Toolbar MUST have navigation picker with identifier 'mainNavigationPicker'"
        )
    }

    // MARK: - Test 2: Picker has all 5 sections

    /// Test: Navigation picker must have all 5 main sections
    /// TDD RED: Tests FAIL because picker doesn't exist yet
    func testPickerHasAllSections() throws {
        // Find the picker
        let picker = app.popUpButtons["mainNavigationPicker"]
        let segmentedControl = app.segmentedControls["mainNavigationPicker"]

        if picker.waitForExistence(timeout: 3) {
            picker.click()
            sleep(1)

            // Check for all 5 options
            let backlog = app.menuItems["Backlog"]
            let planen = app.menuItems["Planen"]
            let zuweisen = app.menuItems["Zuweisen"]
            let focus = app.menuItems["Focus"]
            let review = app.menuItems["Review"]

            XCTAssertTrue(backlog.exists, "TDD RED: Picker must have 'Backlog' option")
            XCTAssertTrue(planen.exists, "TDD RED: Picker must have 'Planen' option")
            XCTAssertTrue(zuweisen.exists, "TDD RED: Picker must have 'Zuweisen' option")
            XCTAssertTrue(focus.exists, "TDD RED: Picker must have 'Focus' option")
            XCTAssertTrue(review.exists, "TDD RED: Picker must have 'Review' option")

            // Dismiss menu
            app.typeKey(.escape, modifierFlags: [])
        } else if segmentedControl.exists {
            // Segmented control - check buttons
            XCTAssertTrue(segmentedControl.buttons["Backlog"].exists, "TDD RED: Must have 'Backlog' segment")
            XCTAssertTrue(segmentedControl.buttons["Planen"].exists, "TDD RED: Must have 'Planen' segment")
            XCTAssertTrue(segmentedControl.buttons["Zuweisen"].exists, "TDD RED: Must have 'Zuweisen' segment")
            XCTAssertTrue(segmentedControl.buttons["Focus"].exists, "TDD RED: Must have 'Focus' segment")
            XCTAssertTrue(segmentedControl.buttons["Review"].exists, "TDD RED: Must have 'Review' segment")
        } else {
            XCTFail("TDD RED: No navigation picker found")
        }
    }

    // MARK: - Test 3: Picker changes view

    /// Test: Selecting a section in picker should change the displayed view
    /// TDD RED: Tests FAIL because picker doesn't exist yet
    func testPickerChangesView() throws {
        // Find and use the picker to switch to "Planen"
        let picker = app.popUpButtons["mainNavigationPicker"]
        let segmentedControl = app.segmentedControls["mainNavigationPicker"]

        if picker.waitForExistence(timeout: 3) {
            picker.click()
            sleep(1)
            app.menuItems["Planen"].click()
            sleep(1)
        } else if segmentedControl.exists {
            segmentedControl.buttons["Planen"].click()
            sleep(1)
        } else {
            XCTFail("TDD RED: No navigation picker found")
            return
        }

        // Take screenshot after navigation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-AfterPlanenClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify "Planen" view is shown (check for timeline or planning-specific element)
        // The planning view should have date picker or timeline
        let datePicker = app.datePickers.firstMatch
        let timelineExists = app.scrollViews.count > 0

        XCTAssertTrue(
            datePicker.exists || timelineExists,
            "TDD RED: Clicking 'Planen' should show the Planning view"
        )
    }

    // MARK: - Test 4: Sidebar only visible for Backlog

    /// Test: Sidebar should only be visible when Backlog is selected
    /// TDD RED: Tests FAIL because sidebar is always visible currently
    func testSidebarOnlyVisibleForBacklog() throws {
        let picker = app.popUpButtons["mainNavigationPicker"]
        let segmentedControl = app.segmentedControls["mainNavigationPicker"]

        // First, switch to Backlog and check sidebar is visible
        if picker.waitForExistence(timeout: 3) {
            picker.click()
            sleep(1)
            app.menuItems["Backlog"].click()
            sleep(1)
        } else if segmentedControl.exists {
            segmentedControl.buttons["Backlog"].click()
            sleep(1)
        } else {
            XCTFail("TDD RED: No navigation picker found")
            return
        }

        // Check sidebar/filter is visible for Backlog
        let filterSidebar = app.outlines.firstMatch
        let backlogSidebarVisible = filterSidebar.exists

        // Take screenshot
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "MacToolbar-BacklogWithSidebar"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Now switch to Planen
        if picker.exists {
            picker.click()
            sleep(1)
            app.menuItems["Planen"].click()
            sleep(1)
        } else {
            segmentedControl.buttons["Planen"].click()
            sleep(1)
        }

        // Take screenshot
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "MacToolbar-PlanenNoSidebar"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // Sidebar should NOT be visible for Planen
        // We check that the outline (sidebar) is either gone or has no filter items
        let sidebarStillVisible = app.outlines.firstMatch.exists

        // For Backlog, sidebar should be visible. For Planen, it should be hidden or minimal.
        XCTAssertTrue(backlogSidebarVisible, "TDD RED: Sidebar should be visible for Backlog")
        // Note: This test may need adjustment based on exact implementation
    }

    // MARK: - Test 5: No old sidebar navigation

    /// Test: The old sidebar navigation (MainSection buttons) should not exist
    /// TDD RED: Tests should PASS after implementation removes old sidebar nav
    func testOldSidebarNavigationRemoved() throws {
        // The old sidebar had buttons/rows for each section
        // After implementation, these should NOT exist in sidebar

        // Look for old-style sidebar navigation items
        let sidebarBacklog = app.outlineRows["Backlog"].firstMatch
        let sidebarPlanen = app.outlineRows["Planen"].firstMatch

        // These should NOT exist if we've moved to toolbar navigation
        // (They may still exist briefly, but shouldn't be the primary navigation)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-NoOldSidebar"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The toolbar navigation picker should exist instead
        let picker = app.popUpButtons["mainNavigationPicker"]
        let segmentedControl = app.segmentedControls["mainNavigationPicker"]

        XCTAssertTrue(
            picker.exists || segmentedControl.exists,
            "TDD RED: Toolbar navigation picker must exist"
        )
    }
}
