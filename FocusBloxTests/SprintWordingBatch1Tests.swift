import XCTest
import Foundation

/// Tests for Sprint → FocusBlox wording replacement (Batch 1, Bug #224)
///
/// Verifies that user-visible "Sprint" strings have been replaced in batch 1 files.
/// Uses source file scanning since these are pure string replacements.
@MainActor
final class SprintWordingBatch1Tests: XCTestCase {

    private let batch1Files = [
        "FocusLiveView.swift",
        "DailyReviewView.swift",
        "SprintReviewSheet.swift",
        "SprintPickerSheet.swift",
        "CoachView.swift",
    ]

    private func sourceRoot() -> URL {
        // Navigate from test bundle to project root
        var url = Bundle.main.bundleURL
        while url.pathComponents.count > 3 && !FileManager.default.fileExists(atPath: url.appendingPathComponent("Sources").path) {
            url = url.deletingLastPathComponent()
        }
        return url
    }

    private func findFile(_ name: String, in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == name {
                return fileURL
            }
        }
        return nil
    }

    func test_noUserVisibleSprintStrings_inBatch1Files() throws {
        let root = sourceRoot()
        let sourcesDir = root.appendingPathComponent("Sources")

        guard FileManager.default.fileExists(atPath: sourcesDir.path) else {
            // Running in CI or different context — skip gracefully
            throw XCTSkip("Sources directory not found at \(sourcesDir.path)")
        }

        // Patterns that indicate user-visible "Sprint" text (not variable names)
        let forbiddenPatterns = [
            "\"Sprint",           // String starting with Sprint
            "Sprint\"",           // String ending with Sprint
            "\"Focus Sprint",     // "Focus Sprint..."
            "Sprint Review",      // Sprint Review in any string
            "Sprint starten",     // Sprint starten
            "Sprint beendet",     // Sprint beendet
            "Sprint läuft",       // Sprint läuft
            "Sprint blockiert",   // Sprint blockiert
            "Sprint konnte",      // Sprint konnte nicht...
            "Ohne Sprint",        // Ohne Sprint erledigt
        ]

        var violations: [String] = []

        for fileName in batch1Files {
            guard let fileURL = findFile(fileName, in: sourcesDir) else {
                XCTFail("File not found: \(fileName)")
                continue
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                // Skip comments and variable declarations
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") || trimmed.hasPrefix("*") {
                    continue
                }

                for pattern in forbiddenPatterns {
                    if line.contains(pattern) {
                        violations.append("\(fileName):\(index + 1) contains '\(pattern)': \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found \(violations.count) user-visible 'Sprint' string(s):\n\(violations.joined(separator: "\n"))")
    }
}
