import XCTest
@testable import FocusBlox

/// Tests for Bug: FocusBlock title not updating after time change
///
/// Root Cause: `updateFocusBlockTime()` only updates startDate/endDate,
/// but NOT the event title. The title "FocusBlox 09:00" stays stale after move.
///
/// TDD RED: These tests FAIL because `FocusBlock.generateTitle(for:)` does not exist yet,
/// and `EventKitRepository.updateFocusBlockTime()` does not update the title.
final class FocusBlockTitleUpdateTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Title Generation

    /// FocusBlock should have a static method to generate a title from a start time
    /// Expected: "FocusBlox 09:00" for a 9 AM block (German locale)
    func test_generateTitle_fromStartDate() {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        let title = FocusBlock.generateTitle(for: startDate)

        // Title must contain "FocusBlox" prefix
        XCTAssertTrue(title.hasPrefix("FocusBlox "), "Title should start with 'FocusBlox '")
        // Title must contain the formatted time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let expectedTime = formatter.string(from: startDate)
        XCTAssertEqual(title, "FocusBlox \(expectedTime)")
    }

    /// Title generation for afternoon time
    func test_generateTitle_afternoonTime() {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: today)!

        let title = FocusBlock.generateTitle(for: startDate)

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let expectedTime = formatter.string(from: startDate)
        XCTAssertEqual(title, "FocusBlox \(expectedTime)")
    }

    // MARK: - Title Update After Move

    /// After moving a block via drag, the title should reflect the new start time
    /// This tests the complete flow: old title → move → new title
    func test_titleChanges_afterMove() {
        let today = calendar.startOfDay(for: Date())
        let oldStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        let oldTitle = FocusBlock.generateTitle(for: oldStart)

        // Simulate move to 14:00
        let newStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let newTitle = FocusBlock.generateTitle(for: newStart)

        XCTAssertNotEqual(oldTitle, newTitle, "Title must change when start time changes")

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        XCTAssertTrue(newTitle.contains(formatter.string(from: newStart)),
                      "New title must contain the new start time")
    }

    // MARK: - Mock Repository Title Update

    /// MockEventKitRepository should track title updates when time changes
    func test_mockRepository_tracksTitleUpdate() {
        let mock = MockEventKitRepository()
        mock.mockCalendarAuthStatus = .fullAccess

        let today = calendar.startOfDay(for: Date())
        let newStart = calendar.date(byAdding: .hour, value: 16, to: today)!
        let newEnd = calendar.date(byAdding: .hour, value: 18, to: today)!

        XCTAssertNoThrow(try mock.updateFocusBlockTime(eventID: "block-1", startDate: newStart, endDate: newEnd))

        // The mock should also track that a title was generated
        XCTAssertNotNil(mock.lastUpdatedFocusBlockTitle, "Mock should track the updated title")

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let expectedTitle = "FocusBlox \(formatter.string(from: newStart))"
        XCTAssertEqual(mock.lastUpdatedFocusBlockTitle, expectedTitle,
                       "Updated title should match 'FocusBlox' + new start time")
    }
}
