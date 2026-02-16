//
//  MenuBarFocusBlockTests.swift
//  FocusBloxMacTests
//
//  Unit Tests for MenuBar FocusBlock Status - Timer formatting
//

import XCTest
@testable import FocusBloxMac

/// Unit tests for MenuBar timer formatting logic
/// Tests the mm:ss formatting used in the Menu Bar label and popover
final class MenuBarFocusBlockTests: XCTestCase {

    // MARK: - Timer Formatting Tests

    /// Test: Remaining seconds should format as mm:ss
    /// EXPECTED TO FAIL: MenuBarTimerFormatter does not exist yet
    func testTimerFormatPositiveMinutes() {
        // 14 minutes 23 seconds = 863 seconds
        let formatted = MenuBarTimerFormatter.format(seconds: 863)
        XCTAssertEqual(formatted, "14:23", "863 seconds should format as 14:23")
    }

    /// Test: Zero seconds should show 0:00
    /// EXPECTED TO FAIL: MenuBarTimerFormatter does not exist yet
    func testTimerFormatZero() {
        let formatted = MenuBarTimerFormatter.format(seconds: 0)
        XCTAssertEqual(formatted, "0:00", "0 seconds should format as 0:00")
    }

    /// Test: Negative seconds (overdue) should show 0:00
    /// EXPECTED TO FAIL: MenuBarTimerFormatter does not exist yet
    func testTimerFormatNegativeShowsZero() {
        let formatted = MenuBarTimerFormatter.format(seconds: -30)
        XCTAssertEqual(formatted, "0:00", "Negative seconds should show 0:00")
    }

    /// Test: Exactly 1 hour should show 60:00
    /// EXPECTED TO FAIL: MenuBarTimerFormatter does not exist yet
    func testTimerFormatOneHour() {
        let formatted = MenuBarTimerFormatter.format(seconds: 3600)
        XCTAssertEqual(formatted, "60:00", "3600 seconds should format as 60:00")
    }

    /// Test: Single digit minutes should not have leading zero
    /// EXPECTED TO FAIL: MenuBarTimerFormatter does not exist yet
    func testTimerFormatSingleDigitMinutes() {
        let formatted = MenuBarTimerFormatter.format(seconds: 305)
        XCTAssertEqual(formatted, "5:05", "305 seconds should format as 5:05")
    }
}
