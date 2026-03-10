//
//  MacTextTruncationUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for Bug 86: macOS task title truncation.
//  Verifies that long task titles use sufficient width and are not
//  unnecessarily compressed by the HStack layout.
//

import XCTest

/// UI Tests for macOS text truncation fix.
///
/// Tests verify:
/// 1. Long task title text element has sufficient width (not squeezed by Spacer)
/// 2. Sidebar filter labels with badges have sufficient width
final class MacTextTruncationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        // Terminate any lingering instance before launching fresh
        app.terminate()
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 10)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Test 1: Task title VStack uses majority of row width

    func test_taskTitleWidth_notCompressedByLayout() throws {
        // Mock data has a backlog task with long title + ALL badges (tags, recurrence,
        // category, duration, due date). This is the worst case for title compression.
        // With the bug: VStack has no .frame(maxWidth: .infinity), so the title
        // gets compressed by the wide metadataRow HStack and truncated with "…".
        // After fix: VStack expands to fill available width.

        let longTitle = "[MOCK] Lohnsteuererklaerung einreichen"
        let titleText = app.staticTexts[longTitle]
        guard titleText.waitForExistence(timeout: 8) else {
            XCTFail("Could not find '\(longTitle)' task title in backlog")
            return
        }

        let titleWidth = titleText.frame.width

        // This title needs ~380px at system font to display fully.
        // With the bug: metadataRow badges (all fixedSize) + Spacer compress VStack,
        // title frame is ~150-250px → truncated with "…".
        // After fix: VStack fills available width, title gets 350px+.
        XCTAssertGreaterThan(
            titleWidth, 300,
            "Task title width is only \(Int(titleWidth))px — title is being compressed by badges. " +
            "VStack needs .frame(maxWidth: .infinity, alignment: .leading)"
        )
    }

    // MARK: - Test 2: Sidebar label width is not overly compressed

    func test_sidebarFilterLabel_hasSufficientWidth() throws {
        // Sidebar labels "Überfällig", "Wiederkehrend" are inside HStack with badge.
        // With the bug: sidebar is too narrow, labels show "Überf…", "Wiede…".
        // Note: SwiftUI exposes full text in accessibility even when visually truncated,
        // so we check the frame WIDTH of the label instead.

        // Find the "Wiederkehrend" label — longest sidebar label, most likely to truncate
        let label = app.staticTexts["Wiederkehrend"]
        guard label.waitForExistence(timeout: 5) else {
            // If mock data has no recurring tasks, label might not show count/be hidden.
            // Fall back to "Überfällig"
            let fallback = app.staticTexts["Überfällig"]
            guard fallback.waitForExistence(timeout: 3) else {
                XCTFail("No sidebar filter labels found")
                return
            }
            // "Überfällig" needs ~85px at system font. If < 60px, it's truncated.
            XCTAssertGreaterThan(
                fallback.frame.width, 60,
                "Sidebar label 'Überfällig' width is only \(Int(fallback.frame.width))px — label is truncated"
            )
            return
        }

        // "Wiederkehrend" needs ~110px at system font. If < 80px, it's truncated.
        XCTAssertGreaterThan(
            label.frame.width, 80,
            "Sidebar label 'Wiederkehrend' width is only \(Int(label.frame.width))px — label is truncated"
        )
    }
}
