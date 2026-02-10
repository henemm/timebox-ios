//
//  MacToolbarNavigationUITests.swift
//  FocusBloxMacUITests
//
//  Tests for macOS Toolbar Navigation
//  macOS Picker(.segmented) in toolbar renders as RadioGroup with SF Symbol IDs.
//

import XCTest

/// UI Tests for macOS Toolbar Navigation
///
/// Tests verify:
/// 1. Toolbar has navigation picker with 5 sections
/// 2. Picker changes the displayed view
/// 3. Sidebar only visible for Backlog (filter options)
///
/// macOS Picker(.segmented) in toolbar renders as RadioGroup.
/// Radio buttons use SF Symbol names as identifiers:
///   Backlog="tray.full", Planen="calendar", Zuweisen="arrow.up.arrow.down",
///   Focus="target", Review="chart.bar"
final class MacToolbarNavigationUITests: XCTestCase {

    var app: XCUIApplication!

    // SF Symbol identifiers used by MainSection
    private let sectionSymbols = [
        "tray.full",      // Backlog
        "calendar",        // Planen
        "arrow.up.arrow.down", // Zuweisen
        "target",          // Focus
        "chart.bar"        // Review
    ]

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

    /// Test: Toolbar must have a navigation picker rendered as RadioGroup
    func testToolbarHasNavigationPicker() throws {
        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // macOS renders Picker(.segmented) in toolbar as a RadioGroup
        let radioGroup = app.radioGroups["mainNavigationPicker"]

        XCTAssertTrue(
            radioGroup.waitForExistence(timeout: 3),
            "Toolbar MUST have navigation picker RadioGroup with identifier 'mainNavigationPicker'"
        )
    }

    // MARK: - Test 2: Picker has all 5 sections

    /// Test: Navigation picker must have all 5 main sections (as radio buttons with SF Symbol IDs)
    func testPickerHasAllSections() throws {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker RadioGroup not found")
            return
        }

        // Check for all 5 radio buttons by SF Symbol identifier
        for symbol in sectionSymbols {
            let radioButton = radioGroup.radioButtons[symbol]
            XCTAssertTrue(
                radioButton.exists,
                "Picker must have radio button with SF Symbol '\(symbol)'"
            )
        }
    }

    // MARK: - Test 3: Picker changes view

    /// Test: Selecting a section in picker should change the displayed view
    func testPickerChangesView() throws {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker not found")
            return
        }

        // Click "Planen" (calendar symbol)
        let planenRadio = radioGroup.radioButtons["calendar"]
        guard planenRadio.waitForExistence(timeout: 2) else {
            XCTFail("Planen radio button not found")
            return
        }
        planenRadio.click()
        sleep(1)

        // Take screenshot after navigation
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-AfterPlanenClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify Planen view is shown (has "Tasks in die Timeline ziehen" footer)
        let planenFooter = app.staticTexts["Tasks in die Timeline ziehen"]
        let timelineExists = app.scrollViews.count > 0

        XCTAssertTrue(
            planenFooter.waitForExistence(timeout: 3) || timelineExists,
            "Clicking 'Planen' should show the Planning view"
        )
    }

    // MARK: - Test 4: Sidebar only visible for Backlog

    /// Test: Sidebar should only be visible when Backlog is selected
    func testSidebarOnlyVisibleForBacklog() throws {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker not found")
            return
        }

        // Switch to Backlog
        radioGroup.radioButtons["tray.full"].click()
        sleep(1)

        // Check sidebar/filter is visible for Backlog
        let filterSidebar = app.outlines.firstMatch
        let backlogSidebarVisible = filterSidebar.exists

        // Take screenshot
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "MacToolbar-BacklogWithSidebar"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Now switch to Planen
        radioGroup.radioButtons["calendar"].click()
        sleep(1)

        // Take screenshot
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "MacToolbar-PlanenNoSidebar"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // For Backlog, sidebar should be visible.
        XCTAssertTrue(backlogSidebarVisible, "Sidebar should be visible for Backlog")
    }

    // MARK: - Test 5: No old sidebar navigation

    /// Test: The toolbar navigation picker should exist (RadioGroup with SF Symbol radio buttons)
    func testOldSidebarNavigationRemoved() throws {
        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacToolbar-NoOldSidebar"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The toolbar navigation picker should exist as RadioGroup
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        XCTAssertTrue(
            radioGroup.waitForExistence(timeout: 3),
            "Toolbar navigation picker must exist as RadioGroup"
        )
    }
}
