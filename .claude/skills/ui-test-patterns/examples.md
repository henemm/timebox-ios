# UI Test Beispiele

## Beispiel 1: Feature mit Loading State testen

```swift
func testDataLoadsAfterToggleEnabled() throws {
    // Navigation
    navigateToSettings()

    // Toggle aktivieren
    let toggle = app.switches["featureToggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    toggle.tap()

    // Zurueck zur Hauptansicht
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // Warten auf Loading-Ende
    let loading = app.activityIndicators["loadingIndicator"]
    if loading.exists {
        XCTAssertTrue(loading.waitForNonExistence(withTimeout: 10))
    }

    // Daten pruefen
    let firstItem = app.cells.firstMatch
    XCTAssertTrue(firstItem.waitForExistence(timeout: 5))
}
```

## Beispiel 2: Picker-Auswahl testen

```swift
func testPriorityPickerSelection() throws {
    // Sheet oeffnen
    app.buttons["addTaskButton"].tap()
    let sheet = app.navigationBars["Neuer Task"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 3))

    // Picker antippen (erscheint als Button)
    let priorityPicker = app.buttons.matching(
        NSPredicate(format: "label CONTAINS 'Priorität'")
    ).firstMatch
    XCTAssertTrue(priorityPicker.waitForExistence(timeout: 3))
    priorityPicker.tap()

    // Option waehlen
    let highOption = app.buttons["Hoch"]
    XCTAssertTrue(highOption.waitForExistence(timeout: 2))
    highOption.tap()
}
```

## Beispiel 3: Swipe-Action testen

```swift
func testSwipeToDelete() throws {
    let firstCell = app.cells.firstMatch
    guard firstCell.waitForExistence(timeout: 5) else {
        XCTSkip("No items to delete")
        return
    }

    let cellIdentifier = firstCell.identifier

    // Swipe nach links
    firstCell.swipeLeft()

    // Delete-Button erscheint
    let deleteButton = app.buttons["Delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    deleteButton.tap()

    // Bestaetigen falls Dialog erscheint
    let confirmButton = app.buttons["Löschen"]
    if confirmButton.waitForExistence(timeout: 2) {
        confirmButton.tap()
    }

    // Pruefen dass Element weg ist
    let deletedCell = app.cells.matching(identifier: cellIdentifier).firstMatch
    XCTAssertTrue(deletedCell.waitForNonExistence(withTimeout: 5))
}
```

## Beispiel 4: Text eingeben und pruefen

```swift
func testCreateTaskWithTitle() throws {
    // Sheet oeffnen
    app.buttons["addTaskButton"].tap()

    let sheet = app.navigationBars["Neuer Task"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 3))

    // Titel eingeben
    let titleField = app.textFields["Task-Titel"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 2))
    titleField.tap()
    titleField.typeText("Mein Test-Task")

    // Speichern
    app.buttons["Speichern"].tap()

    // Sheet sollte schliessen
    XCTAssertTrue(sheet.waitForNonExistence(withTimeout: 3))

    // Task sollte in Liste erscheinen
    let newTask = app.staticTexts["Mein Test-Task"]
    XCTAssertTrue(newTask.waitForExistence(timeout: 5))
}
```

## Beispiel 5: Tab-Navigation testen

```swift
func testNavigateBetweenTabs() throws {
    let tabs = ["Backlog", "Blöcke", "Review", "Settings"]

    for tabName in tabs {
        let tab = app.tabBars.buttons[tabName]
        XCTAssertTrue(tab.waitForExistence(timeout: 3), "\(tabName) tab should exist")
        tab.tap()

        // Warten bis Tab selektiert ist (NICHT sleep!)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: tab
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "\(tabName) should be selected after tap")
    }
}
```

## Beispiel 6: Alert/Dialog behandeln

```swift
func testPermissionAlertHandling() throws {
    // Aktion die Alert ausloest
    app.buttons["requestPermission"].tap()

    // System-Alert abfangen (laeuft in anderem Prozess!)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.buttons["Allow"]

    if allowButton.waitForExistence(timeout: 5) {
        allowButton.tap()
    }

    // Zurueck zur App - Permission sollte granted sein
    let grantedLabel = app.staticTexts["Permission Granted"]
    XCTAssertTrue(grantedLabel.waitForExistence(timeout: 5))
}
```

## Beispiel 7: Screenshot fuer Dokumentation

```swift
func testCaptureFeatureScreenshot() throws {
    // Setup: Feature-State herstellen
    navigateToSettings()
    let toggle = app.switches["featureToggle"]
    if (toggle.value as? String) == "0" {
        toggle.tap()
    }

    // Zurueck zur Hauptansicht
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // Warten auf vollstaendiges Laden
    let content = app.cells.firstMatch
    XCTAssertTrue(content.waitForExistence(timeout: 10))

    // Screenshot erstellen
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "Feature-Enabled-State"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```
