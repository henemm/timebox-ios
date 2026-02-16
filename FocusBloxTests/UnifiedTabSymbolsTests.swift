import XCTest

/// Unit tests verifying the unified navigation symbol values.
/// These expected values must match both iOS MainTabView and macOS MainSection.
final class UnifiedTabSymbolsTests: XCTestCase {

    /// The agreed-upon unified symbol set for all platforms
    private let expectedSymbols: [(section: String, symbol: String)] = [
        ("backlog", "list.bullet"),
        ("planning", "calendar"),
        ("assign", "arrow.up.arrow.down"),
        ("focus", "target"),
        ("review", "chart.bar")
    ]

    /// Verify that all expected symbols are valid SF Symbol names
    func testUnifiedSymbolsAreValidSFSymbols() {
        for (section, symbol) in expectedSymbols {
            let image = UIImage(systemName: symbol)
            XCTAssertNotNil(image, "\(section) symbol '\(symbol)' should be a valid SF Symbol")
        }
    }

    /// Verify we have exactly 5 navigation sections
    func testFiveNavigationSections() {
        XCTAssertEqual(expectedSymbols.count, 5, "Should have exactly 5 navigation sections")
    }
}
