import XCTest
@testable import FocusBlox

/// CTC-4: Tests for ClipboardHelper mock text parsing
/// The only testable business logic in this feature — extracting clipboard mock text from launch arguments
final class ClipboardHelperTests: XCTestCase {

    /// Verhalten: Returns mock text when -MockClipboard argument is followed by text
    /// Bricht wenn: ClipboardHelper.mockText(from:) index math is wrong or key is changed
    func test_mockText_returnsTextAfterFlag() {
        let args = ["app", "-UITesting", "-MockClipboard", "Buy groceries"]
        let result = ClipboardHelper.mockText(from: args)
        XCTAssertEqual(result, "Buy groceries")
    }

    /// Verhalten: Returns nil when -MockClipboard flag is absent
    /// Bricht wenn: ClipboardHelper returns non-nil for missing flag
    func test_mockText_returnsNilWhenFlagMissing() {
        let args = ["app", "-UITesting"]
        let result = ClipboardHelper.mockText(from: args)
        XCTAssertNil(result)
    }

    /// Verhalten: Returns nil when -MockClipboard is the last argument (no text follows)
    /// Bricht wenn: ClipboardHelper doesn't check bounds (index out of range crash)
    func test_mockText_returnsNilWhenFlagIsLastArg() {
        let args = ["app", "-MockClipboard"]
        let result = ClipboardHelper.mockText(from: args)
        XCTAssertNil(result)
    }
}
