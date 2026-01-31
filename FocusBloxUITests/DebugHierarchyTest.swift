import XCTest

/// Debug-Test zum Extrahieren des Accessibility Trees.
/// NICHT fuer produktive Tests verwenden - nur fuer Diagnose!
///
/// Verwendung: `/inspect-ui` Command oder direkt:
/// ```
/// xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
///   -destination 'id=877731AF-6250-4E23-A07E-80270C69D827' \
///   -only-testing:FocusBloxUITests/DebugHierarchyTest/testPrintAccessibilityTree
/// ```
final class DebugHierarchyTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Haupttest: Komplette Hierarchie ausgeben

    /// Gibt den kompletten Accessibility Tree aus.
    /// Zeigt alle Elemente, Identifier und Hierarchie.
    func testPrintAccessibilityTree() {
        // Kurz warten bis App vollstaendig geladen
        let firstElement = app.navigationBars.firstMatch
        _ = firstElement.waitForExistence(timeout: 3)

        print("\n")
        print("=== ACCESSIBILITY TREE ===")
        print(app.debugDescription)
        print("=== END ACCESSIBILITY TREE ===")
        print("\n")

        // Zusaetzliche strukturierte Ausgabe
        printStructuredSummary()
    }

    // MARK: - Spezifische Screen-Tests

    /// Gibt Hierarchie nach Navigation zu Settings aus.
    func testPrintSettingsScreen() {
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1) // Animation abwarten
        }

        print("\n=== SETTINGS SCREEN HIERARCHY ===")
        print(app.debugDescription)
        print("=== END ===\n")
        printStructuredSummary()
    }

    /// Gibt Hierarchie nach Oeffnen des Add-Task-Sheets aus.
    func testPrintAddTaskSheet() {
        let addButton = app.buttons["addTaskButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            sleep(1)
        }

        print("\n=== ADD TASK SHEET HIERARCHY ===")
        print(app.debugDescription)
        print("=== END ===\n")
        printStructuredSummary()
    }

    /// Gibt Hierarchie des Backlog-Tabs aus.
    func testPrintBacklogTab() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 3) {
            backlogTab.tap()
            sleep(1)
        }

        print("\n=== BACKLOG TAB HIERARCHY ===")
        print(app.debugDescription)
        print("=== END ===\n")
        printStructuredSummary()
    }

    /// Gibt Hierarchie des Assign-Tabs aus.
    func testPrintAssignTab() {
        // Navigate to Assign using floating tab bar
        let assignTab = app.buttons["tab-assign"]
        guard assignTab.waitForExistence(timeout: 10) else {
            print("ERROR: tab-assign not found!")
            return
        }
        assignTab.tap()
        sleep(2)

        // Screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AssignTabDebug"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("\n=== ASSIGN TAB HIERARCHY ===")
        print(app.debugDescription)
        print("=== END ===\n")

        // Search for Focus Block elements
        print("\n=== FOCUS BLOCK ELEMENTS ===")

        let focusBlockCards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).allElementsBoundByIndex
        print("\nFocus Block Cards (\(focusBlockCards.count)):")
        for card in focusBlockCards {
            print("  - [\(card.identifier)]")
        }

        let tasksInBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskInBlock_'")
        ).allElementsBoundByIndex
        print("\nTasks in Block (\(tasksInBlock.count)):")
        for task in tasksInBlock {
            print("  - [\(task.identifier)]")
        }

        let removeButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'removeTaskButton_'")
        ).allElementsBoundByIndex
        print("\nRemove Buttons (\(removeButtons.count)):")
        for btn in removeButtons {
            print("  - [\(btn.identifier)]")
        }

        print("\n=== ALL STATIC TEXTS ===")
        let texts = app.staticTexts.allElementsBoundByIndex
        for text in texts.prefix(50) {
            print("  - \"\(text.label)\"")
        }

        printStructuredSummary()
    }

    /// Gibt Hierarchie der Backlog Liste aus (mit custom floating tab bar).
    func testPrintBacklogListView() {
        // Navigate to Backlog using floating tab bar
        let backlogTab = app.buttons["tab-backlog"]
        guard backlogTab.waitForExistence(timeout: 10) else {
            print("ERROR: tab-backlog not found!")
            return
        }
        backlogTab.tap()
        sleep(1)

        // Switch to Liste view
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        guard viewModeSwitcher.waitForExistence(timeout: 5) else {
            print("ERROR: viewModeSwitcher not found!")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)

        let listeOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Liste'")
        ).firstMatch
        guard listeOption.waitForExistence(timeout: 3) else {
            print("ERROR: Liste option not found!")
            return
        }
        listeOption.tap()
        sleep(3) // Wait for data to load

        // Screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "BacklogListeDebug"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("\n=== BACKLOG LISTE HIERARCHY ===")
        print(app.debugDescription)
        print("=== END ===\n")

        // Search for specific identifiers
        print("\n=== SEARCH RESULTS ===")

        print("\nImages:")
        let images = app.images.allElementsBoundByIndex
        for img in images {
            print("  - [\(img.identifier)] '\(img.label)'")
        }

        print("\nOther Elements with 'backlog' or task IDs:")
        let others = app.otherElements.allElementsBoundByIndex
        for elem in others.prefix(30) {
            let id = elem.identifier
            if !id.isEmpty {
                print("  - [\(id)]")
            }
        }

        print("\nStatic Texts with identifiers:")
        let texts = app.staticTexts.allElementsBoundByIndex
        for txt in texts.prefix(30) {
            let id = txt.identifier
            if !id.isEmpty {
                print("  - [\(id)] = '\(txt.label)'")
            }
        }

        printStructuredSummary()
    }

    // MARK: - Hilfsmethoden

    /// Strukturierte Zusammenfassung der wichtigsten Elemente.
    private func printStructuredSummary() {
        print("\n=== STRUCTURED SUMMARY ===\n")

        // Navigation Bars
        let navBars = app.navigationBars.allElementsBoundByIndex
        if !navBars.isEmpty {
            print("## Navigation Bars:")
            for bar in navBars {
                print("  - \"\(bar.identifier.isEmpty ? bar.label : bar.identifier)\"")
            }
            print("")
        }

        // Tab Bars
        let tabButtons = app.tabBars.buttons.allElementsBoundByIndex
        if !tabButtons.isEmpty {
            print("## Tab Bar Buttons:")
            for tab in tabButtons {
                let selected = tab.isSelected ? " [SELECTED]" : ""
                print("  - \"\(tab.label)\"\(selected)")
            }
            print("")
        }

        // Buttons mit Identifier
        print("## Buttons:")
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(30) { // Limit um Output lesbar zu halten
            let id = button.identifier
            let label = button.label
            let hittable = button.isHittable ? "" : " [NOT HITTABLE]"
            if !id.isEmpty {
                print("  - [\(id)] \"\(label)\"\(hittable)")
            } else if !label.isEmpty {
                print("  - \"\(label)\"\(hittable) (NO IDENTIFIER!)")
            }
        }
        if buttons.count > 30 {
            print("  ... and \(buttons.count - 30) more")
        }
        print("")

        // Static Texts
        print("## Static Texts:")
        let texts = app.staticTexts.allElementsBoundByIndex
        for text in texts.prefix(20) {
            let id = text.identifier
            let label = text.label
            if !id.isEmpty {
                print("  - [\(id)] \"\(label)\"")
            } else if !label.isEmpty && label.count < 50 {
                print("  - \"\(label)\"")
            }
        }
        if texts.count > 20 {
            print("  ... and \(texts.count - 20) more")
        }
        print("")

        // Switches/Toggles
        let switches = app.switches.allElementsBoundByIndex
        if !switches.isEmpty {
            print("## Switches/Toggles:")
            for toggle in switches {
                let id = toggle.identifier
                let value = toggle.value as? String ?? "?"
                let state = value == "1" ? "ON" : "OFF"
                if !id.isEmpty {
                    print("  - [\(id)] = \(state)")
                } else {
                    print("  - \"\(toggle.label)\" = \(state) (NO IDENTIFIER!)")
                }
            }
            print("")
        }

        // Text Fields
        let textFields = app.textFields.allElementsBoundByIndex
        if !textFields.isEmpty {
            print("## Text Fields:")
            for field in textFields {
                let id = field.identifier
                let value = field.value as? String ?? ""
                print("  - [\(id.isEmpty ? "NO ID" : id)] value=\"\(value)\"")
            }
            print("")
        }

        // Cells
        let cells = app.cells.allElementsBoundByIndex
        if !cells.isEmpty {
            print("## Cells (first 10):")
            for cell in cells.prefix(10) {
                let id = cell.identifier
                print("  - [\(id.isEmpty ? "NO ID" : id)]")
            }
            if cells.count > 10 {
                print("  ... and \(cells.count - 10) more")
            }
            print("")
        }

        // Warnungen
        print("## WARNINGS:")
        let buttonsWithoutId = buttons.filter { $0.identifier.isEmpty && !$0.label.isEmpty }
        if !buttonsWithoutId.isEmpty {
            print("  ! \(buttonsWithoutId.count) Buttons ohne AccessibilityIdentifier")
        }

        let switchesWithoutId = switches.filter { $0.identifier.isEmpty }
        if !switchesWithoutId.isEmpty {
            print("  ! \(switchesWithoutId.count) Switches ohne AccessibilityIdentifier")
        }

        let fieldsWithoutId = textFields.filter { $0.identifier.isEmpty }
        if !fieldsWithoutId.isEmpty {
            print("  ! \(fieldsWithoutId.count) TextFields ohne AccessibilityIdentifier")
        }

        print("\n=== END SUMMARY ===\n")
    }
}
