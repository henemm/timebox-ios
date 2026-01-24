# Reminder Lists Selection Tests

## Feature: Konfigurierbare Erinnerungslisten fuer Reminders Sync

## Unit Tests (FocusBloxTests/RemindersSyncServiceTests.swift)

### testGetAllReminderListsReturnsLists
```swift
func testGetAllReminderListsReturnsLists() {
    // GIVEN: Mock repository with reminder lists
    let mockRepo = MockEventKitRepository()
    // Setup mock reminder lists

    // WHEN: getAllReminderLists() called
    let lists = mockRepo.getAllReminderLists()

    // THEN: Returns all reminder lists
    XCTAssertFalse(lists.isEmpty)
}
```

### testFetchIncompleteRemindersFiltersbyVisibleLists
```swift
func testFetchIncompleteRemindersFiltersbyVisibleLists() async throws {
    // GIVEN: Reminders in multiple lists, only some lists visible
    let mockRepo = MockEventKitRepository()
    mockRepo.mockReminders = [
        ReminderData(id: "1", title: "List A Task", listID: "listA"),
        ReminderData(id: "2", title: "List B Task", listID: "listB")
    ]
    UserDefaults.standard.set(["listA"], forKey: "visibleReminderListIDs")

    // WHEN: fetchIncompleteReminders()
    let reminders = try await mockRepo.fetchIncompleteReminders()

    // THEN: Only reminders from visible lists returned
    XCTAssertEqual(reminders.count, 1)
    XCTAssertEqual(reminders.first?.title, "List A Task")
}
```

### testFetchIncompleteRemindersReturnsAllWhenNoFilter
```swift
func testFetchIncompleteRemindersReturnsAllWhenNoFilter() async throws {
    // GIVEN: Reminders in multiple lists, no filter set
    let mockRepo = MockEventKitRepository()
    mockRepo.mockReminders = [
        ReminderData(id: "1", title: "List A Task"),
        ReminderData(id: "2", title: "List B Task")
    ]
    UserDefaults.standard.removeObject(forKey: "visibleReminderListIDs")

    // WHEN: fetchIncompleteReminders()
    let reminders = try await mockRepo.fetchIncompleteReminders()

    // THEN: All reminders returned
    XCTAssertEqual(reminders.count, 2)
}
```

## UI Tests (FocusBloxUITests/RemindersSyncUITests.swift)

### testReminderListsSelectionVisible
```swift
func testReminderListsSelectionVisible() throws {
    // GIVEN: App launched, Reminders sync enabled
    let app = XCUIApplication()
    app.launch()

    // WHEN: Open Settings
    app.buttons["settingsButton"].tap()

    // AND: Enable Reminders sync
    app.switches["remindersSyncToggle"].tap()

    // THEN: "Sichtbare Erinnerungslisten" section visible
    XCTAssertTrue(app.staticTexts["Sichtbare Erinnerungslisten"].exists)
}
```

### testReminderListTogglesPersist
```swift
func testReminderListTogglesPersist() throws {
    // GIVEN: Settings open, Reminders sync enabled
    let app = XCUIApplication()
    app.launch()
    app.buttons["settingsButton"].tap()

    // WHEN: Toggle a reminder list off
    let listToggle = app.switches.element(boundBy: 0) // First list
    listToggle.tap()

    // AND: Close and reopen settings
    app.buttons["Fertig"].tap()
    app.buttons["settingsButton"].tap()

    // THEN: Toggle state persisted
    XCTAssertFalse(listToggle.isSelected)
}
```

## Expected Behavior

1. `getAllReminderLists()` returns all EKCalendars of type .reminder
2. `fetchIncompleteReminders()` filters by `visibleReminderListIDs` if set
3. SettingsView shows toggles for each reminder list
4. Toggle state persists in UserDefaults
