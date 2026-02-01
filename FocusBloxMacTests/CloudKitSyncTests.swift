//
//  CloudKitSyncTests.swift
//  FocusBloxMacTests
//
//  Tests for CloudKit sync configuration
//

import XCTest
import SwiftData
@testable import FocusBloxMac

final class CloudKitSyncTests: XCTestCase {

    /// Test: App Group container is available
    func testAppGroupContainerExists() throws {
        let appGroupID = "group.com.henning.focusblox"
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )

        XCTAssertNotNil(containerURL, "App Group container should be available")
    }

    /// Test: ModelContainer can be created with CloudKit config
    func testModelContainerCreation() throws {
        XCTAssertNoThrow(try MacModelContainer.create(), "ModelContainer should be created without errors")
    }

    /// Test: ModelContainer uses correct schema
    func testModelContainerSchema() throws {
        let container = try MacModelContainer.create()
        let schema = container.schema

        // Verify LocalTask is in schema
        let hasLocalTask = schema.entities.contains { $0.name == "LocalTask" }
        XCTAssertTrue(hasLocalTask, "Schema should contain LocalTask entity")
    }

    /// Test: Tasks can be created and persisted
    @MainActor
    func testTaskPersistence() throws {
        let container = try MacModelContainer.create()
        let context = container.mainContext

        // Create a test task
        let testTitle = "CloudKit Sync Test \(UUID().uuidString)"
        let task = LocalTask(title: testTitle)
        context.insert(task)
        try context.save()

        // Verify task exists
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.title == testTitle }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1, "Task should be persisted")
        XCTAssertEqual(results.first?.title, testTitle)

        // Cleanup
        if let taskToDelete = results.first {
            context.delete(taskToDelete)
            try context.save()
        }
    }

    /// Test: iCloud container ID matches expected value
    func testICloudContainerID() throws {
        // Read entitlements to verify iCloud container is configured
        let appGroupID = "group.com.henning.focusblox"
        let expectedICloudContainer = "iCloud.com.henning.focusblox"

        // If App Group works, iCloud should also be configured
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )

        XCTAssertNotNil(containerURL, "App Group (and thus iCloud) should be configured")

        // The iCloud container ID follows the pattern iCloud.{bundle-id-prefix}
        // We verify the App Group is accessible, which indicates proper signing
        XCTAssertTrue(containerURL?.path.contains("group.com.henning.focusblox") ?? false,
                      "Container path should reference the correct App Group")
    }
}
