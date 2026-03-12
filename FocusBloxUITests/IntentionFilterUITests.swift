import XCTest

/// UI Tests for intention-based backlog filtering.
///
/// Tests the flow: Set morning intention → App switches to Backlog tab → Filter chips visible.
final class IntentionFilterUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-CoachModeEnabled"]
        app.launch()
    }

    // MARK: - Helper

    /// Navigate to Review tab, select an intention chip, and tap "Intention setzen".
    private func setIntention(_ option: String) {
        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let chip = app.buttons["intentionChip_\(option)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Chip \(option) should exist")
        chip.tap()

        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3))
        setButton.tap()
    }

    // MARK: - UI-01: Setting intention switches to Backlog tab

    func test_settingIntention_switchesToBacklogTab() {
        setIntention("fokus")

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                       "After setting intention, app should switch to Backlog tab")
    }

    // MARK: - UI-02: Filter chip appears in Backlog after Fokus intention

    func test_fokusIntention_showsFilterChipInBacklog() {
        setIntention("fokus")

        let filterChip = app.buttons["removeIntentionFilter_fokus"]
        XCTAssertTrue(filterChip.waitForExistence(timeout: 5),
                       "Fokus filter chip should appear in Backlog after setting intention")
    }

    // MARK: - UI-03: Filter chip can be dismissed

    func test_filterChip_canBeDismissed() {
        setIntention("fokus")

        let filterChip = app.buttons["removeIntentionFilter_fokus"]
        XCTAssertTrue(filterChip.waitForExistence(timeout: 5), "Filter chip should exist")

        filterChip.tap()

        // After tapping, the chip should be gone
        XCTAssertFalse(filterChip.waitForExistence(timeout: 2),
                        "Filter chip should disappear after dismissal")
    }

    // MARK: - UI-04: Survival shows no filter chips

    func test_survivalIntention_showsNoFilterChips() {
        setIntention("survival")

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                       "Should be on Backlog tab after setting survival intention")

        // No filter chips should appear for survival
        let anyFilterChip = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'removeIntentionFilter_'"))
        XCTAssertEqual(anyFilterChip.count, 0,
                        "Survival should show no filter chips")
    }

    // MARK: - UI-05: Fokus filter hides non-NextUp backlog section

    func test_fokusFilter_hidesBacklogSection() {
        setIntention("fokus")

        let filterChip = app.buttons["removeIntentionFilter_fokus"]
        XCTAssertTrue(filterChip.waitForExistence(timeout: 5), "Filter chip should exist")

        let backlogSection = app.staticTexts["Backlog"]
        XCTAssertFalse(backlogSection.exists,
                        "Backlog section should be hidden when fokus filter is active")
    }

    // MARK: - UI-06: Removing all chips hides chip bar

    func test_removingAllChips_hidesChipBar() {
        setIntention("growth")

        let filterChip = app.buttons["removeIntentionFilter_growth"]
        XCTAssertTrue(filterChip.waitForExistence(timeout: 5), "Growth filter chip should exist")

        filterChip.tap()

        // No filter chips should remain
        let anyFilterChip = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'removeIntentionFilter_'"))
        XCTAssertEqual(anyFilterChip.count, 0,
                        "No filter chips should remain after removing all")
    }
}
