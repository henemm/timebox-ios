import XCTest

/// UI Tests for Bug: Missing drop indicator when dragging FocusBlocks on iOS timeline
///
/// macOS has a DropPreviewIndicator (blue line + time label). iOS has nothing.
///
/// TDD RED: These tests FAIL because the drop indicator does not exist yet.
final class FocusBlockDropIndicatorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToBloxTab() -> XCUIElement? {
        let bloxTab = app.tabBars.buttons["Blox"]
        guard bloxTab.waitForExistence(timeout: 5) else { return nil }
        bloxTab.tap()
        sleep(3)

        let timeline = app.scrollViews["planningTimeline"]
        guard timeline.waitForExistence(timeout: 5) else { return nil }
        return timeline
    }

    // MARK: - Drop Indicator Tests

    /// GIVEN: A timeline with FocusBlocks exists
    /// WHEN: The canvas drop zone is available
    /// THEN: A dropIndicator element should exist in the view hierarchy
    ///       (it becomes visible during drag via isTargeted callback)
    func testDropIndicatorElementExistsInTimeline() throws {
        guard let timeline = navigateToBloxTab() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "DropIndicator-Timeline"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The drop indicator should exist in the hierarchy (hidden when not dragging)
        let dropIndicator = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'dropPreviewIndicator'"))
            .firstMatch

        XCTAssertTrue(
            dropIndicator.waitForExistence(timeout: 3),
            "Drop preview indicator element should exist in timeline hierarchy"
        )
    }

    /// GIVEN: Timeline with canvas drop zone
    /// WHEN: Drop zone is checked
    /// THEN: canvasDropZone has the correct accessibility identifier
    func testCanvasDropZoneExists() throws {
        guard let timeline = navigateToBloxTab() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        let dropZone = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'canvasDropZone'"))
            .firstMatch

        XCTAssertTrue(
            dropZone.waitForExistence(timeout: 3),
            "Canvas drop zone should exist in timeline"
        )
    }
}
