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
        sleep(2)

        var log = ""

        // Search for mock tasks by scrolling
        log += "\n=== SEARCHING FOR MOCK TASKS ===\n"

        for swipeNum in 0..<10 {
            let texts = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'MOCK'")
            )
            log += "After swipe \(swipeNum): Found \(texts.count) MOCK texts\n"
            for i in 0..<min(texts.count, 20) {
                let t = texts.element(boundBy: i)
                if t.exists {
                    log += "  [\(i)] '\(t.label)' frame=\(t.frame)\n"
                }
            }

            // Search for Blockiert labels
            let blocked = app.buttons.matching(
                NSPredicate(format: "label == 'Blockiert'")
            )
            if blocked.count > 0 {
                log += "  >>> FOUND \(blocked.count) 'Blockiert' buttons!\n"
                for i in 0..<min(blocked.count, 5) {
                    let b = blocked.element(boundBy: i)
                    if b.exists {
                        log += "    button[\(i)] frame=\(b.frame)\n"
                    }
                }
            }

            // Check for lock images
            let locks = app.images.matching(
                NSPredicate(format: "label CONTAINS 'lock'")
            )
            if locks.count > 0 {
                log += "  >>> FOUND \(locks.count) lock images\n"
            }

            app.swipeUp()
            sleep(1)
        }

        // Write log as test failure message so it appears in xcresult
        // Using XCTContext.runActivity to embed the log
        XCTContext.runActivity(named: "Hierarchy Debug Log") { activity in
            let attachment = XCTAttachment(string: log)
            attachment.name = "debug_log"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        // Also force-fail with the log so it shows in test output
        if log.contains("MOCK") {
            XCTAssertTrue(true, "Found MOCK tasks - see attachment for details")
        }

        // Try to assert something that will show the log in failure message
        let mockTexts = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'MOCK'")
        )
        XCTAssert(mockTexts.count > 0, "DEBUG LOG:\n\(log)")
    }
}
