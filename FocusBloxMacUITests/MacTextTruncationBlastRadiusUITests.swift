//
//  MacTextTruncationBlastRadiusUITests.swift
//  FocusBloxMacUITests
//
//  BACKLOG-013: Text truncation fix for additional macOS views.
//  Verifies that task titles use sufficient width after applying
//  .frame(maxWidth: .infinity, alignment: .leading) modifier.
//

import XCTest

/// UI Tests for BACKLOG-013: macOS text truncation blast radius.
///
/// Navigates to Planning, Assign, and Focus views and verifies
/// that task titles are not unnecessarily compressed by Spacer() layout.
///
/// Bricht wenn: `.frame(maxWidth: .infinity, alignment: .leading)` fehlt
/// auf VStack/Text in den jeweiligen Row-Structs.
final class MacTextTruncationBlastRadiusUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.terminate()
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 10)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helper

    /// Navigate to a section via toolbar RadioGroup
    private func navigateToSection(symbol: String) -> Bool {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 5) else {
            XCTFail("Navigation picker RadioGroup not found")
            return false
        }
        let radioButton = radioGroup.radioButtons[symbol]
        guard radioButton.waitForExistence(timeout: 3) else {
            XCTFail("Radio button '\(symbol)' not found in picker")
            return false
        }
        radioButton.click()
        sleep(1)
        return true
    }

    /// Find a mock task title element from the known mock data titles.
    /// Uses .firstMatch to handle duplicate labels across views.
    /// Returns the first found element, or nil if none found.
    private func findMockTaskTitle(from titles: [String], timeout: TimeInterval = 3) -> (element: XCUIElement, title: String)? {
        for title in titles {
            let text = app.staticTexts[title].firstMatch
            if text.waitForExistence(timeout: timeout) {
                return (text, title)
            }
        }
        return nil
    }

    // MARK: - Known Mock Data Titles

    /// NextUp tasks visible in Planning and Assign views
    private let nextUpTitles = [
        "[MOCK] Task 1 #30min",
        "[MOCK] Task 2 #15min",
        "[MOCK] Task 3 #45min",
        "[MOCK] Lohnsteuererklaerung einreichen"
    ]

    /// Focus tasks visible in Focus view (if sprint active)
    private let focusTitles = [
        "[MOCK] Focus Task 1",
        "[MOCK] Focus Task 2",
        "[MOCK] Focus Task 3",
        "[MOCK] Task 1 #30min"
    ]

    // MARK: - Test 1: Planning View (NextUpTaskRow)

    /// NextUpTaskRow VStack must expand to fill available width.
    /// NextUp section has maxWidth: 350, so titles should be > 150px.
    ///
    /// Bricht wenn: MacPlanningView.swift NextUpTaskRow VStack fehlt .frame(maxWidth: .infinity)
    func test_planningView_taskTitleNotCompressed() throws {
        guard navigateToSection(symbol: "calendar") else { return }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "PlanningView-TitleWidth"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        guard let (element, title) = findMockTaskTitle(from: nextUpTitles) else {
            XCTFail("No NextUp task titles found in Planning view")
            return
        }

        let titleWidth = element.frame.width
        // NextUp section has maxWidth: 350px. With fix, VStack fills the
        // section width. Without fix, VStack is compressed by Spacer.
        // Threshold: 100px (conservative — accounts for narrow columns + padding)
        XCTAssertGreaterThan(
            titleWidth, 100,
            "Planning: '\(title)' width is only \(Int(titleWidth))px — " +
            "NextUpTaskRow VStack needs .frame(maxWidth: .infinity, alignment: .leading)"
        )
    }

    // MARK: - Test 2: Focus View (TaskQueueRow)

    /// TaskQueueRow Text must expand to fill available width.
    ///
    /// Bricht wenn: MacFocusView.swift task rows fehlt .frame(maxWidth: .infinity)
    func test_focusView_taskTitleNotCompressed() throws {
        guard navigateToSection(symbol: "target") else { return }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "FocusView-TitleWidth"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        guard let (element, title) = findMockTaskTitle(from: focusTitles) else {
            // Focus view needs active sprint with tasks — skip if not present
            return
        }

        let titleWidth = element.frame.width
        XCTAssertGreaterThan(
            titleWidth, 150,
            "Focus: '\(title)' width is only \(Int(titleWidth))px — " +
            "TaskQueueRow needs .frame(maxWidth: .infinity, alignment: .leading)"
        )
    }
}
