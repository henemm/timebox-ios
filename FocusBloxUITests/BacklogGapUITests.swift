import XCTest

/// UI Tests fuer Bug: Schwarzer Leerraum im iOS Backlog zwischen Suchfeld und Next Up
final class BacklogGapUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Verhalten: Der erste sichtbare Content (Next Up Section) erscheint direkt unter dem Suchfeld,
    ///   ohne grossen schwarzen Leerraum dazwischen.
    /// Bricht wenn: BacklogView.swift Zeile 168-170 — `.safeAreaInset(edge: .top) { EmptyView() }`
    ///   reserviert unsichtbaren Platz und schiebt den List-Content nach unten.
    func test_noLargeGapBetweenSearchAndFirstContent() throws {
        // Backlog tab should already be selected. Wait for the view mode switcher to confirm we're on Backlog.
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 10),
                      "View mode switcher should exist on Backlog screen")

        // Wait a moment for data to load
        let nextUpSection = app.otherElements.matching(identifier: "nextUpSection").firstMatch
        if !nextUpSection.waitForExistence(timeout: 5) {
            // Try finding it as a staticText instead
            let nextUpText = app.staticTexts["Next Up"]
            XCTAssertTrue(nextUpText.waitForExistence(timeout: 5),
                          "Next Up section or label should exist")
        }

        // Find the first task row — this proves data loaded
        let firstTask = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        XCTAssertTrue(firstTask.waitForExistence(timeout: 10),
                      "At least one task should appear in backlog")

        // Now measure the gap: viewModeSwitcher bottom to first task top
        let headerBottom = viewModeSwitcher.frame.maxY
        let firstTaskTop = firstTask.frame.minY
        let gap = firstTaskTop - headerBottom

        // The gap between header and first task content should be reasonable.
        // With the bug (safeAreaInset Dead Code), the gap is ~500pt+.
        // After fix, it should be ~100-200pt (search field + section header + row padding).
        // Using 350pt as threshold — generous enough for search field + normal spacing.
        XCTAssertLessThan(gap, 350,
            "Gap between header and first task is \(Int(gap))pt — should be < 350pt. Large gap indicates layout bug (dead safeAreaInset).")
    }
}
