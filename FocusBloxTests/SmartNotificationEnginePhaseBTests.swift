import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for SmartNotificationEngine Phase B (FocusBlock Migration)
/// TDD RED: Tests MUST FAIL — ModelContext overload + TaskOverdue methods don't exist yet.
@MainActor
final class SmartNotificationEnginePhaseBTests: XCTestCase {

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
    }

    // MARK: - ModelContext Overload Tests

    /// Verhalten: buildAllRequests mit ModelContext-Overload liefert gleiche Ergebnisse
    /// wie Container-Overload bei identischem Datenstand.
    /// Bricht wenn: buildAllRequests(profile:context:eventKitRepo:) nicht existiert (Compile Error)
    ///   oder buildTaskRequests(context:) andere Logik hat als buildTaskRequests(container:).
    func test_contextOverload_producesEquivalentRequests() async throws {
        let cal = Calendar.current
        let tasks = (0..<3).map { i in
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.day! += i + 2
            comps.hour = 18
            comps.minute = 0
            let dueDate = cal.date(from: comps)!
            return makeTask(title: "Task \(i)", dueDate: dueDate)
        }
        let container = try makeTestContainer(with: tasks)
        let context = container.mainContext
        let repo = makeMockRepo(blocks: [])

        // Act: Beide Overloads aufrufen
        let containerRequests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced, container: container, eventKitRepo: repo
        )
        let contextRequests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced, context: context, eventKitRepo: repo
        )

        // Assert: Gleiche Anzahl
        XCTAssertEqual(containerRequests.count, contextRequests.count,
                       "Context overload should produce same number of requests as container overload")
    }

    /// Verhalten: Context-Overload mit quiet Profil → 0 Task-Requests.
    /// Bricht wenn: buildAllRequests(profile:context:eventKitRepo:) nicht existiert
    ///   oder Profil-Check fuer .quiet fehlt.
    func test_contextOverload_quietProfile_zeroTaskRequests() async throws {
        let tasks = [makeTask(title: "Task", dueDate: Date().addingTimeInterval(86400 * 2))]
        let container = try makeTestContainer(with: tasks)

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .quiet,
            context: container.mainContext,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        let taskRequests = requests.filter { $0.identifier.hasPrefix("due-date-") }
        XCTAssertEqual(taskRequests.count, 0, "Quiet profile with context overload: 0 task requests")
    }

    /// Verhalten: Context-Overload mit balanced Profil → Task-Requests <= Budget (20).
    /// Bricht wenn: buildTaskRequests(context:) den budgetTasks-Cap nicht respektiert.
    func test_contextOverload_balancedProfile_taskRequestsWithinBudget() async throws {
        let cal = Calendar.current
        let tasks = (0..<30).map { i in
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.day! += i + 2
            comps.hour = 18
            comps.minute = 0
            let dueDate = cal.date(from: comps)!
            return makeTask(title: "Task \(i)", dueDate: dueDate)
        }
        let container = try makeTestContainer(with: tasks)

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            context: container.mainContext,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        let taskRequests = requests.filter { $0.identifier.hasPrefix("due-date-") }
        XCTAssertLessThanOrEqual(taskRequests.count, SmartNotificationEngine.budgetTasks,
                                  "Context overload: task requests within budget")
    }

    /// Verhalten: Context-Overload ignoriert completed Tasks.
    /// Bricht wenn: buildTaskRequests(context:) den isCompleted-Filter entfernt.
    func test_buildTaskRequests_context_excludesCompletedTasks() async throws {
        let task = makeTask(title: "Done Task", dueDate: Date().addingTimeInterval(86400 * 2))
        task.isCompleted = true
        task.completedAt = Date()
        let container = try makeTestContainer(with: [task])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            context: container.mainContext,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        let taskRequests = requests.filter { $0.identifier.hasPrefix("due-date-") }
        XCTAssertEqual(taskRequests.count, 0, "Completed tasks excluded in context overload")
    }

    /// Verhalten: Context-Overload ignoriert Tasks ohne dueDate.
    /// Bricht wenn: buildTaskRequests(context:) den dueDate-nil-Filter entfernt.
    func test_buildTaskRequests_context_excludesTasksWithoutDueDate() async throws {
        let task = makeTask(title: "No due", dueDate: nil)
        let container = try makeTestContainer(with: [task])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            context: container.mainContext,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        let taskRequests = requests.filter { $0.identifier.hasPrefix("due-date-") }
        XCTAssertEqual(taskRequests.count, 0, "Tasks without dueDate excluded in context overload")
    }

    // MARK: - Task-Overdue Methods Tests

    /// Verhalten: scheduleTaskOverdue existiert als Methode auf der Engine.
    /// Bricht wenn: SmartNotificationEngine.scheduleTaskOverdue nicht existiert (Compile Error).
    func test_scheduleTaskOverdue_methodExists() {
        // Act: Methode aufrufen — wenn sie nicht existiert, Compile Error = RED
        SmartNotificationEngine.scheduleTaskOverdue(
            taskID: "test-task-1",
            taskTitle: "Test Task",
            durationMinutes: 5
        )
        // Assert: Kein Crash — Methode existiert und delegiert an NotificationService
        // (NotificationService.scheduleTaskOverdueNotification wird intern aufgerufen)
    }

    /// Verhalten: cancelTaskOverdue existiert als Methode auf der Engine.
    /// Bricht wenn: SmartNotificationEngine.cancelTaskOverdue nicht existiert (Compile Error).
    func test_cancelTaskOverdue_methodExists() {
        // Act: Methode aufrufen
        SmartNotificationEngine.cancelTaskOverdue(taskID: "test-task-1")
        // Assert: Kein Crash — Methode existiert und delegiert an NotificationService
    }

    // MARK: - Regression: Phase A Container Overload bleibt funktional

    /// Verhalten: Container-Overload (Phase A) funktioniert weiterhin nach Phase B Aenderungen.
    /// Bricht wenn: Phase B Aenderungen den bestehenden Container-Overload brechen.
    func test_containerOverload_stillFunctional() async throws {
        let container = try makeTestContainer()

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        // Container-Overload existiert weiterhin und crasht nicht
        XCTAssertNotNil(requests, "Container overload should still work")
    }

    /// Verhalten: Budget-Cap 64 gilt auch fuer Context-Overload.
    /// Bricht wenn: Array(requests.prefix(64)) im Context-Overload fehlt.
    func test_totalBudget_neverExceeds64_contextOverload() async throws {
        let cal = Calendar.current
        let tasks = (0..<100).map { i in
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.day! += i + 2
            comps.hour = 18
            comps.minute = 0
            let dueDate = cal.date(from: comps)!
            return makeTask(title: "Task \(i)", dueDate: dueDate)
        }
        let blocks = (0..<10).map { i in
            makeFocusBlock(id: "block-\(i)", minutesFromNow: (i + 1) * 60)
        }
        let container = try makeTestContainer(with: tasks)

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .active,
            context: container.mainContext,
            eventKitRepo: makeMockRepo(blocks: blocks)
        )

        XCTAssertLessThanOrEqual(requests.count, 64,
                                  "Context overload: total requests never exceed 64")
    }

    // MARK: - View Migration: No Direct NotificationService Calls

    private var projectRoot: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FocusBloxTests/
            .deletingLastPathComponent()   // project root
            .path
    }

    /// Verhalten: FocusLiveView hat nach Migration keine direkten NotificationService-Aufrufe mehr
    /// (ausser ueber SmartNotificationEngine).
    /// Bricht wenn: FocusLiveView noch direkte NotificationService.schedule/cancel-Aufrufe enthaelt.
    func test_focusLiveView_noDirectNotificationServiceCalls() throws {
        let sourceFile = try String(contentsOfFile: "\(projectRoot)/Sources/Views/FocusLiveView.swift", encoding: .utf8)

        // Diese direkten Aufrufe duerfen nach Migration nicht mehr vorkommen:
        let forbiddenPatterns = [
            "NotificationService.cancelTaskNotification",
            "NotificationService.cancelFocusBlockNotification",
            "NotificationService.scheduleFocusBlockEndNotification",
            "NotificationService.scheduleTaskOverdueNotification"
        ]

        for pattern in forbiddenPatterns {
            XCTAssertFalse(sourceFile.contains(pattern),
                           "FocusLiveView should not contain direct call: \(pattern)")
        }
    }

    /// Verhalten: BlockPlanningView hat nach Migration keine direkten NotificationService-Aufrufe mehr.
    /// Bricht wenn: BlockPlanningView noch direkte Aufrufe enthaelt.
    func test_blockPlanningView_noDirectNotificationServiceCalls() throws {
        let sourceFile = try String(contentsOfFile: "\(projectRoot)/Sources/Views/BlockPlanningView.swift", encoding: .utf8)

        let forbiddenPatterns = [
            "NotificationService.cancelFocusBlockNotification",
            "NotificationService.scheduleFocusBlockStartNotification",
            "NotificationService.scheduleFocusBlockEndNotification"
        ]

        for pattern in forbiddenPatterns {
            XCTAssertFalse(sourceFile.contains(pattern),
                           "BlockPlanningView should not contain direct call: \(pattern)")
        }
    }

    /// Verhalten: TaskAssignmentView hat nach Migration keine direkten NotificationService-Aufrufe mehr.
    /// Bricht wenn: TaskAssignmentView noch direkte Aufrufe enthaelt.
    func test_taskAssignmentView_noDirectNotificationServiceCalls() throws {
        let sourceFile = try String(contentsOfFile: "\(projectRoot)/Sources/Views/TaskAssignmentView.swift", encoding: .utf8)

        let forbiddenPatterns = [
            "NotificationService.cancelFocusBlockNotification",
            "NotificationService.scheduleFocusBlockStartNotification"
        ]

        for pattern in forbiddenPatterns {
            XCTAssertFalse(sourceFile.contains(pattern),
                           "TaskAssignmentView should not contain direct call: \(pattern)")
        }
    }

    /// Verhalten: FocusLiveView.rescheduleEndNotification Methode existiert nicht mehr.
    /// Bricht wenn: Die Methode noch im Source Code vorhanden ist.
    func test_rescheduleEndNotification_methodRemoved() throws {
        let sourceFile = try String(contentsOfFile: "\(projectRoot)/Sources/Views/FocusLiveView.swift", encoding: .utf8)
        XCTAssertFalse(sourceFile.contains("func rescheduleEndNotification"),
                       "rescheduleEndNotification should be removed from FocusLiveView")
    }

    /// Verhalten: FocusBloxMacApp.rescheduleDueDateNotifications Methode existiert nicht mehr.
    /// Bricht wenn: Die Methode noch im macOS App Source Code vorhanden ist.
    func test_macApp_rescheduleDueDateNotifications_removed() throws {
        let sourceFile = try String(contentsOfFile: "\(projectRoot)/FocusBloxMac/FocusBloxMacApp.swift", encoding: .utf8)
        XCTAssertFalse(sourceFile.contains("func rescheduleDueDateNotifications"),
                       "rescheduleDueDateNotifications should be removed from FocusBloxMacApp")
    }

    // MARK: - Helpers

    private func makeTestContainer(with tasks: [LocalTask] = []) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext
        for task in tasks {
            context.insert(task)
        }
        try context.save()
        return container
    }

    private func makeTask(title: String, dueDate: Date?) -> LocalTask {
        let task = LocalTask(title: title)
        task.dueDate = dueDate
        return task
    }

    private func makeFocusBlock(id: String, minutesFromNow: Int) -> FocusBlock {
        let start = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
        let end = start.addingTimeInterval(3600)
        return FocusBlock(
            id: id,
            title: "Test Block",
            startDate: start,
            endDate: end,
            taskIDs: [],
            completedTaskIDs: [],
            taskTimes: [:]
        )
    }

    func makeMockRepo(blocks: [FocusBlock]) -> MockEventKitRepository {
        let repo = MockEventKitRepository()
        repo.mockFocusBlocks = blocks
        return repo
    }
}
