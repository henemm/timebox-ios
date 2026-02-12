import XCTest
import UserNotifications
@testable import FocusBlox

/// Tests for Bug 39: FocusBlock Lifecycle nach Block-Ende
@MainActor
final class FocusBlockLifecycleTests: XCTestCase {

    // MARK: - Block End Notification Tests

    /// Block-Ende Notification sollte korrekt erstellt werden
    func testBlockEndNotificationContent() {
        let now = Date()
        let endDate = now.addingTimeInterval(30 * 60)

        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "test-end-1",
            blockTitle: "FocusBlox 10:00",
            endDate: endDate,
            completedCount: 2,
            totalCount: 3,
            now: now
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.content.title, "FocusBlox beendet")
        XCTAssertTrue(request?.content.body.contains("2/3") ?? false)
    }

    /// Block-Ende Notification fuer vergangenen Block sollte nil sein
    func testBlockEndNotificationNilForPastBlock() {
        let now = Date()
        let endDate = now.addingTimeInterval(-10 * 60)

        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "test-past",
            blockTitle: "Past Block",
            endDate: endDate,
            completedCount: 0,
            totalCount: 1,
            now: now
        )

        XCTAssertNil(request, "Keine Notification fuer vergangene Bloecke")
    }

    /// Notification Identifier sollte korrektes Format haben
    func testBlockEndNotificationIdentifier() {
        let now = Date()
        let endDate = now.addingTimeInterval(60 * 60)

        let request = NotificationService.buildFocusBlockEndNotificationRequest(
            blockID: "ABC-123",
            blockTitle: "Test",
            endDate: endDate,
            completedCount: 0,
            totalCount: 1,
            now: now
        )

        XCTAssertEqual(request?.identifier, "focus-block-end-ABC-123")
    }

    // MARK: - Abgelaufene Bloecke Filter Tests

    /// isPast sollte true sein fuer abgelaufene Bloecke
    func testExpiredBlockIsPast() {
        let block = FocusBlock(
            id: "expired-1",
            title: "Expired Block",
            startDate: Date().addingTimeInterval(-120 * 60),
            endDate: Date().addingTimeInterval(-60 * 60),
            taskIDs: ["t1"],
            completedTaskIDs: [],
            taskTimes: [:]
        )

        XCTAssertTrue(block.isPast)
        XCTAssertFalse(block.isActive)
    }

    /// Aktiver Block sollte nicht isPast sein
    func testActiveBlockIsNotPast() {
        let block = FocusBlock(
            id: "active-1",
            title: "Active Block",
            startDate: Date().addingTimeInterval(-30 * 60),
            endDate: Date().addingTimeInterval(30 * 60),
            taskIDs: ["t1"],
            completedTaskIDs: [],
            taskTimes: [:]
        )

        XCTAssertTrue(block.isActive)
        XCTAssertFalse(block.isPast)
    }

    /// Unerledigte Tasks sollten identifizierbar sein
    func testIncompleteTasksIdentifiable() {
        let block = FocusBlock(
            id: "review-1",
            title: "Review Block",
            startDate: Date().addingTimeInterval(-120 * 60),
            endDate: Date().addingTimeInterval(-60 * 60),
            taskIDs: ["t1", "t2", "t3"],
            completedTaskIDs: ["t1"],
            taskTimes: [:]
        )

        let incompleteTasks = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
        XCTAssertEqual(incompleteTasks, ["t2", "t3"])
    }
}
