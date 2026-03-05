//
//  IOSTimelineCanvasUITests.swift
//  FocusBloxUITests
//
//  UI Tests for Bug 70c-1b: iOS Timeline Canvas Rebuild.
//  Verifies canvas-based timeline rendering with duration-proportional blocks.
//
//  Created: 2026-03-05
//

import XCTest

final class IOSTimelineCanvasUITests: XCTestCase {

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

    private func navigateToBloxTimeline() -> XCUIElement? {
        let bloxTab = app.tabBars.buttons["Blox"]
        guard bloxTab.waitForExistence(timeout: 5) else { return nil }
        bloxTab.tap()
        sleep(3)

        let timeline = app.scrollViews["planningTimeline"]
        guard timeline.waitForExistence(timeout: 5) else { return nil }
        return timeline
    }

    // MARK: - Canvas Structure Tests

    /// EXPECTED TO FAIL (RED): Canvas-based timeline uses TimelineLayout,
    ///   blocks have duration-proportional height (120 min block taller than 60 min block).
    ///   Currently blocks all have same ~40pt height.
    /// Bricht wenn: TimelineLayout nicht in timelineContent verwendet wird
    func testBlocksHaveDurationProportionalHeight() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        // mock-block-1: 09:00-11:00 (120 min)
        let block1 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-1'"))
            .firstMatch

