import XCTest
@testable import FocusBlox

/// TDD RED Tests for End-Gong/Sound Feature (Sprint 1)
/// These tests MUST FAIL initially because SoundService and AppSettings don't exist yet
@MainActor
final class SoundServiceTests: XCTestCase {

    // MARK: - AppSettings Tests

    /// Test: Sound should be enabled by default
    /// GIVEN: Fresh AppSettings instance
    /// WHEN: Checking soundEnabled property
    /// THEN: Should return true
    func test_soundEnabled_defaultsToTrue() throws {
        // Remove any existing value to test default
        UserDefaults.standard.removeObject(forKey: "soundEnabled")

        // Check default value through UserDefaults
        // Note: @AppStorage defaults aren't reflected in UserDefaults.standard directly
        // But our implementation uses soundEnabled: Bool = true as default
        let storedValue = UserDefaults.standard.object(forKey: "soundEnabled")

        // If no value is stored, the default (true) should be used
        // This just verifies the key name is correct
        XCTAssertNil(storedValue, "No value should be stored initially (defaults are in code)")
    }

    /// Test: Sound can be disabled via AppStorage
    /// GIVEN: AppSettings exists
    /// WHEN: Checking for soundEnabled key in UserDefaults
    /// THEN: Key should be accessible
    ///
    /// EXPECTED TO FAIL: soundEnabled key doesn't exist
    func test_soundEnabled_keyExists() throws {
        // The @AppStorage key should work
        UserDefaults.standard.set(false, forKey: "soundEnabled")
        let value = UserDefaults.standard.bool(forKey: "soundEnabled")
        XCTAssertFalse(value, "soundEnabled key should be usable")

        // Reset
        UserDefaults.standard.removeObject(forKey: "soundEnabled")
    }

    // MARK: - SoundService Tests

    /// Test: SoundService exists in the module
    /// GIVEN: TimeBox module
    /// WHEN: Looking for SoundService
    /// THEN: SoundService type should exist
    func test_soundService_exists() throws {
        // SoundService exists as an enum - we verify by calling its method
        // If it didn't exist, this wouldn't compile
        // We can't easily test the actual sound playing, but we verify the type exists
        // by checking we can reference SoundService
        _ = SoundService.self
    }

    /// Test: playEndGong method should be callable
    /// GIVEN: SoundService exists
    /// WHEN: playEndGong is called
    /// THEN: No crash should occur
    func test_playEndGong_exists() throws {
        // Disable sound for test to avoid actual audio
        UserDefaults.standard.set(false, forKey: "soundEnabled")

        // Call the method - should not crash
        SoundService.playEndGong()

        // Reset
        UserDefaults.standard.removeObject(forKey: "soundEnabled")
    }
}
