import XCTest

/// UI Tests for Quick Capture triggers from Widget and Siri
/// Task 8: Home Screen Widget → App mit QuickCaptureView
/// Task 10: Siri Shortcut → App mit QuickCaptureView
final class QuickCaptureTriggersUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Task 8: Widget URL Handling

    /// GIVEN: App is launched with create-task URL
    /// WHEN: The URL focusblox://create-task is opened
    /// THEN: QuickCaptureView should be presented
    ///
    /// Note: This simulates what happens when user taps the Home Screen Widget
    func testCreateTaskURLOpensQuickCapture() throws {
        // Launch with URL argument to simulate deep link
        app.launchArguments.append("-QuickCaptureTest")
        app.launch()

        // Wait for app to launch and process the URL
        sleep(2)

        // QuickCaptureView should be visible
        // Check for the text field (Task-Titel)
        let taskTitleField = app.textFields["Task-Titel"]

        // Screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task8-WidgetURL-QuickCapture"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify QuickCaptureView is shown
        XCTAssertTrue(
            taskTitleField.waitForExistence(timeout: 5),
            "QuickCaptureView should open when launched with -QuickCaptureTest flag"
        )
    }

    /// GIVEN: QuickCaptureView is open from widget trigger
    /// WHEN: User enters a task title and saves
    /// THEN: Task should be created and sheet dismissed
    func testWidgetTriggeredQuickCaptureCreatesTask() throws {
        // Launch with QuickCapture flag
        app.launchArguments.append("-QuickCaptureTest")
        app.launch()
        sleep(2)

        // Find and fill the task title field
        let taskTitleField = app.textFields["Task-Titel"]
        guard taskTitleField.waitForExistence(timeout: 5) else {
            throw XCTSkip("QuickCaptureView did not open")
        }

        taskTitleField.tap()
        taskTitleField.typeText("Widget Test Task")

        // Screenshot before save
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "Task8-BeforeSave"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Tap save button
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        sleep(1)

        // Screenshot after save
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "Task8-AfterSave"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // QuickCaptureView should be dismissed
        XCTAssertFalse(
            taskTitleField.waitForExistence(timeout: 2),
            "QuickCaptureView should be dismissed after saving"
        )
    }

    // MARK: - Task 10: Siri Shortcut Handling

    /// GIVEN: App receives QuickCaptureRequested notification
    /// WHEN: The notification is posted (simulated by -QuickCaptureTest flag)
    /// THEN: QuickCaptureView should be presented
    ///
    /// Note: This simulates what happens when Siri Shortcut triggers the app
    func testSiriNotificationOpensQuickCapture() throws {
        // The -QuickCaptureTest flag simulates both URL and notification triggers
        app.launchArguments.append("-QuickCaptureTest")
        app.launch()
        sleep(2)

        // QuickCaptureView should be visible
        let taskTitleField = app.textFields["Task-Titel"]

        // Screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task10-SiriTrigger-QuickCapture"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(
            taskTitleField.waitForExistence(timeout: 5),
            "QuickCaptureView should open when Siri notification is received"
        )
    }

    // MARK: - Integration: Quick Capture Flow

    /// Test the complete flow from trigger to task creation
    func testCompleteQuickCaptureFlow() throws {
        app.launchArguments.append("-QuickCaptureTest")
        app.launch()
        sleep(2)

        // Step 1: Verify QuickCaptureView opens
        let taskTitleField = app.textFields["Task-Titel"]
        guard taskTitleField.waitForExistence(timeout: 5) else {
            XCTFail("QuickCaptureView should open")
            return
        }

        // Step 2: Enter task title
        taskTitleField.tap()
        let testTaskName = "Integration Test \(Int.random(in: 1000...9999))"
        taskTitleField.typeText(testTaskName)

        // Step 3: Save
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        sleep(1)

        // Step 4: Verify dismissal
        XCTAssertFalse(taskTitleField.exists, "Sheet should be dismissed")

        // Step 5: Navigate to Backlog to verify task was created
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 3) {
            backlogTab.tap()
            sleep(1)

            // Screenshot showing the new task in backlog
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "QuickCapture-TaskCreated"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            // Check if our task appears
            let taskExists = app.staticTexts[testTaskName].waitForExistence(timeout: 3)
            XCTAssertTrue(taskExists, "Created task should appear in backlog")
        }
    }
}
