import XCTest
@testable import FocusBlox

/// Unit tests for NextUp swipe action callbacks
final class NextUpSwipeActionsTests: XCTestCase {

    /// GIVEN: NextUpSection is created with edit/delete callbacks
    /// THEN: The callbacks should be optional and not required
    /// EXPECTED TO FAIL: onEditTask and onDeleteTask don't exist yet
    func testNextUpSectionAcceptsEditAndDeleteCallbacks() {
        // This test verifies that NextUpSection can be initialized
        // with the new onEditTask and onDeleteTask callbacks
        let section = NextUpSection(
            tasks: [],
            onRemoveFromNextUp: { _ in },
            onEditTask: { _ in },
            onDeleteTask: { _ in }
        )
        XCTAssertNotNil(section, "NextUpSection should accept edit and delete callbacks")
    }
}
