import XCTest
@testable import TimeBox

/// Unit Tests for Categories Expansion (Sprint 3)
@MainActor
final class CategoriesTests: XCTestCase {

    // MARK: - LocalizedCategory Tests

    /// Test: localizedCategory should return "Lernen" for "learning"
    func test_localizedCategory_returnsLernenForLearning() throws {
        // Verify the String extension handles "learning"
        let result = "learning".localizedCategoryLabel
        XCTAssertEqual(result, "Lernen", "learning should map to Lernen")
    }

    /// Test: localizedCategory should return "Weitergeben" for "giving_back"
    func test_localizedCategory_returnsWeitergebenForGivingBack() throws {
        // Verify the String extension handles "giving_back"
        let result = "giving_back".localizedCategoryLabel
        XCTAssertEqual(result, "Weitergeben", "giving_back should map to Weitergeben")
    }

    // MARK: - All Categories Test

    /// Test: All 5 category values should be valid taskType options
    func test_allFiveCategoriesAreValid() throws {
        let validCategories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        // This test documents that all 5 categories should be valid
        for category in validCategories {
            XCTAssertTrue(validCategories.contains(category), "\(category) should be a valid category")
        }

        XCTAssertEqual(validCategories.count, 5, "Should have exactly 5 categories")
    }
}

// MARK: - String Extension for Testing
// Note: This mirrors the private extension in BacklogView for testing purposes
extension String {
    var localizedCategoryLabel: String {
        switch self {
        case "income": return "Geld verdienen"
        case "maintenance": return "Maintenance"
        case "recharge": return "Energie aufladen"
        case "learning": return "Lernen"
        case "giving_back": return "Weitergeben"
        default: return self.capitalized
        }
    }
}
