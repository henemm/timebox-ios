import XCTest
@testable import FocusBlox

/// Unit Tests for ImportancePicker and CategoryPicker
///
/// Tests verify the picker data models and selection logic.
///
/// TDD RED: These tests WILL FAIL because the picker views don't exist yet.
final class QuickEditPickerTests: XCTestCase {

    // MARK: - ImportancePicker Tests

    /// Test: ImportancePicker provides correct options (Low=1, Medium=2, High=3)
    /// EXPECTED TO FAIL: ImportancePicker doesn't exist yet
    func testImportancePickerOptions() throws {
        let options = ImportancePickerOption.allCases
        XCTAssertEqual(options.count, 3, "ImportancePicker should have 3 options")
        XCTAssertEqual(options[0].rawValue, 1, "First option should be Low (1)")
        XCTAssertEqual(options[1].rawValue, 2, "Second option should be Medium (2)")
        XCTAssertEqual(options[2].rawValue, 3, "Third option should be High (3)")
    }

    /// Test: ImportancePicker options have correct display names
    /// EXPECTED TO FAIL: ImportancePicker doesn't exist yet
    func testImportancePickerDisplayNames() throws {
        XCTAssertEqual(ImportancePickerOption.low.displayName, "Niedrig")
        XCTAssertEqual(ImportancePickerOption.medium.displayName, "Mittel")
        XCTAssertEqual(ImportancePickerOption.high.displayName, "Hoch")
    }

    /// Test: ImportancePicker options have correct emoji icons
    /// EXPECTED TO FAIL: ImportancePicker doesn't exist yet
    func testImportancePickerIcons() throws {
        XCTAssertEqual(ImportancePickerOption.low.icon, "🟦")
        XCTAssertEqual(ImportancePickerOption.medium.icon, "🟨")
        XCTAssertEqual(ImportancePickerOption.high.icon, "🔴")
    }

    // MARK: - CategoryPicker Tests

    /// Test: CategoryPicker provides correct options (5 Lebensarbeit categories)
    /// EXPECTED TO FAIL: CategoryPicker doesn't exist yet
    func testCategoryPickerOptions() throws {
        let options = CategoryPickerOption.allCases
        XCTAssertEqual(options.count, 5, "CategoryPicker should have 5 options")

        let rawValues = options.map { $0.rawValue }
        XCTAssertTrue(rawValues.contains("income"))
        XCTAssertTrue(rawValues.contains("maintenance"))
        XCTAssertTrue(rawValues.contains("recharge"))
        XCTAssertTrue(rawValues.contains("learning"))
        XCTAssertTrue(rawValues.contains("giving_back"))
    }

    /// Test: CategoryPicker options have display names
    /// EXPECTED TO FAIL: CategoryPicker doesn't exist yet
    func testCategoryPickerDisplayNames() throws {
        XCTAssertEqual(CategoryPickerOption.income.displayName, "Einkommen")
        XCTAssertEqual(CategoryPickerOption.maintenance.displayName, "Maintenance")
        XCTAssertEqual(CategoryPickerOption.recharge.displayName, "Recharge")
        XCTAssertEqual(CategoryPickerOption.learning.displayName, "Lernen")
        XCTAssertEqual(CategoryPickerOption.givingBack.displayName, "Giving Back")
    }

    /// Test: CategoryPicker options have SF Symbol icons
    /// EXPECTED TO FAIL: CategoryPicker doesn't exist yet
    func testCategoryPickerIcons() throws {
        // Each category should have a non-empty SF Symbol name
        for option in CategoryPickerOption.allCases {
            XCTAssertFalse(option.sfSymbol.isEmpty, "\(option.rawValue) should have an SF Symbol")
        }
    }
}
