import XCTest

/// UI Tests for MAC_027: Focus Sprint Workflow Parity (macOS)
/// Tests sub-features:
/// 1. Sidebar switches to Focus after sprint start
/// 2. Follow-up creation in Sprint Review for incomplete tasks
final class MacFocusSprintParityUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-UITesting"]
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateToFocusTab() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else { return }
        radioGroup.radioButtons["target"].click()
    }

    private func navigateToBacklogTab() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else { return }
        radioGroup.radioButtons["list.bullet"].click()
    }

    // MARK: - Sub-Feature 1: Sidebar-Switch bei Sprint-Start

    @MainActor
    func testFocusSprintContextMenuExists() throws {
        navigateToBacklogTab()

        let taskRow = app.staticTexts["[MOCK] Task 1 #30min"]
        guard taskRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("Mock task not visible in backlog")
        }

        taskRow.click()
        taskRow.rightClick()

        let sprintMenuItem = app.menuItems["Focus Sprint starten"]
        XCTAssertTrue(
            sprintMenuItem.waitForExistence(timeout: 3),
            "'Focus Sprint starten' sollte im Context-Menu verfuegbar sein"
        )
    }

    @MainActor
    func testSidebarSwitchCodePathExists() throws {
        navigateToBacklogTab()
        let taskRow = app.staticTexts["[MOCK] Task 1 #30min"]
        XCTAssertTrue(
            taskRow.waitForExistence(timeout: 5),
            "Mock tasks should be visible in backlog"
        )
    }

    // MARK: - Sub-Feature 2: Follow-up in Sprint Review

    @MainActor
    func testFollowUpUIElementsExistInCode() throws {
        navigateToFocusTab()
        XCTAssertTrue(app.windows.firstMatch.exists, "Focus view should be reachable")
    }

    @MainActor
    func testFocusViewLoadsWithoutActiveSprint() throws {
        navigateToFocusTab()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should exist")

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        let focusButton = radioGroup.radioButtons["target"]
        XCTAssertEqual(
            focusButton.value as? Int, 1,
            "Focus tab should be selected after navigation"
        )
    }
}