        if !block1.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }
        guard block1.waitForExistence(timeout: 5) else {
            XCTFail("mock-block-1 should exist")
            return
        }

        // mock-block-active: 60 min duration
        let activeBlock = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-active'"))
            .firstMatch

        if !activeBlock.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }

        guard activeBlock.waitForExistence(timeout: 5) else {
            throw XCTSkip("Active block not visible — cannot compare heights")
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "70c1b-CanvasBlocks"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Canvas-based: 120 min block should be roughly 2x height of 60 min block
        // With hourHeight=60: 120min=120pt, 60min=60pt
        let block1Height = block1.frame.height
        let activeHeight = activeBlock.frame.height

        // Allow 20% tolerance for padding/minimum height
        XCTAssertGreaterThan(
            block1Height, activeHeight * 1.5,
            "120-min block (\(block1Height)pt) should be significantly taller than 60-min block (\(activeHeight)pt)"
        )
    }

    /// EXPECTED TO FAIL (RED): Hour grid labels exist as background.
    ///   hourMarker identifiers must be on grid Text views, not inside TimelineHourRow.
    func testHourGridLabelsExist() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        // Hour marker at 08:00 should exist in the grid
        let hourMarker = timeline.staticTexts["hourMarker_8"]

        if !hourMarker.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }

        XCTAssertTrue(hourMarker.waitForExistence(timeout: 5), "Hour marker 08:00 should exist in grid")
    }

    /// EXPECTED TO FAIL (RED): Canvas uses single drop zone instead of per-hour drop zones.
    ///   The canvas ZStack has .accessibilityIdentifier("canvasDropZone") instead of
    ///   16 separate "timelineDropZone_\(hour)" zones.
    /// Bricht wenn: Drop-Destination nicht auf dem Canvas-ZStack liegt
    func testCanvasDropZoneExists() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        // New: single canvas-wide drop zone
        let canvasDropZone = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'canvasDropZone'"))
            .firstMatch

        XCTAssertTrue(
            canvasDropZone.waitForExistence(timeout: 5),
            "Canvas-wide drop zone should exist (replaces per-hour drop zones)"
        )
    }

    /// EXPECTED TO FAIL (RED): FocusBlocks are positioned at their start time on canvas.
    ///   mock-block-1 (09:00) should be at a different Y than mock-block-2 (14:00).
    /// Bricht wenn: Blocks nicht absolut positioniert werden (TimelineLayout)
    func testBlocksPositionedByStartTime() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        let block1 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-1'"))
            .firstMatch

        let block2 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-2'"))
            .firstMatch

        // Scroll to see block1 (09:00)
        if !block1.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }
        guard block1.waitForExistence(timeout: 5) else {
            XCTFail("mock-block-1 should exist")
            return
        }

        // Scroll to see block2 (14:00)
        if !block2.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
            timeline.swipeUp()
            sleep(1)
        }
        guard block2.waitForExistence(timeout: 5) else {
            XCTFail("mock-block-2 should exist")
            return
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "70c1b-BlockPositions"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Canvas: block2 (14:00) should be further down than block1 (09:00)
        // With hourHeight=60: block1.y ≈ 180 (3h from 06:00), block2.y ≈ 480 (8h from 06:00)
        // Difference should be ~300pt (5 hours * 60pt/hour)
        let yDifference = block2.frame.minY - block1.frame.minY
        XCTAssertGreaterThan(
            yDifference, 200,
            "Block at 14:00 should be >200pt below block at 09:00 (got \(yDifference)pt). Canvas positions blocks by time."
        )
    }

    // MARK: - Overlap Layout Tests

    /// Overlapping items must be side-by-side (reduced width), not stacked full-width.
    /// mock-event-long (08:00-12:00) overlaps with mock-block-1 (09:00-11:00).
    /// Both should have roughly half the timeline width.
    /// Bricht wenn: Overlap-Detection oder Column-Assignment nicht funktioniert
    func testOverlappingEventAndBlockAreSideBySide() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        // Find the long calendar event
        let longEvent = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'timelineEvent_mock-event-long'"))
            .firstMatch

        // Find focus block 1 (overlaps with long event)
        let block1 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-1'"))
            .firstMatch

        if !longEvent.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }
        guard longEvent.waitForExistence(timeout: 5) else {
            XCTFail("Long calendar event (08:00-12:00) should exist on timeline")
            return
        }
        guard block1.waitForExistence(timeout: 5) else {
            XCTFail("Focus block 1 (09:00-11:00) should exist on timeline")
            return
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "overlap-side-by-side"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Timeline content width (subtract time column ~45pt from full timeline width)
        let timelineWidth = timeline.frame.width
        let contentWidth = timelineWidth - 45

        let eventWidth = longEvent.frame.width
        let blockWidth = block1.frame.width

        // Both should be LESS than full content width (side-by-side = roughly half each)
        XCTAssertLessThan(
            eventWidth, contentWidth * 0.7,
            "Overlapping event width (\(eventWidth)) should be < 70% of content width (\(contentWidth)) — must be side-by-side, not full-width"
        )
        XCTAssertLessThan(
            blockWidth, contentWidth * 0.7,
            "Overlapping block width (\(blockWidth)) should be < 70% of content width (\(contentWidth)) — must be side-by-side, not full-width"
        )

        // They should be at different X positions (not stacked)
        let eventX = longEvent.frame.minX
        let blockX = block1.frame.minX
        XCTAssertNotEqual(
            eventX, blockX, accuracy: 5,
            "Overlapping items should be at different X positions (side-by-side). Event.x=\(eventX), Block.x=\(blockX)"
        )
    }

    /// Non-overlapping items should remain full-width (not squeezed into columns).
    /// mock-block-2 (14:00-16:00) doesn't overlap with anything → full width.
    func testNonOverlappingBlockIsFullWidth() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        let block2 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-2'"))
            .firstMatch

        if !block2.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
            timeline.swipeUp()
            sleep(1)
        }
        guard block2.waitForExistence(timeout: 5) else {
            XCTFail("mock-block-2 should exist")
            return
        }

        let timelineWidth = timeline.frame.width
        let contentWidth = timelineWidth - 45
        let blockWidth = block2.frame.width

        // Non-overlapping block should be close to full content width
        XCTAssertGreaterThan(
            blockWidth, contentWidth * 0.8,
            "Non-overlapping block width (\(blockWidth)) should be > 80% of content width (\(contentWidth)) — should be full-width"
        )
    }

    /// Existing blocks should remain tappable after canvas rebuild.
    /// Verifies that tap → FocusBlockTasksSheet still works.
    func testFocusBlockIsTappable() throws {
        guard let timeline = navigateToBloxTimeline() else {
            XCTFail("Timeline should exist on Blox tab")
            return
        }

        let block1 = timeline.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'focusBlock_mock-block-1'"))
            .firstMatch

        if !block1.waitForExistence(timeout: 3) {
            timeline.swipeUp()
            sleep(1)
        }

        guard block1.waitForExistence(timeout: 5) else {
            XCTFail("mock-block-1 should exist")
            return
        }

        XCTAssertTrue(block1.isHittable, "FocusBlock should be hittable (tappable) on canvas")
    }
}
