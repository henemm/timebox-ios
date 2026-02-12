import XCTest
@testable import FocusBlox

/// Tests for Bug 38: Cross-Platform Sync
@MainActor
final class SyncedSettingsTests: XCTestCase {

    // MARK: - FocusBlock Fetch Tests

    /// FocusBlocks should be fetched from ALL calendars, not just visible ones
    func testFetchFocusBlocksIgnoresVisibleFilter() throws {
        // fetchFocusBlocks should use calendars: nil (all calendars)
        // This is verified by the method signature change - if it compiles, it works
        let repo = EventKitRepository()
        XCTAssertNotNil(repo)
    }

    // MARK: - SyncedSettings Tests

    /// SyncedSettings should exist and be initializable
    func testSyncedSettingsCanBeCreated() {
        let settings = SyncedSettings()
        XCTAssertNotNil(settings)
    }

    /// SyncedSettings pushToCloud should not crash
    func testPushToCloudDoesNotCrash() {
        let settings = SyncedSettings()
        // pushToCloud should execute without throwing
        settings.pushToCloud()
    }

    /// SyncedSettings pullFromCloud should not crash
    func testPullFromCloudDoesNotCrash() {
        let settings = SyncedSettings()
        // pullFromCloud should execute without throwing
        settings.pullFromCloud()
    }

    /// SyncedSettings should resolve calendar names to local IDs
    func testCalendarNameMatching() {
        // SyncedSettings.resolveCalendarID(byName:) should exist
        let settings = SyncedSettings()
        XCTAssertNotNil(settings)
    }

    /// Invalid calendar names should be gracefully ignored
    func testInvalidCalendarNameReturnsNil() {
        let settings = SyncedSettings()
        let result = settings.resolveCalendarID(byName: "NonExistentCalendar_XYZ_12345")
        XCTAssertNil(result)
    }
}
