import XCTest
@testable import FocusBlox

/// Tests for Warning Feature (Sprint 2)
@MainActor
final class WarningTests: XCTestCase {

    // MARK: - AppSettings Tests

    /// Test: Warning should be enabled by default
    /// GIVEN: Fresh AppSettings
    /// WHEN: Checking warningEnabled
    /// THEN: Should return true
    func test_warningEnabled_defaultsToTrue() throws {
        // Remove any existing value to test default
        UserDefaults.standard.removeObject(forKey: "warningEnabled")

        // Verify AppSettings default value
        let settings = AppSettings.shared
        XCTAssertTrue(settings.warningEnabled, "Warning should be enabled by default")
    }

    /// Test: Warning timing should default to standard (80%)
    /// GIVEN: Fresh AppSettings
    /// WHEN: Checking warningTiming
    /// THEN: Should return .standard (80%)
    func test_warningTiming_defaultsToStandard() throws {
        // Remove any existing value
        UserDefaults.standard.removeObject(forKey: "warningTiming")

        // Verify AppSettings default value
        let settings = AppSettings.shared
        XCTAssertEqual(settings.warningTiming, .standard, "Warning timing should default to standard")
    }

    // MARK: - WarningTiming Enum Tests

    /// Test: WarningTiming enum should have correct labels
    /// Bricht wenn: WarningTiming.swift label Property geaendert wird
    func test_warningTiming_hasCorrectLabels() throws {
        XCTAssertEqual(WarningTiming.short.label, "Kurz vorher")
        XCTAssertEqual(WarningTiming.standard.label, "Standard")
        XCTAssertEqual(WarningTiming.early.label, "Weit vorher")
    }

    /// Test: WarningTiming should have correct percentage values
    /// GIVEN: WarningTiming enum exists
    /// WHEN: Checking percentComplete values
    /// THEN: short=0.9, standard=0.8, early=0.7
    func test_warningTiming_hasCorrectPercentages() throws {
        XCTAssertEqual(WarningTiming.short.percentComplete, 0.9, accuracy: 0.001)
        XCTAssertEqual(WarningTiming.standard.percentComplete, 0.8, accuracy: 0.001)
        XCTAssertEqual(WarningTiming.early.percentComplete, 0.7, accuracy: 0.001)
    }

    // MARK: - SoundService Tests

    /// Test: playWarning method should exist and not crash
    /// GIVEN: SoundService
    /// WHEN: Calling playWarning with sound/warning disabled
    /// THEN: No crash should occur
    func test_playWarning_exists() throws {
        // Disable sounds for test
        UserDefaults.standard.set(false, forKey: "soundEnabled")
        UserDefaults.standard.set(false, forKey: "warningEnabled")

        // Call playWarning - should not crash
        SoundService.playWarning()

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "soundEnabled")
        UserDefaults.standard.removeObject(forKey: "warningEnabled")
    }
}
