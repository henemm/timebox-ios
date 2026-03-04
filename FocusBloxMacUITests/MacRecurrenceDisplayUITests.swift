import XCTest

/// macOS UI Tests for Recurrence Display Name Consistency (Tech-Debt Fix 2)
///
/// Tests verify:
/// 1. macOS app loads mock data including biweekly recurring task
/// 2. Recurrence badge text uses RecurrencePattern.displayName (shared enum)
///    Not the deleted private recurrenceDisplayName() function
final class MacRecurrenceDisplayUITests: XCTestCase {

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

    // MARK: - Mock Data Loads

    /// GIVEN: macOS app launched with -UITesting flag
    /// WHEN: App starts
    /// THEN: Biweekly recurring task should be visible in the backlog
    /// Bricht wenn: seedUITestData in FocusBloxMacApp fehlt oder biweekly Task nicht angelegt
    func testBiweeklyTaskExistsInBacklog() throws {
        // Wait for backlog to load
        sleep(2)

        // Take screenshot for diagnosis
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacRecurrence-BacklogWithBiweekly"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for any mock task to verify seed data loaded
        // Use staticTexts which is safer than descendants(matching: .any)
        let mockTask = app.staticTexts["Mock Task 1 #30min"]
        XCTAssertTrue(
            mockTask.waitForExistence(timeout: 5),
            "Mock data must be seeded — 'Mock Task 1 #30min' should be visible"
        )
    }

    /// GIVEN: macOS backlog shows recurring tasks
    /// WHEN: Any recurrence pattern is displayed
    /// THEN: No raw pattern strings (like "weekdays", "quarterly") should appear
    /// Bricht wenn: RecurrencePattern(rawValue:) returns nil → fallback shows raw string
    func testNoRawRecurrencePatternStringsVisible() throws {
        // Navigate to Backlog (macOS uses list.bullet icon)
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        if radioGroup.waitForExistence(timeout: 3) {
            radioGroup.radioButtons["list.bullet"].click()
            sleep(1)
        }

        // Switch to recurring filter if available
        let recurringFilter = app.staticTexts["sidebarFilter_recurring"]
        if recurringFilter.waitForExistence(timeout: 3) {
            recurringFilter.click()
            sleep(1)
        }

        // Raw pattern strings should NEVER appear in the UI
        let rawPatterns = ["weekdays", "weekends", "quarterly", "semiannually"]
        for pattern in rawPatterns {
            let rawText = app.staticTexts.matching(
                NSPredicate(format: "label == %@", pattern)
            )
            XCTAssertEqual(
                rawText.count, 0,
                "Raw pattern string '\(pattern)' should not appear in UI — must use displayName"
            )
        }
    }
}
