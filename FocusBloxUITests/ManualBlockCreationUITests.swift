import XCTest

/// UI Tests for Manual Block Creation feature in Blöcke tab
/// Tests verify the "Eigenen Block erstellen" button and sheet functionality
final class ManualBlockCreationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Test 1: Manual Block Creation Button Exists

    func testManualBlockCreationButtonExists() throws {
        // Navigate to Blöcke tab
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(bloeckeTab.exists, "Blöcke tab should exist")
        bloeckeTab.tap()

        // Wait for content to load
        sleep(2)

        // Check for "Eigenen Block erstellen" button
        let createButton = app.buttons["createCustomBlockButton"]

        // Take screenshot for evidence
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ManualBlockCreation-ButtonCheck"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(createButton.exists, "Button 'Eigenen Block erstellen' should exist")
    }

    // MARK: - Test 2: Tap Button Opens Sheet

    func testManualBlockCreationOpensSheet() throws {
        // Navigate to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Tap the create button
        let createButton = app.buttons["createCustomBlockButton"]
        XCTAssertTrue(createButton.exists, "Create button should exist")
        createButton.tap()

        // Wait for sheet to appear with proper timeout
        sleep(2)

        // Check for sheet content - look for "Erstellen" button which indicates sheet is open
        // Navigation titles may not be exposed as staticTexts in all iOS versions
        let erstellenButton = app.buttons["Erstellen"]
        let abbrechenButton = app.buttons["Abbrechen"]

        // Take screenshot of sheet
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ManualBlockCreation-Sheet"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Sheet is open if we can see the action buttons
        let sheetIsOpen = erstellenButton.exists || abbrechenButton.exists
        XCTAssertTrue(sheetIsOpen, "Sheet should appear with Erstellen/Abbrechen buttons")
    }

    // MARK: - Test 3: Sheet Has Time Pickers

    func testSheetHasTimePickers() throws {
        // Navigate to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Open sheet
        let createButton = app.buttons["createCustomBlockButton"]
        guard createButton.exists else {
            XCTFail("Create button does not exist")
            return
        }
        createButton.tap()
        sleep(2)

        // Check for Start/Ende labels (Form section labels)
        let startLabel = app.staticTexts["Start"]
        let endLabel = app.staticTexts["Ende"]

        // Take screenshot for debugging
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ManualBlockCreation-TimePickers"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The Form with DatePickers should show Start/Ende labels
        let hasTimeLabels = startLabel.exists && endLabel.exists
        XCTAssertTrue(hasTimeLabels, "Sheet should have 'Start' and 'Ende' labels")

        // Check for Erstellen button
        let erstellenButton = app.buttons["Erstellen"]
        XCTAssertTrue(erstellenButton.exists, "Sheet should have 'Erstellen' button")
    }
}
