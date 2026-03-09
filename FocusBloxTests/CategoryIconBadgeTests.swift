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

    // MARK: - Two-line badge with label

    /// Bug 79: CategoryIconBadge should use displayName (English) not localizedName (German)
    /// GIVEN: CategoryIconBadge for .income
    /// WHEN: Accessing labelText
    /// THEN: Returns the English display name ("Earn"), not German ("Geld")
    /// BREAKS: labelText currently returns localizedName ("Geld")
    func testBadge_labelText_returnsDisplayName() {
        let badge = CategoryIconBadge(category: .income)
        XCTAssertEqual(badge.labelText, "Earn",
            "Bug 79: Badge should show English displayName, not German localizedName")
    }

    /// Bug 79: All categories should show English displayName on badges
    /// BREAKS: All currently show German localizedName
    func testBadge_labelText_allCategoriesShowEnglishDisplayName() {
        let expectedLabels: [(TaskCategory, String)] = [
            (.income, "Earn"),
            (.essentials, "Essentials"),
            (.selfCare, "Self Care"),
            (.learn, "Learn"),
            (.social, "Social"),
        ]
        for (category, expectedLabel) in expectedLabels {
            let badge = CategoryIconBadge(category: category)
            XCTAssertEqual(badge.labelText, expectedLabel,
                "Bug 79: \(category.rawValue) badge should show '\(expectedLabel)'")
        }
    }

    /// GIVEN: CategoryIconBadge for all categories
    /// WHEN: Accessing labelText
    /// THEN: All labels are short enough for a badge (max 10 chars for "Essentials")
    func testBadge_labelText_allCategoriesAreBadgeFriendly() {
        for category in TaskCategory.allCases {
            let badge = CategoryIconBadge(category: category)
            XCTAssertLessThanOrEqual(
                badge.labelText.count, 10,
                "\(category.rawValue) label '\(badge.labelText)' too long for badge"
            )
        }
    }
}
