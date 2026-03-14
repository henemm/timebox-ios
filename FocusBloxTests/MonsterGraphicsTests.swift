import XCTest
@testable import FocusBlox

/// Tests for Discipline.imageName and CoachType.discipline mapping.
final class MonsterGraphicsTests: XCTestCase {

    // MARK: - Discipline.imageName

    func test_imageName_fokus_returnsMonsterFokus() {
        XCTAssertEqual(Discipline.fokus.imageName, "monsterFokus")
    }

    func test_imageName_mut_returnsMonsterMut() {
        XCTAssertEqual(Discipline.mut.imageName, "monsterMut")
    }

    func test_imageName_ausdauer_returnsMonsterAusdauer() {
        XCTAssertEqual(Discipline.ausdauer.imageName, "monsterAusdauer")
    }

    func test_imageName_konsequenz_returnsMonsterKonsequenz() {
        XCTAssertEqual(Discipline.konsequenz.imageName, "monsterKonsequenz")
    }

    func test_imageName_allCases_haveUniqueValues() {
        let names = Discipline.allCases.map(\.imageName)
        XCTAssertEqual(Set(names).count, 4, "All 4 disciplines should have unique image names")
    }

    // MARK: - CoachType.discipline

    func test_discipline_troll_mapsToKonsequenz() {
        XCTAssertEqual(CoachType.troll.discipline, .konsequenz)
    }

    func test_discipline_feuer_mapsToMut() {
        XCTAssertEqual(CoachType.feuer.discipline, .mut)
    }

    func test_discipline_eule_mapsToFokus() {
        XCTAssertEqual(CoachType.eule.discipline, .fokus)
    }

    func test_discipline_golem_mapsToAusdauer() {
        XCTAssertEqual(CoachType.golem.discipline, .ausdauer)
    }

    func test_discipline_allCases_mapToValidDiscipline() {
        for coach in CoachType.allCases {
            let discipline = coach.discipline
            XCTAssertTrue(Discipline.allCases.contains(discipline),
                "\(coach.rawValue) should map to a valid Discipline")
        }
    }
}
