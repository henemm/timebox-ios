import XCTest

/// Tests that all tab labels use consistent English naming
/// Bug 67: Tab labels were German ("Blöcke", "Fokus", "Rückblick")
/// Expected: English labels ("Blox", "Focus", "Review")
final class TabLabelsEnglishUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// GIVEN: App is launched
    /// WHEN: Tab bar is displayed
    /// THEN: "Blox" tab should exist (not "Blöcke")
    func testBloxTabLabelIsEnglish() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        let bloxTab = tabBar.buttons["Blox"]
        XCTAssertTrue(bloxTab.exists, "Tab should be labeled 'Blox' not 'Blöcke'")
    }

    /// GIVEN: App is launched
    /// WHEN: Tab bar is displayed
    /// THEN: "Focus" tab should exist (not "Fokus")
    func testFocusTabLabelIsEnglish() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        let focusTab = tabBar.buttons["Focus"]
        XCTAssertTrue(focusTab.exists, "Tab should be labeled 'Focus' not 'Fokus'")
    }

    /// GIVEN: App is launched
    /// WHEN: Tab bar is displayed
    /// THEN: "Review" tab should exist (not "Rückblick")
    func testReviewTabLabelIsEnglish() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        let reviewTab = tabBar.buttons["Review"]
        XCTAssertTrue(reviewTab.exists, "Tab should be labeled 'Review' not 'Rückblick'")
    }

    /// GIVEN: App is launched
    /// WHEN: Tab bar is displayed
    /// THEN: German labels should NOT exist
    func testGermanLabelsDoNotExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        XCTAssertFalse(tabBar.buttons["Blöcke"].exists, "'Blöcke' should not exist")
        XCTAssertFalse(tabBar.buttons["Fokus"].exists, "'Fokus' should not exist")
        XCTAssertFalse(tabBar.buttons["Rückblick"].exists, "'Rückblick' should not exist")
    }
}
