//
//  MacCoachTabLayoutUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED: Tests for macOS Coach-Tab Layout (#197)
//  These tests MUST FAIL before implementation.
//

import XCTest

/// UI Tests for macOS Coach-Tab Layout — Feature-Parität mit iOS (#197)
///
/// Tests verify:
/// 1. Coach section appears in toolbar picker when feature flag is ON
/// 2. Coach section does NOT appear when flag is OFF (default)
/// 3. Navigation to Coach shows CoachView with morning/daytime/evening sections
/// 4. Classic layout (flag OFF) still shows Tag + Review sections
///
/// macOS Picker(.segmented) renders as RadioGroup with SF Symbol identifiers.
final class MacCoachTabLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func launchWithCoachLayout() {
        app.launchArguments = [
            "-UITesting", "-MockData",
            "-ApplePersistenceIgnoreState", "YES",
            "--coach-tab-layout"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    private func launchWithClassicLayout() {
        app.launchArguments = [
            "-UITesting", "-MockData",
            "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    // MARK: - Test 1: Coach section appears with flag

    /// Verhalten: Mit --coach-tab-layout Flag muss "sparkles" Radio-Button im Picker erscheinen
    /// Bricht wenn: MainSection enum keinen .coach case hat oder visibleSections ihn nicht enthält
    func testCoachSectionAppearsWithFlag() throws {
        launchWithCoachLayout()

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker RadioGroup not found")
            return
        }

        // Coach uses SF Symbol "sparkles"
        let coachRadio = radioGroup.radioButtons["sparkles"]
        XCTAssertTrue(
            coachRadio.waitForExistence(timeout: 3),
            "Coach section (sparkles) MUST appear in toolbar picker when --coach-tab-layout flag is set"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacCoach-FlagOn-PickerWithCoach"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Test 2: Coach section NOT visible without flag

    /// Verhalten: Ohne Flag darf "sparkles" NICHT im Picker erscheinen
    /// Bricht wenn: visibleSections Coach auch ohne Flag zurückgibt
    func testCoachSectionNotVisibleWithoutFlag() throws {
        launchWithClassicLayout()

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker RadioGroup not found")
            return
        }

        let coachRadio = radioGroup.radioButtons["sparkles"]
        XCTAssertFalse(
            coachRadio.exists,
            "Coach section (sparkles) must NOT appear without --coach-tab-layout flag"
        )
    }

    // MARK: - Test 3: Navigate to Coach shows CoachView

    /// Verhalten: Klick auf Coach-Section zeigt CoachView mit den 3 Tagesphase-Sections
    /// Bricht wenn: mainContentView switch keinen .coach case hat oder CoachView() nicht rendert
    func testNavigateToCoachSection() throws {
        launchWithCoachLayout()

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker not found")
            return
        }

        // Navigate to Coach
        let coachRadio = radioGroup.radioButtons["sparkles"]
        guard coachRadio.waitForExistence(timeout: 3) else {
            XCTFail("Coach radio button (sparkles) not found — MainSection.coach missing?")
            return
        }
        coachRadio.click()

        // macOS NavigationSplitView content area doesn't expose children as otherElements.
        // Use descendants(matching: .any) which traverses the full accessibility tree.
        let coachView = app.descendants(matching: .any)["coachView"]
        XCTAssertTrue(
            coachView.waitForExistence(timeout: 5),
            "CoachView (coachView identifier) must appear after navigating to Coach section"
        )

        // Verify morning section exists
        let morningSection = app.descendants(matching: .any)["coachMorningSection"]
        XCTAssertTrue(
            morningSection.waitForExistence(timeout: 3),
            "CoachView must contain morning section (coachMorningSection)"
        )

        // Verify daytime section exists
        let daytimeSection = app.descendants(matching: .any)["coachDaytimeSection"]
        XCTAssertTrue(
            daytimeSection.waitForExistence(timeout: 3),
            "CoachView must contain daytime section (coachDaytimeSection)"
        )

        // Verify evening section exists
        let eveningSection = app.descendants(matching: .any)["coachEveningSection"]
        XCTAssertTrue(
            eveningSection.waitForExistence(timeout: 3),
            "CoachView must contain evening section (coachEveningSection)"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacCoach-CoachViewRendered"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Test 4: Classic layout shows Tag + Review, no Coach

    /// Verhalten: Ohne Flag müssen Tag + Review sichtbar sein, Coach nicht
    /// Bricht wenn: visibleSections im classic-Modus falsche Sections zurückgibt
    func testClassicSectionsWithoutFlag() throws {
        launchWithClassicLayout()

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker not found")
            return
        }

        // Classic layout: Tag (calendar.badge.clock) and Review (chart.bar) must exist
        let tagRadio = radioGroup.radioButtons["calendar.badge.clock"]
        XCTAssertTrue(
            tagRadio.exists,
            "Classic layout must have Tag section (calendar.badge.clock)"
        )

        let reviewRadio = radioGroup.radioButtons["chart.bar"]
        XCTAssertTrue(
            reviewRadio.exists,
            "Classic layout must have Review section (chart.bar)"
        )

        // Coach must NOT exist in classic layout
        let coachRadio = radioGroup.radioButtons["sparkles"]
        XCTAssertFalse(
            coachRadio.exists,
            "Classic layout must NOT have Coach section (sparkles)"
        )
    }

    // MARK: - Test 5: Coach layout hides Tag + Review

    /// Verhalten: Mit Flag dürfen Tag + Review NICHT im Picker sein
    /// Bricht wenn: visibleSections im coach-Modus Tag/Review nicht entfernt
    func testCoachLayoutHidesTagAndReview() throws {
        launchWithCoachLayout()

        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else {
            XCTFail("Navigation picker not found")
            return
        }

        // Tag and Review must NOT exist in coach layout
        let tagRadio = radioGroup.radioButtons["calendar.badge.clock"]
        XCTAssertFalse(
            tagRadio.exists,
            "Coach layout must NOT have Tag section (calendar.badge.clock)"
        )

        let reviewRadio = radioGroup.radioButtons["chart.bar"]
        XCTAssertFalse(
            reviewRadio.exists,
            "Coach layout must NOT have Review section (chart.bar)"
        )

        // Backlog and Focus must still exist
        let backlogRadio = radioGroup.radioButtons["list.bullet"]
        XCTAssertTrue(
            backlogRadio.exists,
            "Coach layout must still have Backlog section (list.bullet)"
        )

        let focusRadio = radioGroup.radioButtons["target"]
        XCTAssertTrue(
            focusRadio.exists,
            "Coach layout must still have Focus section (target)"
        )
    }
}
