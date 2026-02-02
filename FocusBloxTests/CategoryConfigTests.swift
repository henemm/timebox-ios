import XCTest
@testable import FocusBlox

/// Unit Tests for CategoryConfig - Phase 2: "unbekannt" category
final class CategoryConfigTests: XCTestCase {

    // MARK: - "unbekannt" Category Tests

    /// Test that "unknown" category exists
    func testUnknownCategoryExists() {
        // EXPECTED TO FAIL: unknown case doesn't exist yet
        let unknown = CategoryConfig(rawValue: "unknown")
        XCTAssertNotNil(unknown, "CategoryConfig should have 'unknown' case")
    }

    /// Test "unknown" category has correct display name
    func testUnknownCategoryDisplayName() {
        // EXPECTED TO FAIL: unknown case doesn't exist yet
        guard let unknown = CategoryConfig(rawValue: "unknown") else {
            XCTFail("CategoryConfig.unknown should exist")
            return
        }
        XCTAssertEqual(unknown.displayName, "Unbekannt", "Display name should be 'Unbekannt'")
    }

    /// Test "unknown" category has an icon
    func testUnknownCategoryIcon() {
        guard let unknown = CategoryConfig(rawValue: "unknown") else {
            XCTFail("CategoryConfig.unknown should exist")
            return
        }
        XCTAssertFalse(unknown.icon.isEmpty, "Unknown category should have an icon")
    }

    /// Test "unknown" category has a color
    func testUnknownCategoryColor() {
        guard let unknown = CategoryConfig(rawValue: "unknown") else {
            XCTFail("CategoryConfig.unknown should exist")
            return
        }
        // Color should be gray/secondary for unknown
        XCTAssertNotNil(unknown.color, "Unknown category should have a color")
    }

    /// Test all cases count (should be 6 with unknown)
    func testAllCasesCount() {
        // EXPECTED TO FAIL: Currently 5 cases, should be 6
        XCTAssertEqual(CategoryConfig.allCases.count, 6, "Should have 6 categories including 'unknown'")
    }

    // MARK: - Existing Categories Still Work

    /// Verify existing categories still work correctly
    func testExistingCategoriesStillWork() {
        XCTAssertNotNil(CategoryConfig(rawValue: "income"))
        XCTAssertNotNil(CategoryConfig(rawValue: "maintenance"))
        XCTAssertNotNil(CategoryConfig(rawValue: "recharge"))
        XCTAssertNotNil(CategoryConfig(rawValue: "learning"))
        XCTAssertNotNil(CategoryConfig(rawValue: "giving_back"))
    }
}
