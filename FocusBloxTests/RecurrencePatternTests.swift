import XCTest
@testable import FocusBlox

/// Unit Tests for RecurrencePattern enum expansion (Phase 1: Recurrence Editing)
/// Tests new cases: weekdays, weekends, quarterly, semiannually, yearly
/// EXPECTED TO FAIL: New enum cases do not exist yet.
final class RecurrencePatternTests: XCTestCase {

    // MARK: - New Cases Exist

    func test_weekdays_rawValueExists() {
        let pattern = RecurrencePattern(rawValue: "weekdays")
        XCTAssertNotNil(pattern, "RecurrencePattern should have a 'weekdays' case")
    }

    func test_weekends_rawValueExists() {
        let pattern = RecurrencePattern(rawValue: "weekends")
        XCTAssertNotNil(pattern, "RecurrencePattern should have a 'weekends' case")
    }

    func test_quarterly_rawValueExists() {
        let pattern = RecurrencePattern(rawValue: "quarterly")
        XCTAssertNotNil(pattern, "RecurrencePattern should have a 'quarterly' case")
    }

    func test_semiannually_rawValueExists() {
        let pattern = RecurrencePattern(rawValue: "semiannually")
        XCTAssertNotNil(pattern, "RecurrencePattern should have a 'semiannually' case")
    }

    func test_yearly_rawValueExists() {
        let pattern = RecurrencePattern(rawValue: "yearly")
        XCTAssertNotNil(pattern, "RecurrencePattern should have a 'yearly' case")
    }

    // MARK: - Display Names

    func test_weekdays_displayName() {
        guard let pattern = RecurrencePattern(rawValue: "weekdays") else {
            XCTFail("weekdays pattern must exist before testing displayName")
            return
        }
        XCTAssertEqual(pattern.displayName, "An Wochentagen")
    }

    func test_weekends_displayName() {
        guard let pattern = RecurrencePattern(rawValue: "weekends") else {
            XCTFail("weekends pattern must exist before testing displayName")
            return
        }
        XCTAssertEqual(pattern.displayName, "An Wochenenden")
    }

    func test_quarterly_displayName() {
        guard let pattern = RecurrencePattern(rawValue: "quarterly") else {
            XCTFail("quarterly pattern must exist before testing displayName")
            return
        }
        XCTAssertEqual(pattern.displayName, "Alle 3 Monate")
    }

    func test_semiannually_displayName() {
        guard let pattern = RecurrencePattern(rawValue: "semiannually") else {
            XCTFail("semiannually pattern must exist before testing displayName")
            return
        }
        XCTAssertEqual(pattern.displayName, "Alle 6 Monate")
    }

    func test_yearly_displayName() {
        guard let pattern = RecurrencePattern(rawValue: "yearly") else {
            XCTFail("yearly pattern must exist before testing displayName")
            return
        }
        XCTAssertEqual(pattern.displayName, "Jährlich")
    }

    // MARK: - Requires Properties

    /// Weekdays preset has implicit weekdays (Mon-Fri), no user selection needed
    func test_weekdays_doesNotRequireWeekdaySelection() {
        guard let pattern = RecurrencePattern(rawValue: "weekdays") else {
            XCTFail("weekdays pattern must exist")
            return
        }
        XCTAssertFalse(pattern.requiresWeekdays,
            "Weekdays preset has implicit Mon-Fri, no user weekday selection needed")
    }

    /// Weekends preset has implicit weekdays (Sat-Sun), no user selection needed
    func test_weekends_doesNotRequireWeekdaySelection() {
        guard let pattern = RecurrencePattern(rawValue: "weekends") else {
            XCTFail("weekends pattern must exist")
            return
        }
        XCTAssertFalse(pattern.requiresWeekdays,
            "Weekends preset has implicit Sat-Sun, no user weekday selection needed")
    }

    func test_quarterly_doesNotRequireMonthDay() {
        guard let pattern = RecurrencePattern(rawValue: "quarterly") else {
            XCTFail("quarterly pattern must exist")
            return
        }
        XCTAssertFalse(pattern.requiresMonthDay)
    }

    func test_semiannually_doesNotRequireMonthDay() {
        guard let pattern = RecurrencePattern(rawValue: "semiannually") else {
            XCTFail("semiannually pattern must exist")
            return
        }
        XCTAssertFalse(pattern.requiresMonthDay)
    }

    func test_yearly_doesNotRequireMonthDay() {
        guard let pattern = RecurrencePattern(rawValue: "yearly") else {
            XCTFail("yearly pattern must exist")
            return
        }
        XCTAssertFalse(pattern.requiresMonthDay)
    }

    // MARK: - CaseIterable includes new cases

    func test_allCases_includesNewPatterns() {
        let allRawValues = RecurrencePattern.allCases.map(\.rawValue)
        XCTAssertTrue(allRawValues.contains("weekdays"), "allCases should include weekdays")
        XCTAssertTrue(allRawValues.contains("weekends"), "allCases should include weekends")
        XCTAssertTrue(allRawValues.contains("quarterly"), "allCases should include quarterly")
        XCTAssertTrue(allRawValues.contains("semiannually"), "allCases should include semiannually")
        XCTAssertTrue(allRawValues.contains("yearly"), "allCases should include yearly")
    }
}
