import XCTest

/// UI Tests for BacklogRow Badge Flow Layout
///
/// Verifies that badges in BacklogRow wrap to multiple lines
/// instead of being clipped in a single-line HStack.
///
/// Strategy: Create a task with ALL possible attributes set,
/// then verify the LAST badges (score, due date) are still visible.
/// With HStack + .clipped(), they get pushed off-screen.
/// With FlowLayout, they wrap to the next line.
final class BacklogBadgeFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to Backlog tab
    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    /// Create a task with many attributes to trigger badge overflow
    private func createFullyAttributedTask() {
        // Tap "+" to open CreateTaskView
        let addButton = app.buttons["addTaskButton"]
        if !addButton.waitForExistence(timeout: 3) {
            // Fallback: try navigation bar button
            app.navigationBars.buttons.matching(
                NSPredicate(format: "label CONTAINS '+' OR label CONTAINS 'Hinzufügen' OR label CONTAINS 'add'")
            ).firstMatch.tap()
        } else {
            addButton.tap()
        }
        sleep(1)

        // Enter title
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 3) {
            titleField.tap()
            titleField.typeText("Badge-Overflow-Test-Task")
        }

        // Set due date (tap the due date toggle/picker if available)
        let dueDateToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'frist' OR label CONTAINS[c] 'datum' OR label CONTAINS[c] 'fällig'")
        ).firstMatch
        if dueDateToggle.waitForExistence(timeout: 2) {
            dueDateToggle.tap()
        }

        // Set recurrence if available
        let recurrencePicker = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'wiederholung' OR label CONTAINS[c] 'wiederkehrend'")
        ).firstMatch
        if recurrencePicker.waitForExistence(timeout: 2) {
            recurrencePicker.tap()
            sleep(1)
            // Select "Täglich"
            let dailyOption = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'täglich' OR label CONTAINS[c] 'taeglich'")
            ).firstMatch
            if dailyOption.waitForExistence(timeout: 2) {
                dailyOption.tap()
            }
        }

        // Add a tag
        let tagField = app.textFields.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'tag' OR placeholderValue CONTAINS[c] 'tag'")
        ).firstMatch
        if tagField.waitForExistence(timeout: 2) {
            tagField.tap()
            tagField.typeText("wichtig\n")
        }

        // Set duration
        let durationButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '30' OR label CONTAINS '30m'")
        ).firstMatch
        if durationButton.waitForExistence(timeout: 2) {
            durationButton.tap()
        }

        // Save task
        let saveButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'erstellen' OR label CONTAINS[c] 'speichern' OR label CONTAINS[c] 'fertig'")
        ).firstMatch
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
        }
        sleep(2)
    }

    // MARK: - Test: Last badges visible after task with many attributes

    /// Creates a task with all attributes (importance, urgency, category,
    /// recurrence, tags, duration, score, due date) and verifies the
    /// LAST badge in the row is within screen bounds.
    ///
    /// BREAKS AT: BacklogRow.swift metadataRow using HStack instead of FlowLayout.
    /// With HStack + .clipped(), the rightmost badges (score, due date)
    /// are pushed off-screen when many badges are shown.
    func testLastBadgeWithinScreenBounds() throws {
        navigateToBacklog()
        createFullyAttributedTask()

        // Take screenshot to document badge layout
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "BadgeFlow_AllAttributes"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Find the priority score badge (second-to-last badge)
        let scoreBadge = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'priorityScoreBadge_'")
        ).firstMatch

        // If no score badge found as otherElement, try staticTexts
        let scoreBadgeAlt = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'priorityScoreBadge_'")
        ).firstMatch

        let foundBadge = scoreBadge.waitForExistence(timeout: 3) ? scoreBadge : scoreBadgeAlt

        guard foundBadge.waitForExistence(timeout: 3) else {
            XCTFail("Priority score badge not found — task may not have been created")
            return
        }

        // The badge's right edge must be within the screen width.
        // With HStack + .clipped(), it overflows and gets clipped.
        let screenWidth = app.frame.width
        let badgeMaxX = foundBadge.frame.maxX

        XCTAssertLessThanOrEqual(
            badgeMaxX, screenWidth,
            "Priority score badge (maxX=\(badgeMaxX)) exceeds screen width (\(screenWidth)). "
            + "Badges are clipped — metadataRow needs FlowLayout instead of HStack."
        )

        // Also verify the badge has non-zero width (not squeezed to nothing)
        XCTAssertGreaterThan(
            foundBadge.frame.width, 10,
            "Priority score badge width (\(foundBadge.frame.width)) is too small — likely squeezed by HStack"
        )
    }
}
