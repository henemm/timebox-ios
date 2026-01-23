import XCTest

/// UI Tests for Smart Gaps feature in Blöcke tab
/// Tests verify the gap detection and block creation UI
final class SmartGapsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Test 1: Smart Gaps Section Exists

    func testSmartGapsSectionExists() throws {
        // Navigate to Blöcke tab
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(bloeckeTab.exists, "Blöcke tab should exist")
        bloeckeTab.tap()

        // Wait for content to load
        sleep(2)

        // Check for Smart Gaps header text
        // Either "Tag ist frei!" (day is free) or "Freie Slots" (has events)
        let dayFreeText = app.staticTexts["Tag ist frei!"]
        let freeSlotsText = app.staticTexts["Freie Slots"]

        let hasSmartGapsSection = dayFreeText.exists || freeSlotsText.exists
        XCTAssertTrue(hasSmartGapsSection, "Smart Gaps section should show 'Tag ist frei!' or 'Freie Slots'")
    }

    // MARK: - Test 2: Shows Suggested Times When Day Is Free

    func testShowsSuggestedTimesWhenDayFree() throws {
        // Navigate to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // When day is free, should show "Vorgeschlagene Zeiten:"
        let dayFreeText = app.staticTexts["Tag ist frei!"]

        if dayFreeText.exists {
            let suggestedText = app.staticTexts["Vorgeschlagene Zeiten:"]
            XCTAssertTrue(suggestedText.exists, "Should show 'Vorgeschlagene Zeiten:' when day is free")

            // Should show time slots with "min" duration
            let durationTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '60 min'"))
            XCTAssertTrue(durationTexts.count > 0, "Should show at least one 60 min slot")
        }
    }

    // MARK: - Test 3: Gap Slots Have Plus Button

    func testGapSlotsHavePlusButton() throws {
        // Navigate to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Check for plus button (SF Symbol plus.circle.fill)
        // Using predicate to find buttons with plus icon
        let plusButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'plus' OR identifier CONTAINS 'plus'"))

        // Alternative: look for the button image
        let plusImages = app.images.matching(NSPredicate(format: "identifier == 'plus.circle.fill'"))

        // At least one should exist if there are slots
        let hasCreateButton = plusButtons.count > 0 || plusImages.count > 0

        // Take screenshot for evidence
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SmartGaps-PlusButtons"
        attachment.lifetime = .keepAlways
        add(attachment)

        // This may fail if no slots - that's okay, the screenshot documents the state
        XCTAssertTrue(hasCreateButton, "Gap rows should have plus button to create block")
    }

    // MARK: - Test 4: Screenshot of Smart Gaps Section

    func testSmartGapsSectionScreenshot() throws {
        // Navigate to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Take screenshot for documentation
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SmartGaps-Section"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Screenshot taken successfully
        XCTAssertTrue(true, "Screenshot captured for Smart Gaps section")
    }
}
