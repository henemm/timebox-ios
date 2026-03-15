//
//  MacCoachReviewUITests.swift
//  FocusBloxMacUITests
//
//  Tests for Coach Selection (MorningIntentionView) and Evening Reflection
//  integration in macOS Review tab.
//  Uses coach cards (coachSelectionCard_*) instead of old intention chips.
//

import XCTest

final class MacCoachReviewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func launchWithCoachMode() {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    private func launchWithoutCoachMode() {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "0"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    private func navigateToReview() {
        // macOS renders Picker(.segmented) as RadioGroup
        let picker = app.radioGroups["mainNavigationPicker"]
        guard picker.waitForExistence(timeout: 3) else { return }

        // Coach mode changes the icon to sun.and.horizon; normal is chart.bar
        let coachButton = picker.radioButtons["sun.and.horizon"]
        if coachButton.exists {
            coachButton.tap()
            return
        }
        let reviewButton = picker.radioButtons["chart.bar"]
        if reviewButton.exists {
            reviewButton.tap()
            return
        }

        // Fallback: tap 5th radio button by index
        let buttons = picker.radioButtons
        if buttons.count >= 5 {
            buttons.element(boundBy: 4).tap()
        }
    }

    // MARK: - Test 1: Coach OFF shows normal MacReviewView (no coach card)

    /// Verhalten: Ohne Coach-Modus zeigt Review-Tab die normale MacReviewView.
    /// Bricht wenn: ContentView.mainContentView .review-case immer MacCoachReviewView zeigt
    func test_coachModeOff_reviewShowsNoCoachCard() throws {
        launchWithoutCoachMode()
        navigateToReview()

        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        XCTAssertFalse(intentionCard.waitForExistence(timeout: 3),
                       "MorningIntentionCard should NOT be visible when Coach mode is OFF")
    }

    // MARK: - Test 2: Coach ON shows MorningIntentionView with coach cards

    /// Verhalten: Bei Coach-Modus zeigt Review-Tab die MorningIntentionView mit Coach-Karten.
    /// Bricht wenn: MacCoachReviewView nicht erstellt wird oder MorningIntentionView()
    /// nicht einbettet.
    func test_coachModeOn_reviewShowsCoachCard() throws {
        launchWithCoachMode()
        navigateToReview()

        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        XCTAssertTrue(intentionCard.waitForExistence(timeout: 5),
                      "MorningIntentionCard should be visible when Coach mode is ON")
    }

    // MARK: - Test 3: Setting coach switches to Backlog

    /// Verhalten: Nach Coach-Auswahl wechselt die App zum Backlog-Tab.
    /// Bricht wenn: ContentView keinen onChange(of: intentionJustSet)-Observer hat
    func test_setCoach_switchesToBacklog() throws {
        launchWithCoachMode()
        navigateToReview()

        // Wait for the morning intention card to appear
        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        guard intentionCard.waitForExistence(timeout: 5) else {
            XCTFail("morningIntentionCard should be visible")
            return
        }

        // If coach was already set (compact view), tap "Aendern" to switch to selection
        let editButton = app.buttons["editIntentionButton"]
        let hasExistingCoach = editButton.waitForExistence(timeout: 2)
        if hasExistingCoach {
            editButton.tap()
        }

        let setButton = app.buttons["setIntentionButton"]
        guard setButton.waitForExistence(timeout: 5) else {
            XCTFail("setIntentionButton should exist in selection view")
            return
        }

        // Only select a coach card if button is disabled (no prior selections)
        if !setButton.isEnabled {
            let euleCard = app.buttons["coachSelectionCard_eule"]
            guard euleCard.waitForExistence(timeout: 3) else {
                XCTFail("Coach card 'eule' should exist in selection view")
                return
            }
            euleCard.tap()
        }

        // Tap "Intention setzen" button
        guard setButton.isEnabled else {
            XCTFail("setIntentionButton should be enabled after coach selection")
            return
        }
        setButton.tap()

        // After tab switch, the Backlog radio button should be selected (value: 1)
        let picker = app.radioGroups["mainNavigationPicker"]
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker should exist")
            return
        }

        // Check that the Backlog button (first, identifier "list.bullet") is now selected
        let backlogRadio = picker.radioButtons["list.bullet"]
        let predicate = NSPredicate(format: "value == 1")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: backlogRadio)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "After setting coach, Backlog radio button should be selected")
    }

    // MARK: - Test 4: Day progress section visible

    /// Verhalten: MacCoachReviewView zeigt Tages-Fortschritt ("X Tasks erledigt").
    /// Bricht wenn: MacCoachReviewView keine dayProgressSection hat
    func test_coachModeOn_showsDayProgress() throws {
        launchWithCoachMode()
        navigateToReview()

        let dayProgress = app.descendants(matching: .any)["coachDayProgress"]
        XCTAssertTrue(dayProgress.waitForExistence(timeout: 5),
                      "Day progress section should be visible in Coach review")
    }

    // MARK: - Helpers (Evening Reflection)

    private func launchWithEveningReflectionAndCoach() {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1",
            "-ForceEveningReflection",
            "-MockIntentionSet"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    // MARK: - Test 5: Evening Card visible with coach set

    /// Verhalten: Bei ForceEveningReflection + Coach gesetzt zeigt MacCoachReviewView die EveningReflectionCard.
    /// Bricht wenn: MacCoachReviewView.body — EveningReflectionCard(...) nicht eingebaut wird
    func test_eveningReflection_visibleWhenCoachSet() throws {
        launchWithEveningReflectionAndCoach()
        navigateToReview()

        let card = app.descendants(matching: .any)["eveningReflectionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5),
                      "Evening reflection card should be visible when coach is set and ForceEveningReflection is active")
    }

    // MARK: - Test 6: Evening Card NOT visible without coach

    /// Verhalten: Ohne Coach-Modus zeigt Review-Tab KEINE EveningReflectionCard.
    /// Bricht wenn: ContentView zeigt MacCoachReviewView auch wenn Coach-Modus aus ist
    func test_eveningReflection_hiddenWhenCoachModeOff() throws {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "0",
            "-ForceEveningReflection"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)

        navigateToReview()

        let card = app.descendants(matching: .any)["eveningReflectionCard"]
        XCTAssertFalse(card.waitForExistence(timeout: 3),
                       "Evening reflection card should NOT be visible when coach mode is off")
    }

    // MARK: - Test 7: Evening Card renders content

    /// Verhalten: EveningReflectionCard rendert Inhalt (Titel + Reflexionstext).
    /// Bricht wenn: EveningReflectionCard Body leer ist oder nicht rendert
    func test_eveningReflection_showsContent() throws {
        launchWithEveningReflectionAndCoach()
        navigateToReview()

        let card = app.descendants(matching: .any)["eveningReflectionCard"]
        guard card.waitForExistence(timeout: 5) else {
            XCTFail("Evening reflection card should exist")
            return
        }

        // Card should contain "Dein Abend-Spiegel" headline
        let headline = app.staticTexts["Dein Abend-Spiegel"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5),
                      "Evening card should display 'Dein Abend-Spiegel' headline")
    }

}
