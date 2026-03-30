//
//  MacDayViewTimelineUITests.swift
//  FocusBloxMacUITests
//
//  Tests for MAC_RW_2.1_TL — DayView Daytime Timeline on macOS
//  Verifies MacTimelineView replaces the placeholder "Timeline kommt bald"
//

import XCTest

final class MacDayViewTimelineUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -UITesting: Activates MockEventKitRepository with mock events/focus blocks
        // -morningEndHour 0 -eveningStartHour 23: Forces daytime phase at any hour
        app.launchArguments = [
            "-UITesting",
            "-MockData",
            "-ApplePersistenceIgnoreState", "YES",
            "-morningEndHour", "0",
            "-eveningStartHour", "23"
        ]
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToDay() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 5) else {
            XCTFail("Navigation picker RadioGroup not found")
            return
        }
        let dayRadio = radioGroup.radioButtons["calendar.badge.clock"]
        guard dayRadio.waitForExistence(timeout: 3) else {
            XCTFail("Tag radio button not found")
            return
        }
        dayRadio.click()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)
    }

    // MARK: - Tests

    /// Verhalten: Platzhalter "Timeline kommt bald" erscheint nicht mehr im Daytime-Modus
    /// Bricht wenn: DayView.swift #else Branch weiterhin ContentUnavailableView rendert
    func test_dayView_daytime_noPlaceholder() throws {
        navigateToDay()

        let placeholder = app.staticTexts["Timeline kommt bald"]
        _ = placeholder.waitForExistence(timeout: 3)

        XCTAssertFalse(
            placeholder.exists,
            "Platzhalter 'Timeline kommt bald' sollte nicht mehr angezeigt werden"
        )
    }

    /// Verhalten: MacTimelineView zeigt Stundenlabels wenn Mock-Events vorhanden
    /// Bricht wenn: DayView.swift #else Branch MacTimelineView nicht einbindet
    ///              ODER FocusBloxMacApp MockEventKitRepository nicht verwendet
    func test_dayView_daytime_showsTimelineHourLabels() throws {
        navigateToDay()

        // MockEventKitRepository provides events at 08:00 and 12:00
        // MacTimelineView renders hour grid labels "08:00", "12:00", etc.
        let hourLabel = app.staticTexts["12:00"]
        XCTAssertTrue(
            hourLabel.waitForExistence(timeout: 5),
            "Timeline sollte Stundenlabel '12:00' zeigen (MacTimelineView mit Mock-Events)"
        )
    }

    /// Verhalten: Mock-Event "Team Meeting" erscheint in der Timeline
    /// Bricht wenn: MacTimelineView nicht korrekt mit calendarEvents verdrahtet ist
    func test_dayView_daytime_showsMockCalendarEvent() throws {
        navigateToDay()

        // MockEventKitRepository provides "Team Meeting" at 08:00
        let eventTitle = app.staticTexts["Team Meeting"]
        XCTAssertTrue(
            eventTitle.waitForExistence(timeout: 5),
            "Mock-Event 'Team Meeting' sollte in der Timeline angezeigt werden"
        )
    }
}
