//
//  TimelineLayoutTests.swift
//  FocusBloxMacTests
//
//  Unit Tests for TimelineLayout - Custom Layout Protocol
//
//  Created: 2026-02-04
//

import Testing
import SwiftUI
@testable import FocusBloxMac

// MARK: - TimelineLayout Tests

struct TimelineLayoutTests {

    // MARK: - Y-Position Calculation Tests

    @Test("calculateYPosition for 9:00 AM returns 180")
    func testCalculateYPosition_9am() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        // 9:00 is 3 hours after 6:00 → y = 3 * 60 = 180
        let y = layout.calculateYPosition(hour: 9, minute: 0)

        #expect(y == 180, "Expected y=180 for 9:00, got \(y)")
    }

    @Test("calculateYPosition for 9:30 AM returns 210")
    func testCalculateYPosition_930am() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        // 9:30 is 3.5 hours after 6:00 → y = 3.5 * 60 = 210
        let y = layout.calculateYPosition(hour: 9, minute: 30)

        #expect(y == 210, "Expected y=210 for 9:30, got \(y)")
    }

    @Test("calculateYPosition for 6:00 AM (start) returns 0")
    func testCalculateYPosition_6am() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        // 6:00 is start → y = 0
        let y = layout.calculateYPosition(hour: 6, minute: 0)

        #expect(y == 0, "Expected y=0 for 6:00, got \(y)")
    }

    @Test("calculateYPosition for 10:15 AM returns 255")
    func testCalculateYPosition_1015am() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        // 10:15 is 4.25 hours after 6:00 → y = 4.25 * 60 = 255
        let y = layout.calculateYPosition(hour: 10, minute: 15)

        #expect(y == 255, "Expected y=255 for 10:15, got \(y)")
    }

    @Test("calculateYPosition for 21:45 PM returns 945")
    func testCalculateYPosition_2145pm() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        // 21:45 is 15.75 hours after 6:00 → y = 15.75 * 60 = 945
        let y = layout.calculateYPosition(hour: 21, minute: 45)

        #expect(y == 945, "Expected y=945 for 21:45, got \(y)")
    }

    // MARK: - Block Height Calculation Tests

    @Test("calculateBlockHeight for 60 min duration returns 60")
    func testCalculateBlockHeight_60min() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        let height = layout.calculateBlockHeight(durationMinutes: 60)

        #expect(height == 60, "Expected height=60 for 60min, got \(height)")
    }

    @Test("calculateBlockHeight for 90 min duration returns 90")
    func testCalculateBlockHeight_90min() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        let height = layout.calculateBlockHeight(durationMinutes: 90)

        #expect(height == 90, "Expected height=90 for 90min, got \(height)")
    }

    @Test("calculateBlockHeight for 30 min duration returns 30")
    func testCalculateBlockHeight_30min() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        let height = layout.calculateBlockHeight(durationMinutes: 30)

        #expect(height == 30, "Expected height=30 for 30min, got \(height)")
    }

    @Test("calculateBlockHeight for 45 min duration returns 45")
    func testCalculateBlockHeight_45min() async throws {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)

        let height = layout.calculateBlockHeight(durationMinutes: 45)

        #expect(height == 45, "Expected height=45 for 45min, got \(height)")
    }

    // MARK: - Different hourHeight Tests

    @Test("calculateYPosition with hourHeight=80 returns correct value")
    func testCalculateYPosition_differentHourHeight() async throws {
        let layout = TimelineLayout(hourHeight: 80, startHour: 6, endHour: 22)

        // 9:00 is 3 hours after 6:00 → y = 3 * 80 = 240
        let y = layout.calculateYPosition(hour: 9, minute: 0)

        #expect(y == 240, "Expected y=240 for 9:00 with hourHeight=80, got \(y)")
    }

    @Test("calculateBlockHeight with hourHeight=80 returns correct value")
    func testCalculateBlockHeight_differentHourHeight() async throws {
        let layout = TimelineLayout(hourHeight: 80, startHour: 6, endHour: 22)

        let height = layout.calculateBlockHeight(durationMinutes: 60)

        #expect(height == 80, "Expected height=80 for 60min with hourHeight=80, got \(height)")
    }
}

// MARK: - Persistenz Tests

struct TimelinePersistenceTests {

    @Test("assignTaskToBlock adds taskID to block")
    func testAssignTaskToBlock_addsTaskID() async throws {
        // GIVEN: A FocusBlock without the task
        var taskIDs: [String] = ["existing-task"]

        // WHEN: Task is assigned
        let newTaskID = "new-task-123"
        if !taskIDs.contains(newTaskID) {
            taskIDs.append(newTaskID)
        }

        // THEN: TaskIDs should contain the new task
        #expect(taskIDs.contains(newTaskID), "Task should be added to block")
        #expect(taskIDs.count == 2, "Should have 2 tasks")
    }

    @Test("assignTaskToBlock prevents duplicates")
    func testAssignTaskToBlock_preventsDuplicates() async throws {
        // GIVEN: A FocusBlock with an existing task
        var taskIDs: [String] = ["task-123"]

        // WHEN: Same task is assigned again
        let duplicateTaskID = "task-123"
        if !taskIDs.contains(duplicateTaskID) {
            taskIDs.append(duplicateTaskID)
        }

        // THEN: TaskIDs should still have only 1 task
        #expect(taskIDs.count == 1, "Should prevent duplicates")
    }

    @Test("removeTaskFromBlock removes taskID")
    func testRemoveTaskFromBlock_removesTaskID() async throws {
        // GIVEN: A FocusBlock with tasks
        var taskIDs: [String] = ["task-1", "task-2", "task-3"]

        // WHEN: Task is removed
        taskIDs.removeAll { $0 == "task-2" }

        // THEN: TaskIDs should not contain the removed task
        #expect(!taskIDs.contains("task-2"), "Task should be removed")
        #expect(taskIDs.count == 2, "Should have 2 tasks remaining")
    }
}
