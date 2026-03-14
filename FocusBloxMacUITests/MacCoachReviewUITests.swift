//
//  MacCoachReviewUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED: Tests for MorningIntentionView integration in macOS Review tab.
//  These tests MUST FAIL until MacCoachReviewView is implemented.
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

    // MARK: - Test 1: Coach OFF shows normal MacReviewView (no intention card)

    /// Verhalten: Ohne Coach-Modus zeigt Review-Tab die normale MacReviewView.
    /// Bricht wenn: ContentView.mainContentView .review-case immer MacCoachReviewView zeigt
    /// statt nur bei coachModeEnabled == true.
    func test_coachModeOff_reviewShowsNoIntentionCard() throws {
        launchWithoutCoachMode()
        navigateToReview()

        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        XCTAssertFalse(intentionCard.waitForExistence(timeout: 3),
                       "MorningIntentionCard should NOT be visible when Coach mode is OFF")
    }

    // MARK: - Test 2: Coach ON shows MorningIntentionView

    /// Verhalten: Bei Coach-Modus zeigt Review-Tab die MorningIntentionView.
    /// Bricht wenn: MacCoachReviewView nicht erstellt wird oder MorningIntentionView()
    /// nicht einbettet.
    func test_coachModeOn_reviewShowsIntentionCard() throws {
        launchWithCoachMode()
        navigateToReview()

        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        XCTAssertTrue(intentionCard.waitForExistence(timeout: 5),
                      "MorningIntentionCard should be visible when Coach mode is ON")
    }

    // MARK: - Test 3: Intention setzen switches to Backlog

    /// Verhalten: Nach Intention-Setzen wechselt die App zum Backlog-Tab.
    /// Bricht wenn: ContentView keinen onChange(of: intentionJustSet)-Observer hat
    /// der selectedSection auf .backlog setzt.
    func test_setIntention_switchesToBacklog() throws {
        launchWithCoachMode()
        navigateToReview()

        // Wait for the morning intention card to appear
        let intentionCard = app.descendants(matching: .any)["morningIntentionCard"]
        guard intentionCard.waitForExistence(timeout: 5) else {
            XCTFail("morningIntentionCard should be visible")
            return
        }

        // If intention was already set (compact view), tap "Aendern" to switch to selection
        let editButton = app.buttons["editIntentionButton"]
        let hasExistingIntention = editButton.waitForExistence(timeout: 2)
        if hasExistingIntention {
            editButton.tap()
        }

        let setButton = app.buttons["setIntentionButton"]
        guard setButton.waitForExistence(timeout: 5) else {
            XCTFail("setIntentionButton should exist in selection view")
            return
        }

        // Only select a chip if button is disabled (no prior selections)
        if !setButton.isEnabled {
            let fokusChip = app.buttons["intentionChip_fokus"]
            guard fokusChip.waitForExistence(timeout: 3) else {
                XCTFail("Intention chip 'fokus' should exist in selection view")
                return
            }
            fokusChip.tap()
        }

        // Tap "Intention setzen" button
        guard setButton.isEnabled else {
            XCTFail("setIntentionButton should be enabled after chip selection")
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
                       "After setting intention, Backlog radio button should be selected")
    }

    // MARK: - Test 4: Day progress section visible

    /// Verhalten: MacCoachReviewView zeigt Tages-Fortschritt ("X Tasks erledigt").
    /// Bricht wenn: MacCoachReviewView keine dayProgressSection hat
    /// oder das accessibilityIdentifier "coachDayProgress" fehlt.
    func test_coachModeOn_showsDayProgress() throws {
        launchWithCoachMode()
        navigateToReview()

        let dayProgress = app.descendants(matching: .any)["coachDayProgress"]
        XCTAssertTrue(dayProgress.waitForExistence(timeout: 5),
                      "Day progress section should be visible in Coach review")
    }

}
