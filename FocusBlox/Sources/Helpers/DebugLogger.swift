import Foundation

/// Simple file-based debug logger for investigating issues
/// Logs are written to a temp file that can be read during testing
enum DebugLogger {
    private static let logFile: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("timebox-debug.log")
    }()

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }

        // Also print to console
        print(message)
    }

    static func getLogPath() -> String {
        return logFile.path
    }

    static func clearLog() {
        try? FileManager.default.removeItem(at: logFile)
    }

    static func readLog() -> String {
        (try? String(contentsOf: logFile, encoding: .utf8)) ?? "No logs yet"
    }
}
