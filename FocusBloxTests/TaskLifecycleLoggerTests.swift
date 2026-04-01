import XCTest
@testable import FocusBlox

/// TDD RED: Tests for TaskLifecycleLogger (FEATURE_030).
/// These tests MUST FAIL because TaskLifecycleLogger doesn't exist yet.
final class TaskLifecycleLoggerTests: XCTestCase {

    // Use a unique temp file per test run to avoid interference
    private func makeTestLogPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-lifecycle-\(UUID().uuidString).log")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Logger Grundfunktion

    func testLogCreated_writesEntryWithTimestampAndTaskID() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let taskID = UUID()

        logger.logCreated(taskID: taskID, title: "Test Task")

        let content = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(content.contains("[created]"))
        XCTAssertTrue(content.contains(taskID.uuidString))
        XCTAssertTrue(content.contains("Test Task"))
        cleanup(logPath)
    }

    func testLogUpdated_writesFieldChanges() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let taskID = UUID()

        let changes = [
            FieldChange(field: "title", oldValue: "Old", newValue: "New"),
            FieldChange(field: "priority", oldValue: "low", newValue: "high"),
        ]
        logger.logUpdated(taskID: taskID, changes: changes)

        let content = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(content.contains("[updated]"))
        XCTAssertTrue(content.contains(taskID.uuidString))
        XCTAssertTrue(content.contains("title=\"Old\"→\"New\""))
        XCTAssertTrue(content.contains("priority=\"low\"→\"high\""))
        cleanup(logPath)
    }

    func testLogDeleted_writesDeleteEntry() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let taskID = UUID()

        logger.logDeleted(taskID: taskID, title: "Deleted Task")

        let content = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(content.contains("[deleted]"))
        XCTAssertTrue(content.contains(taskID.uuidString))
        XCTAssertTrue(content.contains("Deleted Task"))
        cleanup(logPath)
    }

    func testLogCompleted_writesCompletedEntry() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let taskID = UUID()

        logger.logCompleted(taskID: taskID, title: "Done Task")

        let content = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(content.contains("[completed]"))
        XCTAssertTrue(content.contains(taskID.uuidString))
        cleanup(logPath)
    }

    func testLogUncompleted_writesUncompletedEntry() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let taskID = UUID()

        logger.logUncompleted(taskID: taskID, title: "Reopened Task")

        let content = (try? String(contentsOf: logPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(content.contains("[uncompleted]"))
        XCTAssertTrue(content.contains(taskID.uuidString))
        cleanup(logPath)
    }

    // MARK: - Toggle Guard

    func testLogCreated_doesNothingWhenDisabled() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { false })
        let taskID = UUID()

        logger.logCreated(taskID: taskID, title: "Should Not Appear")

        let exists = FileManager.default.fileExists(atPath: logPath.path)
        XCTAssertFalse(exists, "Log file should not be created when disabled")
        cleanup(logPath)
    }

    func testLogUpdated_doesNothingWhenDisabled() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { false })
        let taskID = UUID()

        let changes = [FieldChange(field: "title", oldValue: "A", newValue: "B")]
        logger.logUpdated(taskID: taskID, changes: changes)

        let exists = FileManager.default.fileExists(atPath: logPath.path)
        XCTAssertFalse(exists, "Log file should not be created when disabled")
        cleanup(logPath)
    }

    // MARK: - Log Management

    func testGetLog_returnsAllEntries() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })
        let id1 = UUID()
        let id2 = UUID()

        logger.logCreated(taskID: id1, title: "Task 1")
        logger.logCompleted(taskID: id2, title: "Task 2")

        let log = logger.getLog()
        XCTAssertTrue(log.contains(id1.uuidString))
        XCTAssertTrue(log.contains(id2.uuidString))
        XCTAssertTrue(log.contains("[created]"))
        XCTAssertTrue(log.contains("[completed]"))
        cleanup(logPath)
    }

    func testClearLog_removesAllEntries() {
        let logPath = makeTestLogPath()
        let logger = TaskLifecycleLogger(logFileURL: logPath, isEnabled: { true })

        logger.logCreated(taskID: UUID(), title: "Temp")
        logger.clearLog()

        let exists = FileManager.default.fileExists(atPath: logPath.path)
        XCTAssertFalse(exists, "Log file should be removed after clearLog()")
        cleanup(logPath)
    }

    // MARK: - FieldChange

    func testFieldChange_formatsCorrectly() {
        let change = FieldChange(field: "duration", oldValue: "15", newValue: "30")
        XCTAssertEqual(change.formatted, "duration=\"15\"→\"30\"")
    }
}
