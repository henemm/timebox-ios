import XCTest

@MainActor
final class DependencyIndentUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    func test_mockBlockedTasksExist() throws {
        // Navigate to Backlog
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "Backlog tab not found")
        backlogTab.tap()
        sleep(2)

        // Collect all visible static texts containing MOCK
        var allMockLabels: [String] = []

        for swipe in 0..<12 {
            let mockTexts = app.staticTexts.allElementsBoundByIndex.filter {
                $0.label.contains("MOCK")
            }
            for t in mockTexts {
                if !allMockLabels.contains(t.label) {
                    allMockLabels.append(t.label)
                }
            }
            app.swipeUp()
            sleep(1)
        }

        // Report what we found
        let foundBlocker = allMockLabels.contains { $0.contains("Blocker") }
        let foundAbhaengig = allMockLabels.contains { $0.contains("Abhaengig") }
        let foundBlockiert = app.buttons.allElementsBoundByIndex.contains { $0.label == "Blockiert" }

        XCTAssertTrue(foundBlocker,
            "Blocker task not found. All MOCK labels: \(allMockLabels)")
        XCTAssertTrue(foundAbhaengig,
            "Blocked task not found. All MOCK labels: \(allMockLabels)")
    }
}
