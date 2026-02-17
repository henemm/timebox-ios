import XCTest
import SwiftUI
@testable import FocusBlox

/// Unit Tests for CategoryIconBadge shared component
/// TDD RED: These tests MUST FAIL because CategoryIconBadge doesn't exist yet
final class CategoryIconBadgeTests: XCTestCase {

    /// GIVEN: A TaskCategory
    /// WHEN: Creating a CategoryIconBadge
    /// THEN: It can be instantiated for every category
    func testBadge_canBeCreatedForAllCategories() {
        for category in TaskCategory.allCases {
            let badge = CategoryIconBadge(category: category)
            XCTAssertNotNil(badge, "Badge should be creatable for \(category.rawValue)")
        }
    }

    /// GIVEN: CategoryIconBadge for .income
    /// WHEN: Accessing the category property
    /// THEN: It holds the correct category
    func testBadge_holdsCorrectCategory() {
        let badge = CategoryIconBadge(category: .income)
        XCTAssertEqual(badge.category.icon, "dollarsign.circle")
        XCTAssertEqual(badge.category.color, .green)
    }

    /// GIVEN: CategoryIconBadge for .selfCare
    /// WHEN: Accessing the category property
    /// THEN: Icon and color match TaskCategory definition
    func testBadge_selfCare_matchesTaskCategory() {
        let badge = CategoryIconBadge(category: .selfCare)
        XCTAssertEqual(badge.category.icon, "heart.circle")
        XCTAssertEqual(badge.category.color, .cyan)
    }
}
