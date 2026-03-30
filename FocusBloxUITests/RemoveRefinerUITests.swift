import XCTest

/// TDD RED UI Tests fuer RW 1.5: Refiner-Tab entfernen
/// Pruefen dass der Refiner-Tab NICHT mehr existiert und Review direkt sichtbar ist.
final class RemoveRefinerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Tab-Bar hat keinen Refiner-Tab mehr

    /// Verhalten: Der Refiner-Tab existiert NIRGENDS mehr — weder direkt noch unter More
    /// Bricht wenn: AppTab.refiner Case und RefinerView-Tab NICHT entfernt werden
    func test_tabBar_hasNoRefinerTab() {
        // Aktuell: 6 Tabs → iOS zeigt "More" → Refiner ist unter More
        // Nach Fix: 5 Tabs → kein More, kein Refiner
        let moreTab = app.tabBars.buttons["More"]

        if moreTab.waitForExistence(timeout: 3) {
            moreTab.tap()
            // In der More-Liste DARF Refiner nicht auftauchen
            let refinerInMore = app.staticTexts["Refiner"]
            XCTAssertFalse(refinerInMore.waitForExistence(timeout: 3),
                           "Refiner darf NICHT unter More existieren — Tab muss komplett entfernt werden")
        } else {
            // Kein More-Tab — dann darf Refiner auch nicht direkt existieren
            let refinerTab = app.tabBars.buttons["Refiner"]
            XCTAssertFalse(refinerTab.exists,
                           "Refiner-Tab darf NICHT in der Tab-Bar existieren")
        }
    }

    // MARK: - Review-Tab ist direkt sichtbar (kein "More")

    /// Verhalten: Review-Tab ist direkt in der Tab-Bar sichtbar (nicht unter "More" versteckt)
    /// Bricht wenn: Es weiterhin 6 Tabs gibt und iOS einen "More"-Tab erzeugt
    func test_tabBar_reviewTabDirectlyVisible() {
        let reviewTab = app.tabBars.buttons["Review"]
        XCTAssertTrue(reviewTab.waitForExistence(timeout: 5),
                      "Review-Tab muss direkt in der Tab-Bar sichtbar sein (nicht unter More)")
    }

    /// Verhalten: Es gibt keinen "More"-Tab mehr
    /// Bricht wenn: Weiterhin 6 Tabs vorhanden sind
    func test_tabBar_hasNoMoreTab() {
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertFalse(moreTab.exists,
                       "More-Tab darf NICHT existieren — nur 5 Tabs erlaubt")
    }

    // MARK: - Tab-Bar hat genau 5 Tabs

    /// Verhalten: Tab-Bar zeigt genau 5 Tabs: Backlog, Blox, Tag, Focus, Review
    /// Bricht wenn: Anzahl der Tabs nicht 5 ist
    func test_tabBar_hasExactlyFiveTabs() {
        let expectedTabs = ["Backlog", "Blox", "Tag", "Focus", "Review"]
        for tab in expectedTabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 3),
                          "Tab '\(tab)' muss in der Tab-Bar sichtbar sein")
        }
    }
}
