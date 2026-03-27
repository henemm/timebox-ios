import XCTest

final class LimitationGuardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    /// Startet App im Morning-Modus mit Mock-Profil das niedrige Durchschnitte hat.
    /// --mock-limitation-profile: injiziert BehavioralProfile mit avgTasksPerDay=2, avgMinutesPerDay=60
    /// So dass 5 Mock-Next-Up-Tasks (Summe ~150 Min) den 1.5x Schwellwert (3 Tasks / 90 Min) ueberschreiten.
    private func launchWithLimitationWarning() {
        app.launchArguments = ["-UITesting", "-morningEndHour", "24", "--mock-limitation-profile"]
        app.launch()
    }

    /// Startet App im Morning-Modus OHNE Mock-Profil (frischer Install, kein Profil).
    private func launchWithoutProfile() {
        app.launchArguments = ["-UITesting", "-morningEndHour", "24"]
        app.launch()
    }

    /// Navigiert zum Tag-Tab.
    private func navigateToDayTab() {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tag-Tab muss existieren")
        tagTab.tap()
    }

    // MARK: - Banner Visibility Tests

    /// Verhalten: Banner erscheint wenn Next-Up-Tasks den 1.5x Schwellwert ueberschreiten.
    /// Bricht wenn: LimitationWarningBanner nicht in NextUpSection eingebettet wird.
    func test_bannerAppears_whenThresholdExceeded() throws {
        launchWithLimitationWarning()
        navigateToDayTab()

        let banner = app.otherElements["limitationWarningBanner"]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 5),
            "Limitation Guard Banner sollte erscheinen wenn Schwellwert ueberschritten"
        )
    }

    /// Verhalten: Banner zeigt korrekte Zahlen (geplante Tasks/Stunden vs. Durchschnitt).
    /// Bricht wenn: LimitationWarningBanner den Text nicht korrekt formatiert.
    func test_bannerShowsCorrectText() throws {
        launchWithLimitationWarning()
        navigateToDayTab()

        let banner = app.otherElements["limitationWarningBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Banner muss existieren")

        // Banner-Text muss Task-Anzahl und Stunden-Angabe enthalten
        let warningText = app.staticTexts["limitationWarningText"]
        XCTAssertTrue(warningText.waitForExistence(timeout: 3), "Warntext muss existieren")

        let textValue = warningText.label
        XCTAssertTrue(
            textValue.contains("Tasks") && textValue.contains("Schnitt"),
            "Banner-Text sollte 'Tasks' und 'Schnitt' enthalten, war: \(textValue)"
        )
    }

    /// Verhalten: Tap auf Dismiss-Button blendet Banner aus.
    /// Bricht wenn: onDismissWarning Callback nicht limitationWarningDismissed setzt.
    func test_bannerDismiss_hidesBanner() throws {
        launchWithLimitationWarning()
        navigateToDayTab()

        let banner = app.otherElements["limitationWarningBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Banner muss existieren")

        let dismissButton = app.buttons["limitationWarningDismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3), "Dismiss-Button muss existieren")
        dismissButton.tap()

        // Banner muss nach Dismiss verschwinden
        XCTAssertFalse(
            banner.waitForExistence(timeout: 2),
            "Banner sollte nach Dismiss nicht mehr sichtbar sein"
        )
    }

    /// Verhalten: Kein Banner wenn kein BehavioralProfile vorhanden (frischer Install).
    /// Bricht wenn: LimitationGuardService.evaluate() bei nil-Profil trotzdem warnt.
    func test_noBanner_whenNoProfileData() throws {
        launchWithoutProfile()
        navigateToDayTab()

        // Warte bis NextUpSection geladen hat
        let nextUpHeader = app.staticTexts["Next Up"]
        XCTAssertTrue(nextUpHeader.waitForExistence(timeout: 5), "Next Up Header muss existieren")

        // Banner darf NICHT erscheinen
        let banner = app.otherElements["limitationWarningBanner"]
        XCTAssertFalse(
            banner.waitForExistence(timeout: 2),
            "Kein Banner bei fehlendem BehavioralProfile"
        )
    }

    /// Verhalten: Kein Banner wenn Next-Up-Tasks unter Schwellwert.
    /// Bricht wenn: Schwellwert-Berechnung falsch (zu niedrig angesetzt).
    func test_noBanner_whenBelowThreshold() throws {
        // --mock-high-profile: injiziert Profil mit avgTasksPerDay=20, avgMinutesPerDay=600
        // 5 Mock-Tasks mit ~150 Min sind weit unter 1.5x (30 Tasks / 900 Min)
        app.launchArguments = ["-UITesting", "-morningEndHour", "24", "--mock-high-profile"]
        app.launch()
        navigateToDayTab()

        let nextUpHeader = app.staticTexts["Next Up"]
        XCTAssertTrue(nextUpHeader.waitForExistence(timeout: 5), "Next Up Header muss existieren")

        let banner = app.otherElements["limitationWarningBanner"]
        XCTAssertFalse(
            banner.waitForExistence(timeout: 2),
            "Kein Banner wenn Tasks unter Schwellwert"
        )
    }
}
