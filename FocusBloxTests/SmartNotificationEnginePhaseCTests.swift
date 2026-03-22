import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for SmartNotificationEngine Phase C (DueDate Migration)
/// TDD RED: Tests MUST FAIL — NotificationActionDelegate doesn't accept eventKitRepository yet,
/// and Views still contain direct NotificationService calls.
@MainActor
final class SmartNotificationEnginePhaseCTests: XCTestCase {

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
    }

    // MARK: - Migration Verification Tests (Source-Grep)
    // Diese Tests lesen den Quellcode und prüfen dass keine direkten
    // NotificationService.cancel/scheduleDueDateNotifications-Calls mehr existieren.

    /// Verhalten: BacklogView ruft keine direkten NotificationService DueDate-Calls mehr auf.
    /// Bricht wenn: Jemand wieder NotificationService.scheduleDueDateNotifications in BacklogView einfuegt.
    func test_backlogView_noDirectNotificationServiceCalls() throws {
        let source = try sourceContent(of: "Sources/Views/BacklogView.swift")
        XCTAssertFalse(
            source.contains("NotificationService.cancelDueDateNotifications"),
            "BacklogView should not contain direct NotificationService.cancelDueDateNotifications calls"
        )
        XCTAssertFalse(
            source.contains("NotificationService.scheduleDueDateNotifications"),
            "BacklogView should not contain direct NotificationService.scheduleDueDateNotifications calls"
        )
    }

    /// Verhalten: TaskFormSheet ruft keine direkten NotificationService DueDate-Calls mehr auf.
    /// Bricht wenn: Jemand wieder NotificationService.scheduleDueDateNotifications in TaskFormSheet einfuegt.
    func test_taskFormSheet_noDirectNotificationServiceCalls() throws {
        let source = try sourceContent(of: "Sources/Views/TaskFormSheet.swift")
        XCTAssertFalse(
            source.contains("NotificationService.cancelDueDateNotifications"),
            "TaskFormSheet should not contain direct NotificationService.cancelDueDateNotifications calls"
        )
        XCTAssertFalse(
            source.contains("NotificationService.scheduleDueDateNotifications"),
            "TaskFormSheet should not contain direct NotificationService.scheduleDueDateNotifications calls"
        )
    }

    /// Verhalten: CreateTaskView ruft keine direkten NotificationService DueDate-Calls mehr auf.
    /// Bricht wenn: Jemand wieder NotificationService.scheduleDueDateNotifications in CreateTaskView einfuegt.
    func test_createTaskView_noDirectNotificationServiceCalls() throws {
        let source = try sourceContent(of: "Sources/Views/TaskCreation/CreateTaskView.swift")
        XCTAssertFalse(
            source.contains("NotificationService.cancelDueDateNotifications"),
            "CreateTaskView should not contain direct NotificationService.cancelDueDateNotifications calls"
        )
        XCTAssertFalse(
            source.contains("NotificationService.scheduleDueDateNotifications"),
            "CreateTaskView should not contain direct NotificationService.scheduleDueDateNotifications calls"
        )
    }

    /// Verhalten: macOS ContentView ruft keine direkten NotificationService DueDate-Calls mehr auf.
    /// Bricht wenn: Jemand wieder NotificationService.scheduleDueDateNotifications in macOS ContentView einfuegt.
    func test_macContentView_noDirectNotificationServiceCalls() throws {
        let source = try sourceContent(of: "FocusBloxMac/ContentView.swift")
        XCTAssertFalse(
            source.contains("NotificationService.cancelDueDateNotifications"),
            "macOS ContentView should not contain direct NotificationService.cancelDueDateNotifications calls"
        )
        XCTAssertFalse(
            source.contains("NotificationService.scheduleDueDateNotifications"),
            "macOS ContentView should not contain direct NotificationService.scheduleDueDateNotifications calls"
        )
    }

    /// Verhalten: NotificationActionDelegate ruft keine direkten NotificationService DueDate-Calls mehr auf.
    /// Bricht wenn: Jemand wieder NotificationService.cancel/scheduleDueDateNotifications in Delegate einfuegt.
    func test_notificationActionDelegate_noDirectDueDateCalls() throws {
        let source = try sourceContent(of: "Sources/Services/NotificationActionDelegate.swift")
        XCTAssertFalse(
            source.contains("NotificationService.cancelDueDateNotifications"),
            "NotificationActionDelegate should not contain direct NotificationService.cancelDueDateNotifications calls"
        )
        XCTAssertFalse(
            source.contains("NotificationService.scheduleDueDateNotifications"),
            "NotificationActionDelegate should not contain direct NotificationService.scheduleDueDateNotifications calls"
        )
    }

    // MARK: - NotificationActionDelegate Integration Tests

    /// Verhalten: NotificationActionDelegate hat ein stored property "eventKitRepository".
    /// Bricht wenn: eventKitRepository-Property nicht existiert oder umbenannt wird.
    /// Nach Implementation: Property existiert → Mirror findet es.
    func test_delegate_hasEventKitRepositoryProperty() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let delegate = NotificationActionDelegate(container: container)

        // Per Reflection pruefen ob eventKitRepository als Property existiert
        let mirror = Mirror(reflecting: delegate)
        let hasEventKitRepo = mirror.children.contains { $0.label == "eventKitRepository" }
        XCTAssertTrue(hasEventKitRepo,
                      "NotificationActionDelegate should have an 'eventKitRepository' stored property (Phase C requires init injection)")
    }

    /// Verhalten: NotificationActionDelegate.init hat 2 Parameter (container + eventKitRepository).
    /// Bricht wenn: init-Signatur nur 1 Parameter hat (nur container).
    /// Prueft per Reflection ob delegate das Repo haelt.
    func test_delegate_init_injectsEventKitRepository() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let delegate = NotificationActionDelegate(container: container)

        // Nach Phase C: eventKitRepository muss vom Typ EventKitRepositoryProtocol sein
        let mirror = Mirror(reflecting: delegate)
        let repoChild = mirror.children.first { $0.label == "eventKitRepository" }
        XCTAssertNotNil(repoChild, "NotificationActionDelegate must accept eventKitRepository in init")
        if let repo = repoChild?.value {
            XCTAssertTrue(repo is any EventKitRepositoryProtocol,
                          "eventKitRepository should conform to EventKitRepositoryProtocol")
        }
    }

    // MARK: - Regression Tests (Phase A+B must stay green)

    /// Verhalten: reconcile(container:) Container-Overload funktioniert weiterhin.
    /// Bricht wenn: Signatur oder Logik von reconcile(reason:container:eventKitRepo:) geaendert wird.
    func test_containerOverload_stillFunctional() async throws {
        let container = try makeTestContainer()
        let repo = MockEventKitRepository()

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: repo
        )

        // Kein Crash + Requests im Budget
        XCTAssertLessThanOrEqual(requests.count, 64, "Container overload should still work, budget <= 64")
    }

    /// Verhalten: reconcile(context:) Context-Overload funktioniert weiterhin.
    /// Bricht wenn: Signatur oder Logik von reconcile(reason:context:eventKitRepo:) geaendert wird.
    func test_contextOverload_stillFunctional() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let repo = MockEventKitRepository()

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            context: context,
            eventKitRepo: repo
        )

        XCTAssertLessThanOrEqual(requests.count, 64, "Context overload should still work, budget <= 64")
    }

    /// Verhalten: Gesamtbudget bleibt <= 64 auch bei vielen Tasks + Blocks.
    /// Bricht wenn: Array(requests.prefix(64)) in buildAllRequests entfernt wird.
    func test_totalBudget_neverExceeds64() async throws {
        // 30+ Tasks mit dueDate + 5 FocusBlocks = weit ueber 64 potentielle Requests
        let cal = Calendar.current
        let tasks = (0..<30).map { i in
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.day! += i + 2
            comps.hour = 18
            comps.minute = 0
            let dueDate = cal.date(from: comps)!
            let task = LocalTask(title: "Task \(i)")
            task.dueDate = dueDate
            return task
        }
        let container = try makeTestContainer(with: tasks)

        let blocks = (0..<5).map { i in
            let start = Date().addingTimeInterval(Double(i + 1) * 7200)
            let end = start.addingTimeInterval(3600)
            return FocusBlock(
                id: "block-\(i)",
                title: "Block \(i)",
                startDate: start,
                endDate: end,
                taskIDs: [],
                completedTaskIDs: [],
                taskTimes: [:]
            )
        }
        let repo = MockEventKitRepository()
        repo.mockFocusBlocks = blocks

        // Profil "active" nutzt alle Slots (Timer + Tasks + Review + Nudges)
        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .active,
            container: container,
            eventKitRepo: repo
        )

        XCTAssertLessThanOrEqual(requests.count, 64, "Total requests must NEVER exceed 64 (iOS limit)")
    }

    // MARK: - Helpers

    /// Liest den Quellcode einer Datei relativ zum Projekt-Root.
    private func sourceContent(of relativePath: String) throws -> String {
        // Projekt-Root: 2 Verzeichnisse ueber dem Test-Bundle
        let testBundle = Bundle(for: type(of: self))
        let bundlePath = testBundle.bundlePath
        // Navigate from .xctest bundle → DerivedData → back to source root
        // Fallback: use known project root structure
        let candidates = [
            // Direct path from working directory (when running via xcodebuild)
            URL(fileURLWithPath: relativePath),
            // Relative to current file
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // FocusBloxTests/
                .deletingLastPathComponent() // FocusBlox/
                .appendingPathComponent(relativePath)
        ]

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return try String(contentsOf: url, encoding: .utf8)
            }
        }

        // Last resort: use process working directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cwdURL = cwd.appendingPathComponent(relativePath)
        return try String(contentsOf: cwdURL, encoding: .utf8)
    }

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
}
