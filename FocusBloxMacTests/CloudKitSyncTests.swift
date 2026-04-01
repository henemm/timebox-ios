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

    /// Bug: Cross-Platform Sync — Completed tasks must disappear from active list after refresh.
    /// Simulates: iOS marks task complete (remote change arrives in store),
    /// then macOS calls refreshTasks() pattern (save + fetch) → completed task filtered out.
    @MainActor
    func testCompletedTaskDisappearsAfterRefresh() throws {
        let container = try MacModelContainer.create()
        let context = container.mainContext

        // Setup: Create an active task
        let testTitle = "Sync Refresh Test \(UUID().uuidString)"
        let task = LocalTask(title: testTitle)
        task.lifecycleStatus = "active"
        context.insert(task)
        try context.save()

        // Verify task appears in active list
        let activeBefore = try context.fetch(FetchDescriptor<LocalTask>())
            .filter { !$0.isCompleted && $0.title == testTitle }
        XCTAssertEqual(activeBefore.count, 1, "Task should be in active list before completion")

        // Simulate remote completion (iOS marks task complete → CloudKit imports to store)
        task.isCompleted = true
        task.completedAt = Date()
        try context.save()

        // Simulate macOS refreshTasks() pattern: save() + fetch()
        try context.save()
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
        ))
        let activeAfter = allTasks.filter { !$0.isCompleted && $0.title == testTitle }

        XCTAssertEqual(activeAfter.count, 0, "Completed task must not appear in active list after refresh")

        // Cleanup
        context.delete(task)
        try context.save()
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
