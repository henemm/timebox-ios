//
//  MacCoachVisibleSectionsTests.swift
//  FocusBloxMacTests
//
//  Unit Tests for visibleSections business logic (#197)
//

import XCTest
@testable import FocusBloxMac

final class MacCoachVisibleSectionsTests: XCTestCase {

    // MARK: - MainSection.coach case

    /// Verhalten: MainSection muss einen .coach case mit "sparkles" icon haben
    /// Bricht wenn: SidebarView.swift den .coach case oder icon entfernt
    func test_coachSection_hasSparklesIcon() {
        let coach = MainSection.coach
        XCTAssertEqual(coach.icon, "sparkles", "Coach section must use sparkles SF Symbol")
        XCTAssertEqual(coach.rawValue, "Coach", "Coach section raw value must be 'Coach'")
    }

    /// Verhalten: MainSection.allCases muss .coach enthalten (6 total)
    /// Bricht wenn: .coach case aus dem enum entfernt wird
    func test_allCases_includesCoach() {
        XCTAssertTrue(
            MainSection.allCases.contains(.coach),
            "MainSection.allCases must include .coach"
        )
        XCTAssertEqual(
            MainSection.allCases.count, 6,
            "MainSection must have 6 cases (backlog, planning, day, focus, review, coach)"
        )
    }

    /// Verhalten: Klassische 5 Sections müssen weiterhin ihre Icons behalten
    /// Bricht wenn: bestehende Icons geändert werden
    func test_classicSections_iconsUnchanged() {
        XCTAssertEqual(MainSection.backlog.icon, "list.bullet")
        XCTAssertEqual(MainSection.planning.icon, "calendar")
        XCTAssertEqual(MainSection.day.icon, "calendar.badge.clock")
        XCTAssertEqual(MainSection.focus.icon, "target")
        XCTAssertEqual(MainSection.review.icon, "chart.bar")
    }
}
