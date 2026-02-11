//
//  MacEventCategoryUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for macOS Calendar Event Category Assignment + Review Integration
//  TDD RED: Tests FAIL because EventBlockView has no tap handler and Review doesn't include events
//

import XCTest

/// UI Tests for macOS Event Category Assignment and Review Integration
///
/// Tests verify:
/// 1. Tap on calendar event in timeline opens category sheet
/// 2. Category selection updates event and shows color stripe
/// 3. Review includes categorized calendar events in stats
///
/// TDD RED: All tests should FAIL until implementation
final class MacEventCategoryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to Planen tab via radio group
    private func navigateToPlanning() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        if radioGroup.waitForExistence(timeout: 3) {
            let planenRadio = radioGroup.radioButtons["calendar"]
            if planenRadio.waitForExistence(timeout: 2) {
                planenRadio.click()
                sleep(1)
            }
        }
    }

    /// Navigate to Review tab
    private func navigateToReview() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        if radioGroup.waitForExistence(timeout: 3) {
            let reviewRadio = radioGroup.radioButtons["chart.bar"]
            if reviewRadio.waitForExistence(timeout: 2) {
                reviewRadio.click()
                sleep(1)
            }
        }
    }

    // MARK: - Test 1: Calendar event has accessibility identifier

    /// GIVEN: macOS timeline with calendar events
    /// WHEN: Looking for event elements
    /// THEN: Events should have accessibilityIdentifier "calendarEvent_{id}"
    /// TDD RED: EventBlockView has no accessibilityIdentifier
    func testCalendarEventHasAccessibilityIdentifier() throws {
        navigateToPlanning()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacTimeline-EventIdentifier"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for calendar event with identifier pattern
        let calendarEvent = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'calendarEvent_'")
        ).firstMatch

        XCTAssertTrue(
            calendarEvent.waitForExistence(timeout: 5),
            "TDD RED: Calendar event MUST have identifier 'calendarEvent_{id}'"
        )
    }

    // MARK: - Test 2: Tap on event opens category sheet

    /// GIVEN: Calendar event in macOS timeline
    /// WHEN: User clicks on event
    /// THEN: Category selection sheet opens with 5 categories
    /// TDD RED: EventBlockView has no onTapGesture
    func testTapEventOpensCategorySheet() throws {
        navigateToPlanning()

        // Find a calendar event
        let calendarEvent = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'calendarEvent_'")
        ).firstMatch

        guard calendarEvent.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: No calendar event found in timeline")
            return
        }

        calendarEvent.click()
        sleep(1)

        // Take screenshot after click
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacTimeline-AfterEventClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: Category sheet should appear with "Kategorie wählen" title
        let sheetTitle = app.staticTexts["Kategorie wählen"]
        XCTAssertTrue(
            sheetTitle.waitForExistence(timeout: 3),
            "TDD RED: Clicking event MUST open category sheet with title 'Kategorie wählen'"
        )
    }

    // MARK: - Test 3: Category sheet shows all 5 categories

    /// GIVEN: Category sheet is open
    /// WHEN: Looking at options
    /// THEN: All 5 categories are visible (Earn, Essentials, Self Care, Learn, Social)
    /// TDD RED: MacEventCategorySheet doesn't exist yet
    func testCategorySheetShowsAllCategories() throws {
        navigateToPlanning()

        // Find and click a calendar event
        let calendarEvent = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'calendarEvent_'")
        ).firstMatch

        guard calendarEvent.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: No calendar event found")
            return
        }

        calendarEvent.click()
        sleep(1)

        // Verify all 5 category options exist
        let incomeOption = app.buttons["categoryOption_income"]
        let maintenanceOption = app.buttons["categoryOption_maintenance"]
        let rechargeOption = app.buttons["categoryOption_recharge"]
        let learningOption = app.buttons["categoryOption_learning"]
        let socialOption = app.buttons["categoryOption_giving_back"]

        XCTAssertTrue(incomeOption.waitForExistence(timeout: 3), "TDD RED: 'Earn' category option missing")
        XCTAssertTrue(maintenanceOption.exists, "TDD RED: 'Essentials' category option missing")
        XCTAssertTrue(rechargeOption.exists, "TDD RED: 'Self Care' category option missing")
        XCTAssertTrue(learningOption.exists, "TDD RED: 'Learn' category option missing")
        XCTAssertTrue(socialOption.exists, "TDD RED: 'Social' category option missing")
    }

    // MARK: - Test 4: Review shows categorized events

    /// GIVEN: Calendar events with assigned categories
    /// WHEN: User navigates to Review tab (week view)
    /// THEN: Category stats include event time
    /// TDD RED: MacReviewView doesn't load CalendarEvents
    func testReviewShowsCategorizedEventStats() throws {
        navigateToReview()
        sleep(1)

        // Switch to week view
        let weekPicker = app.buttons["Diese Woche"]
        if weekPicker.waitForExistence(timeout: 3) {
            weekPicker.click()
            sleep(1)
        }

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacReview-WeekView"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: "Kategorien-Verteilung" section exists (macOS uses this title)
        let categorySection = app.staticTexts["Kategorien-Verteilung"]
        XCTAssertTrue(
            categorySection.waitForExistence(timeout: 5),
            "TDD RED: Review should show 'Kategorien-Verteilung' section"
        )

        // Verify: At least one category shows event-sourced data
        // The identifier "eventMinutesIncluded" should be set when events contribute
        let eventContribution = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'eventMinutesIncluded'")
        ).firstMatch

        XCTAssertTrue(
            eventContribution.waitForExistence(timeout: 3),
            "TDD RED: Review stats MUST include calendar event minutes (marker 'eventMinutesIncluded')"
        )
    }
}
