import XCTest
@testable import FocusBlox

/// Unit Tests for Bug 8: Permission request on app launch
///
/// These tests verify that the MockEventKitRepository correctly tracks
/// when requestAccess() is called, which is used to verify that
/// the app requests permissions on launch.
final class PermissionRequestTests: XCTestCase {

    /// Test: Mock should track when requestAccess is called
    ///
    /// EXPECTED TO FAIL: MockEventKitRepository does not have
    /// requestAccessCalled tracking property yet
    func testMockTracksRequestAccessCalled() async throws {
        let mock = MockEventKitRepository()

        // Call requestAccess
        _ = try await mock.requestAccess()

        // Verify the mock tracked this call
        // This property does not exist yet - test should FAIL
        XCTAssertTrue(mock.requestAccessCalled,
            "Mock should track when requestAccess() is called")
    }

    /// Test: Mock should default to requestAccessCalled = false
    ///
    /// EXPECTED TO FAIL: Property does not exist
    func testMockDefaultsToRequestAccessNotCalled() {
        let mock = MockEventKitRepository()

        XCTAssertFalse(mock.requestAccessCalled,
            "Mock should default to requestAccessCalled = false")
    }
}
