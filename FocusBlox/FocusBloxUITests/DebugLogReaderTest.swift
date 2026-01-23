import XCTest

/// Test to read and display debug logs created during UI testing
final class DebugLogReaderTest: XCTestCase {

    func testReadDebugLogs() throws {
        // This test just outputs where to find logs
        // Run this AFTER running the timeline tests

        // Get temp directory path
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("timebox-debug.log")

        print("📍 Log file location: \(logFile.path)")

        if FileManager.default.fileExists(atPath: logFile.path) {
            let logs = try String(contentsOf: logFile, encoding: .utf8)
            print("📄 Debug Logs:\n")
            print(logs)
            print("\n📄 End of logs")
        } else {
            print("⚠️  No log file found at: \(logFile.path)")
            print("⚠️  Logs may be in simulator-specific location")

            // Try to find it
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: tempDir.path) {
                print("📁 Temp directory contents:")
                for item in contents.prefix(10) {
                    print("  - \(item)")
                }
            }
        }

        // Always pass - this is just for info
        XCTAssertTrue(true, "Log reader test completed")
    }
}
