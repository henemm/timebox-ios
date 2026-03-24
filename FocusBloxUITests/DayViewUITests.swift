import XCTest

final class DayViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Tab Navigation

    /// Verhalten: Tab "Tag" existiert in der Tab-Bar und ist tappbar
    /// Bricht wenn: AppTab.day case fehlt oder tabItem Label falsch
    func test_dayTab_existsInTabBar() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tab 'Tag' sollte in der Tab-Bar existieren")
    }

    /// Verhalten: Tap auf Tab "Tag" navigiert zur DayView
    /// Bricht wenn: DayView nicht als TabView-Child eingebunden ist
    func test_dayTab_tap_showsDayView() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tab 'Tag' muss existieren")
        tagTab.tap()

        // DayView sollte einen der drei Modus-Texte zeigen
        let morningExists = app.staticTexts["Guten Morgen"].waitForExistence(timeout: 3)
        let daytimeExists = app.staticTexts["Dein Tag"].exists
        let eveningExists = app.staticTexts["Tagesrueckblick"].exists

        XCTAssertTrue(
            morningExists || daytimeExists || eveningExists,
            "DayView sollte einen Modus-Titel zeigen (Guten Morgen / Dein Tag / Tagesrueckblick)"
        )
    }

    /// Verhalten: Tab "Tag" ist zwischen "Blox" und "Focus" positioniert
    /// Bricht wenn: AppTab.day an falscher Position im enum steht
    func test_dayTab_positionedBetweenBloxAndFocus() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let bloxTab = tabBar.buttons["Blox"]
        let tagTab = tabBar.buttons["Tag"]
        let focusTab = tabBar.buttons["Focus"]

        XCTAssertTrue(bloxTab.exists, "Blox Tab muss existieren")
        XCTAssertTrue(tagTab.exists, "Tag Tab muss existieren")
        XCTAssertTrue(focusTab.exists, "Focus Tab muss existieren")

        // Tag-Tab muss rechts von Blox und links von Focus sein
        XCTAssertGreaterThan(
            tagTab.frame.midX, bloxTab.frame.midX,
            "Tag-Tab sollte rechts von Blox sein"
        )
        XCTAssertLessThan(
            tagTab.frame.midX, focusTab.frame.midX,
            "Tag-Tab sollte links von Focus sein"
        )
    }

    // MARK: - Phase Content

    /// Verhalten: DayView zeigt phasen-spezifischen Content (nicht leer)
    /// Bricht wenn: DayView body keinen Content fuer die aktuelle Phase rendert
    func test_dayView_showsPhaseContent() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // Mindestens ein Platzhalter-Text muss sichtbar sein
        let hasPlaceholder =
            app.staticTexts["Kalender-Uebersicht kommt bald"].waitForExistence(timeout: 3) ||
            app.staticTexts["Timeline kommt bald"].exists ||
            app.staticTexts["Reflexion kommt bald"].exists

        XCTAssertTrue(hasPlaceholder, "DayView sollte einen Platzhalter-Text fuer die aktuelle Phase zeigen")
    }
}
