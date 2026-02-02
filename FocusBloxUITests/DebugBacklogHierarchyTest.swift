import XCTest

final class DebugBacklogHierarchyTest: XCTestCase {
    func testPrintBacklogHierarchy() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        
        // Navigate to Backlog
        let backlogTab = app.buttons["tab-backlog"]
        guard backlogTab.waitForExistence(timeout: 10) else {
            XCTFail("tab-backlog not found")
            return
        }
        backlogTab.tap()
        sleep(1)
        
        // Switch to Liste
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        guard viewModeSwitcher.waitForExistence(timeout: 5) else {
            XCTFail("viewModeSwitcher not found")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)
        
        let listeOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Liste'")
        ).firstMatch
        guard listeOption.waitForExistence(timeout: 3) else {
            XCTFail("Liste option not found")
            return
        }
        listeOption.tap()
        sleep(3)
        
        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "BacklogListDebug"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        
        // Print full hierarchy
        print("=== FULL APP HIERARCHY ===")
        print(app.debugDescription)
        
        // Search for specific patterns
        print("\n=== BUTTONS WITH 'backlog' ===")
        let backlogButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'backlog'"))
        print("Count: \(backlogButtons.count)")
        for i in 0..<min(backlogButtons.count, 10) {
            print("  \(backlogButtons.element(boundBy: i).identifier)")
        }
        
        print("\n=== OTHER ELEMENTS WITH 'backlog' ===")
        let backlogOther = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'backlog'"))
        print("Count: \(backlogOther.count)")
        for i in 0..<min(backlogOther.count, 10) {
            print("  \(backlogOther.element(boundBy: i).identifier)")
        }
        
        print("\n=== IMAGES ===")
        let images = app.images
        print("Count: \(images.count)")
        for i in 0..<min(images.count, 20) {
            let img = images.element(boundBy: i)
            print("  \(img.identifier) - \(img.label)")
        }
        
        print("\n=== STATIC TEXTS ===")
        let texts = app.staticTexts
        print("Count: \(texts.count)")
        for i in 0..<min(texts.count, 20) {
            let txt = texts.element(boundBy: i)
            print("  '\(txt.identifier)' = '\(txt.label)'")
        }
        
        XCTAssertTrue(true)
    }
}
