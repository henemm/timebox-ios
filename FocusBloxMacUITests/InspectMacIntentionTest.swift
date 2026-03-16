import XCTest

final class InspectMacIntentionTest: XCTestCase {
    func test_screenshotMeinTag() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1"
        ]
        app.launch()

        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 10) else {
            XCTFail("No window")
            return
        }

        // Navigate to Mein Tag
        let picker = app.radioGroups["mainNavigationPicker"]
        guard picker.waitForExistence(timeout: 5) else {
            XCTFail("No picker")
            return
        }
        let btn = picker.radioButtons["sun.and.horizon"]
        if btn.exists { btn.tap() }
        sleep(2)

        // Screenshot 1: Mein Tag compact view
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "meintag-compact-view"
        shot1.lifetime = .keepAlways
        add(shot1)

        // If compact view, tap Aendern to see selection
        let editButton = app.buttons["editIntentionButton"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
            sleep(1)
            let shot2 = XCTAttachment(screenshot: app.screenshot())
            shot2.name = "meintag-selection-view"
            shot2.lifetime = .keepAlways
            add(shot2)
        } else {
            // Already in selection mode
            let shot2 = XCTAttachment(screenshot: app.screenshot())
            shot2.name = "meintag-selection-view"
            shot2.lifetime = .keepAlways
            add(shot2)
        }
    }
}
