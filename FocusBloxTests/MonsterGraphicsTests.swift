import XCTest
@testable import FocusBlox

/// EXPECTED TO FAIL (TDD RED): Discipline.imageName and IntentionOption.monsterDiscipline do not exist yet.
final class MonsterGraphicsTests: XCTestCase {

    // MARK: - Discipline.imageName

    /// Verhalten: Jede Discipline hat einen Asset-Namen fuer das Monster-Bild.
    /// Bricht wenn: Discipline.imageName Property nicht existiert.
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

    // MARK: - IntentionOption.monsterDiscipline

    /// Verhalten: 6 Intentionen mappen auf 4 Disciplines (Monster).
    /// Bricht wenn: IntentionOption.monsterDiscipline Property nicht existiert.
    func test_monsterDiscipline_survival_mapsToAusdauer() {
        XCTAssertEqual(IntentionOption.survival.monsterDiscipline, .ausdauer)
    }

    func test_monsterDiscipline_fokus_mapsToFokus() {
        XCTAssertEqual(IntentionOption.fokus.monsterDiscipline, .fokus)
    }

    func test_monsterDiscipline_bhag_mapsToMut() {
        XCTAssertEqual(IntentionOption.bhag.monsterDiscipline, .mut)
    }

    func test_monsterDiscipline_balance_mapsToAusdauer() {
        XCTAssertEqual(IntentionOption.balance.monsterDiscipline, .ausdauer)
    }

    func test_monsterDiscipline_growth_mapsToFokus() {
        XCTAssertEqual(IntentionOption.growth.monsterDiscipline, .fokus)
    }

    func test_monsterDiscipline_connection_mapsToKonsequenz() {
        XCTAssertEqual(IntentionOption.connection.monsterDiscipline, .konsequenz)
    }

    func test_monsterDiscipline_allCases_mapToValidDiscipline() {
        for option in IntentionOption.allCases {
            let discipline = option.monsterDiscipline
            XCTAssertTrue(Discipline.allCases.contains(discipline),
                "\(option.rawValue) should map to a valid Discipline")
        }
    }
}
