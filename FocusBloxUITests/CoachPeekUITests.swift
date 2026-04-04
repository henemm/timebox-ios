import XCTest

/// UI Tests: Coach-Tab zeigt angrenzende Sektionen als "Peek" am Bildschirmrand.
/// Der User soll sehen, dass oberhalb/unterhalb noch Sektionen existieren.
@MainActor
final class CoachPeekUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["--coach-tab-layout"]
        app.launch()

        // Zum Coach-Tab navigieren
        let coachTab = app.tabBars.buttons["Coach"]
        if coachTab.waitForExistence(timeout: 5) {
            coachTab.tap()
        }
    }

    /// Screenshot jedes Drawers einzeln aufgeklappt.
    func test_screenshot_coachTab() {
        let coach = app.otherElements["coachView"]
        XCTAssertTrue(coach.waitForExistence(timeout: 5))

        // Screenshot 1: Aktuelle Phase (auto-open)
        let s1 = app.screenshot()
        try? s1.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/coach_phase_current.png"))

        // Morning Drawer öffnen
        let morningDrawer = app.buttons["coachDrawer_Guten Morgen"]
        if morningDrawer.waitForExistence(timeout: 3) {
            morningDrawer.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let s2 = app.screenshot()
        try? s2.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/coach_phase_morning.png"))

        // Dein Tag Drawer öffnen
        let dayDrawer = app.buttons["coachDrawer_Dein Tag"]
        if dayDrawer.waitForExistence(timeout: 3) {
            dayDrawer.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let s3 = app.screenshot()
        try? s3.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/coach_phase_daytime.png"))

        // Evening Drawer öffnen
        let eveningDrawer = app.buttons["coachDrawer_Tagesrückblick"]
        if eveningDrawer.waitForExistence(timeout: 3) {
            eveningDrawer.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let s4 = app.screenshot()
        try? s4.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/coach_phase_evening.png"))
    }

    /// Verhalten: Wenn Morning-Section im Fokus ist, muss "Dein Tag" (Daytime)
    /// am unteren Bildschirmrand angedeutet sichtbar sein (Peek-Effekt).
    func test_morningFocus_daytimePeeksFromBelow() {
        let morning = app.otherElements["coachMorningSection"]
        XCTAssertTrue(morning.waitForExistence(timeout: 5), "Morning-Section muss existieren")

        let daytime = app.otherElements["coachDaytimeSection"]
        XCTAssertTrue(daytime.waitForExistence(timeout: 3), "Daytime-Section muss im View-Tree existieren")

        // Daytime muss teilweise auf dem Bildschirm sichtbar sein
        let windowHeight = app.windows.firstMatch.frame.height
        let daytimeTop = daytime.frame.minY

        XCTAssertLessThan(daytimeTop, windowHeight,
            "Daytime-Section (y=\(daytimeTop)) sollte am unteren Rand sichtbar sein (Window-Höhe=\(windowHeight))")
    }

    /// Verhalten: Wenn Daytime-Section im Fokus ist, muss Evening
    /// am unteren Bildschirmrand angedeutet sichtbar sein.
    func test_daytimeFocus_eveningPeeksFromBelow() {
        // Nach 10:00 scrollt die App automatisch zu daytime
        let daytime = app.otherElements["coachDaytimeSection"]
        XCTAssertTrue(daytime.waitForExistence(timeout: 5), "Daytime-Section muss existieren")

        // Wenn daytime nicht sichtbar, swipe auf der coachView
        if !daytime.isHittable {
            app.otherElements["coachView"].swipeUp()
        }

        let evening = app.otherElements["coachEveningSection"]
        XCTAssertTrue(evening.waitForExistence(timeout: 3), "Evening-Section muss im View-Tree existieren")

        let windowHeight = app.windows.firstMatch.frame.height
        let eveningTop = evening.frame.minY

        XCTAssertLessThan(eveningTop, windowHeight,
            "Evening-Section (y=\(eveningTop)) sollte am unteren Rand sichtbar sein (Window-Höhe=\(windowHeight))")
    }
}
