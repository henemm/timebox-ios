import XCTest

/// Bug 70a: FocusBlock times must snap to 15-minute boundaries.
///
/// KEY TEST: Mock data includes an "unaligned" block at 09:13-10:47 (94 min).
/// When EditFocusBlockSheet opens, snapToQuarterHour() snaps to 09:15-10:45 (90 min).
/// Without the fix, duration would show "94 Min" (not a multiple of 15).
/// With the fix, duration shows "1 Std 30 Min" (90 min = multiple of 15).
final class Bug70aSnapUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    private func navigateToBloxTab() {
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab should exist")
        bloxTab.tap()
    }

    /// Find the duration text in the current sheet (format: "Dauer: X Min" or "Dauer: X Std Y Min")
    private func findDurationMinutes() -> Int? {
        let durationLabels = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Dauer:'")
        )
        guard durationLabels.firstMatch.waitForExistence(timeout: 3) else { return nil }
        let text = durationLabels.firstMatch.label

        // Parse "Dauer: 45 Min" → 45
        // Parse "Dauer: 1 Std 30 Min" → 90
        // Parse "Dauer: 2 Std" → 120
        var total = 0

        if let range = text.range(of: #"(\d+) Std"#, options: .regularExpression) {
            let numStr = text[range].replacingOccurrences(of: " Std", with: "")
            total += (Int(numStr) ?? 0) * 60
        }
        if let range = text.range(of: #"(\d+) Min"#, options: .regularExpression) {
            let numStr = text[range].replacingOccurrences(of: " Min", with: "")
            total += Int(numStr) ?? 0
        }

        return total > 0 ? total : nil
    }

    // MARK: - Tests

    /// CRITICAL TEST: Opens EditSheet for the UNALIGNED block (09:13-10:47 = 94 min).
    /// Without snapping: duration = 94 min (94 % 15 = 4 ≠ 0) → FAIL
    /// With snapping: init snaps to 09:15-10:45 → duration = 90 min (90 % 15 = 0) → PASS
    ///
    /// This test WOULD FAIL without the Bug 70a fix because:
    /// - Mock block "mock-block-unaligned" has startDate=09:13, endDate=10:47
    /// - Without snapToQuarterHour() in init, DatePicker shows 09:13-10:47 = 94 min
    /// - 94 is NOT a multiple of 15
    func testEditSheetSnapsUnalignedBlockTo15MinGrid() {
        navigateToBloxTab()

        let timeline = app.scrollViews["planningTimeline"]
        guard timeline.waitForExistence(timeout: 5) else {
            XCTFail("Timeline should exist")
            return
        }

        // Find the unaligned block's edit button specifically
        let editButton = timeline.buttons["focusBlockEditButton_mock-block-unaligned"]
        if !editButton.waitForExistence(timeout: 5) {
            timeline.swipeUp()
        }
        guard editButton.waitForExistence(timeout: 3) else {
            XCTFail("Unaligned block edit button should exist (mock-block-unaligned)")
            return
        }
        editButton.tap()

        // Verify edit sheet opened
        let title = app.staticTexts["Block bearbeiten"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Edit sheet should open")

        // THE ACTUAL SNAPPING TEST:
        // 09:13→09:15, 10:47→10:45 → duration = 90 min
        guard let minutes = findDurationMinutes() else {
            XCTFail("Should find 'Dauer:' label in edit sheet")
            return
        }

        XCTAssertEqual(minutes % 15, 0,
                       "Unaligned block duration \(minutes) min must be multiple of 15 after snapping. " +
                       "Original was 94 min (09:13-10:47), expected 90 min (09:15-10:45)")
        XCTAssertEqual(minutes, 90,
                       "Snapped duration should be 90 min (09:15 to 10:45), got \(minutes)")
    }

    /// Verifies that an already-aligned block (09:00-11:00) stays unchanged after snapping.
    func testEditSheetPreservesAlignedBlockDuration() {
        navigateToBloxTab()

        let timeline = app.scrollViews["planningTimeline"]
        guard timeline.waitForExistence(timeout: 5) else {
            XCTFail("Timeline should exist")
            return
        }

        // Find block-1 (09:00-11:00, already aligned)
        let editButton = timeline.buttons["focusBlockEditButton_mock-block-1"]
        if !editButton.waitForExistence(timeout: 5) {
            timeline.swipeUp()
        }
        guard editButton.waitForExistence(timeout: 3) else {
            XCTFail("Block 1 edit button should exist")
            return
        }
        editButton.tap()

        let title = app.staticTexts["Block bearbeiten"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Edit sheet should open")

        guard let minutes = findDurationMinutes() else {
            XCTFail("Should find 'Dauer:' label")
            return
        }

        XCTAssertEqual(minutes, 120,
                       "Already-aligned block (09:00-11:00) should stay at 120 min, got \(minutes)")
    }

    /// Verifies CreateSheet opens from a free slot with snapped duration.
    func testCreateSheetFromFreeSlotHasSnappedDuration() {
        navigateToBloxTab()

        let timeline = app.scrollViews["planningTimeline"]
        guard timeline.waitForExistence(timeout: 5) else { return }

        let freeSlot = timeline.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch
        guard freeSlot.waitForExistence(timeout: 3) else { return }
        freeSlot.tap()

        let title = app.staticTexts["FocusBlox erstellen"]
        guard title.waitForExistence(timeout: 3) else {
            XCTFail("Create sheet should open")
            return
        }

        guard let minutes = findDurationMinutes() else {
            XCTFail("Should find 'Dauer:' label")
            return
        }

        XCTAssertEqual(minutes % 15, 0,
                       "Create sheet duration \(minutes) min must be multiple of 15")
    }
}
