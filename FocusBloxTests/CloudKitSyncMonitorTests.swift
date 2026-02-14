import XCTest
import CoreData
@testable import FocusBlox

@MainActor
final class CloudKitSyncMonitorTests: XCTestCase {

    // MARK: - Test 1: Initial State

    func testInitialState() {
        let monitor = CloudKitSyncMonitor()

        XCTAssertEqual(monitor.setupState, .notStarted)
        XCTAssertEqual(monitor.importState, .notStarted)
        XCTAssertEqual(monitor.exportState, .notStarted)
        XCTAssertFalse(monitor.isSyncing)
        XCTAssertFalse(monitor.hasSyncError)
        XCTAssertNil(monitor.lastSuccessfulSync)
        XCTAssertNil(monitor.errorMessage)
    }

    // MARK: - Test 2: Import Started -> isSyncing

    func testImportStarted_setsIsSyncing() {
        let monitor = CloudKitSyncMonitor()

        // Simulate import started event
        monitor.simulateEvent(type: .import, started: Date(), ended: nil, succeeded: true, error: nil)

        XCTAssertTrue(monitor.isSyncing)
        if case .inProgress = monitor.importState {
            // correct
        } else {
            XCTFail("Expected .inProgress, got \(monitor.importState)")
        }
    }

    // MARK: - Test 3: Import Succeeded

    func testImportSucceeded_updatesState() {
        let monitor = CloudKitSyncMonitor()
        let start = Date()
        let end = Date()

        monitor.simulateEvent(type: .import, started: start, ended: end, succeeded: true, error: nil)

        XCTAssertFalse(monitor.isSyncing)
        if case .succeeded = monitor.importState {
            // correct
        } else {
            XCTFail("Expected .succeeded, got \(monitor.importState)")
        }
        XCTAssertNotNil(monitor.lastSuccessfulSync)
    }

    // MARK: - Test 4: Export Failed -> hasSyncError

    func testExportFailed_setsError() {
        let monitor = CloudKitSyncMonitor()
        let start = Date()
        let end = Date()
        let error = NSError(domain: "CKErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network unavailable"])

        monitor.simulateEvent(type: .export, started: start, ended: end, succeeded: false, error: error)

        XCTAssertTrue(monitor.hasSyncError)
        if case .failed(_, _, let msg) = monitor.exportState {
            XCTAssertEqual(msg, "Network unavailable")
        } else {
            XCTFail("Expected .failed, got \(monitor.exportState)")
        }
        XCTAssertNotNil(monitor.errorMessage)
    }

    // MARK: - Test 5: Setup Event

    func testSetupEvent_updatesSetupState() {
        let monitor = CloudKitSyncMonitor()
        let start = Date()

        // Setup started
        monitor.simulateEvent(type: .setup, started: start, ended: nil, succeeded: true, error: nil)
        if case .inProgress = monitor.setupState {
            // correct
        } else {
            XCTFail("Expected .inProgress, got \(monitor.setupState)")
        }

        // Setup finished
        monitor.simulateEvent(type: .setup, started: start, ended: Date(), succeeded: true, error: nil)
        if case .succeeded = monitor.setupState {
            // correct
        } else {
            XCTFail("Expected .succeeded, got \(monitor.setupState)")
        }
    }

    // MARK: - Test 6: Multiple Events

    func testMultipleEvents_tracksAllTypes() {
        let monitor = CloudKitSyncMonitor()
        let start = Date()

        // Both in progress
        monitor.simulateEvent(type: .import, started: start, ended: nil, succeeded: true, error: nil)
        monitor.simulateEvent(type: .export, started: start, ended: nil, succeeded: true, error: nil)
        XCTAssertTrue(monitor.isSyncing)

        // Both finished
        let end = Date()
        monitor.simulateEvent(type: .import, started: start, ended: end, succeeded: true, error: nil)
        monitor.simulateEvent(type: .export, started: start, ended: end, succeeded: true, error: nil)
        XCTAssertFalse(monitor.isSyncing)
        XCTAssertFalse(monitor.hasSyncError)
    }
}
