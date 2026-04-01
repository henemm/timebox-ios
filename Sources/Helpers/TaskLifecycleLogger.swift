import Foundation

/// Tracks task lifecycle events (create/update/delete/complete) to a log file.
/// Only active when the debug mode toggle is enabled — zero I/O overhead when off.
final class TaskLifecycleLogger: Sendable {

    @MainActor static let shared = TaskLifecycleLogger()

    private let logFileURL: URL
    private let isEnabled: @Sendable () -> Bool

    init(
        logFileURL: URL? = nil,
        isEnabled: @Sendable @escaping () -> Bool = {
            UserDefaults.standard.bool(forKey: "taskDebugModeEnabled")
        }
    ) {
        self.logFileURL = logFileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("task-lifecycle.log")
        self.isEnabled = isEnabled
    }

    // MARK: - Lifecycle Events

    func logCreated(taskID: UUID, title: String) {
        guard isEnabled() else { return }
        write("[created] taskID=\(taskID.uuidString) title=\"\(title)\"")
    }

    func logUpdated(taskID: UUID, changes: [FieldChange]) {
        guard isEnabled(), !changes.isEmpty else { return }
        let fields = changes.map(\.formatted).joined(separator: " ")
        write("[updated] taskID=\(taskID.uuidString) \(fields)")
    }

    func logDeleted(taskID: UUID, title: String) {
        guard isEnabled() else { return }
        write("[deleted] taskID=\(taskID.uuidString) title=\"\(title)\"")
    }

    func logCompleted(taskID: UUID, title: String) {
        guard isEnabled() else { return }
        write("[completed] taskID=\(taskID.uuidString) title=\"\(title)\"")
    }

    func logUncompleted(taskID: UUID, title: String) {
        guard isEnabled() else { return }
        write("[uncompleted] taskID=\(taskID.uuidString) title=\"\(title)\"")
    }

    func logEnriched(taskID: UUID, changes: [FieldChange]) {
        guard isEnabled(), !changes.isEmpty else { return }
        let fields = changes.map(\.formatted).joined(separator: " ")
        write("[enriched] taskID=\(taskID.uuidString) \(fields)")
    }

    // MARK: - Log Management

    func getLog() -> String {
        (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
    }

    func clearLog() {
        try? FileManager.default.removeItem(at: logFileURL)
    }

    func logPath() -> URL {
        logFileURL
    }

    // MARK: - Private

    private func write(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }
}

/// Represents a single field change for update/enrichment logging.
struct FieldChange: Sendable {
    let field: String
    let oldValue: String
    let newValue: String

    var formatted: String {
        "\(field)=\"\(oldValue)\"→\"\(newValue)\""
    }
}
