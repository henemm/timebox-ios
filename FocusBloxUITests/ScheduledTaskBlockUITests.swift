import XCTest

/// EXPECTED TO FAIL (TDD RED): ScheduledTaskBlock with context menu does not exist yet.
/// Phase B placeholder has no .contextMenu and no time range display.
final class ScheduledTaskBlockUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Context Menu Tests

    /// Verhalten: Long-Press auf einen scheduled Task Block zeigt Context Menu mit "Entplanen"
    /// Bricht wenn: ScheduledTaskBlock.swift — .contextMenu { } Modifier fehlt oder "Entplanen" Button fehlt
    func test_scheduledTaskBlock_showsContextMenu() throws {
        navigateToBlox()

        // Find a scheduled task block on the timeline
        let scheduledBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scheduledTaskBlock_'")
        ).firstMatch

        guard scheduledBlock.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled Task Block muss auf Timeline existieren (scheduledTaskBlock_*)")
            return
        }

        // Long-press to trigger context menu
        scheduledBlock.press(forDuration: 1.0)

        // Context menu MUST contain "Entplanen" action
        let unscheduleButton = app.buttons["Entplanen"]
        XCTAssertTrue(
            unscheduleButton.waitForExistence(timeout: 3),
            "Context Menu MUSS 'Entplanen' Button enthalten"
        )
    }

    /// Verhalten: "Entplanen" im Context Menu entfernt Task von Timeline — Task kehrt ins Backlog zurueck
    /// Bricht wenn: ScheduledTaskBlock.swift — onUnschedule() Callback im Context Menu Button fehlt
    func test_scheduledTaskBlock_unscheduleReturnsToBacklog() throws {
        navigateToBlox()

        // Find scheduled task block
        let scheduledBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scheduledTaskBlock_'")
        ).firstMatch

        guard scheduledBlock.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled Task Block muss auf Timeline existieren")
            return
        }

        // Remember the block identifier to check it disappears
        let blockIdentifier = scheduledBlock.identifier

        // Long-press → Context Menu → tap "Entplanen"
        scheduledBlock.press(forDuration: 1.0)

        let unscheduleButton = app.buttons["Entplanen"]
        guard unscheduleButton.waitForExistence(timeout: 3) else {
            XCTFail("Context Menu 'Entplanen' Button nicht gefunden")
            return
        }
        unscheduleButton.tap()

        // Block MUST disappear from timeline after unschedule
        let blockStillExists = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", blockIdentifier))
            .firstMatch
            .waitForExistence(timeout: 3)

        XCTAssertFalse(
            blockStillExists,
            "Scheduled Task Block MUSS nach 'Entplanen' von der Timeline verschwinden"
        )
    }

    /// Verhalten: Scheduled Task Block zeigt Zeitrange an (z.B. "10:00 – 10:30")
    /// Bricht wenn: ScheduledTaskBlock.swift — Text(timeRangeText) Zeile entfernt
    func test_scheduledTaskBlock_showsTimeRange() throws {
        navigateToBlox()

        // Find scheduled task block
        let scheduledBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scheduledTaskBlock_'")
        ).firstMatch

        guard scheduledBlock.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled Task Block muss auf Timeline existieren")
            return
        }

        // Block MUST contain a time range string pattern (HH:MM)
        // Look for any text matching time format within the block's subtree
        let timeTexts = scheduledBlock.staticTexts.matching(
            NSPredicate(format: "label MATCHES '.*\\\\d{1,2}:\\\\d{2}.*'")
        )

        XCTAssertGreaterThan(
            timeTexts.count, 0,
            "Scheduled Task Block MUSS Zeitrange anzeigen (z.B. '10:00 – 10:30')"
        )
    }

    // MARK: - GapFinder Integration (RW_3.1d)

    /// Verhalten: Scheduled Task Block darf NICHT als Free Slot vorgeschlagen werden
    /// Bricht wenn: GapFinder.swift — scheduledTasks Loop entfernt (busyPeriods ignoriert scheduledTasks)
    func test_scheduledTask_notSuggestedAsFreeSlot() throws {
        navigateToBlox()

        let scheduledBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scheduledTaskBlock_'")
        ).firstMatch

        guard scheduledBlock.waitForExistence(timeout: 5) else {
            XCTFail("Scheduled Task Block muss auf Timeline existieren")
            return
        }

        let freeSlots = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        )

        let blockFrame = scheduledBlock.frame
        for i in 0..<freeSlots.count {
            let slot = freeSlots.element(boundBy: i)
            if slot.exists {
                let slotFrame = slot.frame
                let overlaps = slotFrame.minY < blockFrame.maxY && slotFrame.maxY > blockFrame.minY
                XCTAssertFalse(overlaps, "Free Slot darf NICHT mit Scheduled Task Block ueberlappen")
            }
        }
    }

    // MARK: - Helpers

    private func navigateToBlox() {
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab muss existieren")
        bloxTab.tap()
        _ = app.scrollViews["planningTimeline"].waitForExistence(timeout: 5)
    }
}
