import XCTest
import SwiftData
@testable import FocusBlox

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Pragmatische Test-Suite fuer Apple Intelligence Task Title Enhancement.
///
/// Testet verschiedene Prompt-Strategien gegen das echte On-Device Modell
/// und validiert Output-Qualitaet mit konkreten Eingaben.
///
/// Die Tests sind in 3 Kategorien:
/// 1. Deterministische Validierung (laeuft immer)
/// 2. AI Output-Qualitaet (nur wenn Apple Intelligence verfuegbar)
/// 3. Prompt-Strategie-Vergleich (nur wenn Apple Intelligence verfuegbar)
@MainActor
final class AITitleQualityTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")
    }

    // MARK: - Kategorie 1: Deterministische cleanTitle() Tests (RW_1.4)

    /// cleanTitle entfernt E-Mail-Artefakte deterministisch
    func test_cleanTitle_removesEmailArtifacts() {
        let result = TaskTitleEngine.cleanTitle("Re: Fwd: AW: Meeting vorbereiten")
        XCTAssertEqual(result, "Meeting vorbereiten",
            "E-Mail-Artefakte muessen deterministisch entfernt werden")
    }

    /// cleanTitle erhaelt Sonderzeichen komplett
    func test_cleanTitle_preservesSpecialChars() {
        let result = TaskTitleEngine.cleanTitle("Kruder & Dorfmeister buchen")
        XCTAssertEqual(result, "Kruder & Dorfmeister buchen",
            "Sonderzeichen muessen erhalten bleiben")
    }

    /// cleanTitle erhaelt Umlaute komplett
    func test_cleanTitle_preservesUmlauts() {
        let result = TaskTitleEngine.cleanTitle("Bücher für Maria kaufen")
        XCTAssertEqual(result, "Bücher für Maria kaufen",
            "Umlaute duerfen NIEMALS veraendert werden")
    }

    /// cleanTitle erhaelt Eigennamen mit Umlauten
    func test_cleanTitle_preservesNameUmlauts() {
        let result = TaskTitleEngine.cleanTitle("Müller anrufen wegen Straßensperrung")
        XCTAssertEqual(result, "Müller anrufen wegen Straßensperrung",
            "Eigennamen mit Umlauten muessen erhalten bleiben")
    }

    /// cleanTitle entfernt Einleitungsfloskeln
    func test_cleanTitle_removesIntroPhrases() {
        let result = TaskTitleEngine.cleanTitle("Vergiss nicht den Schlüssel abzugeben")
        XCTAssertEqual(result, "den Schlüssel abzugeben",
            "Einleitungsfloskel muss entfernt werden")
    }

    /// cleanTitle entfernt Dringlichkeit
    func test_cleanTitle_removesUrgencyPrefix() {
        let result = TaskTitleEngine.cleanTitle("Dringend: Steuererklärung abgeben")
        XCTAssertEqual(result, "Steuererklärung abgeben",
            "Dringlichkeit-Prefix muss entfernt werden")
    }

    /// cleanTitle laesst saubere Titel unveraendert
    func test_cleanTitle_preservesCleanTitle() {
        let result = TaskTitleEngine.cleanTitle("Einkaufen gehen")
        XCTAssertEqual(result, "Einkaufen gehen",
            "Sauberer Titel darf nicht veraendert werden")
    }

    /// cleanTitle erhaelt C++ und andere technische Zeichen
    func test_cleanTitle_preservesTechnicalChars() {
        let result = TaskTitleEngine.cleanTitle("C++ Kurs buchen")
        XCTAssertEqual(result, "C++ Kurs buchen",
            "Technische Zeichen muessen erhalten bleiben")
    }

    /// cleanTitle erhaelt Doppelpunkt-Prefixe die User-Content sind
    func test_cleanTitle_preservesCategoryPrefix() {
        let result = TaskTitleEngine.cleanTitle("Projekt: Dokumentation schreiben")
        XCTAssertEqual(result, "Projekt: Dokumentation schreiben",
            "Kategorie-Prefixe mit Doppelpunkt sind User-Content")
    }

    // MARK: - Kategorie 2: AI Output-Qualitaet (nur mit Apple Intelligence)

    #if canImport(FoundationModels)

    /// Test-Matrix: Realistische Eingaben mit erwarteten Qualitaetskriterien.
    /// Jeder Test prueft NICHT den exakten Output, sondern Qualitaetseigenschaften.
    struct TitleTestCase {
        let input: String
        let mustContainWords: [String]     // Diese Woerter MUESSEN im Output sein
        let mustNotContainWords: [String]   // Diese Woerter DUERFEN NICHT im Output sein
        let mustPreserveChars: [Character]  // Diese Zeichen MUESSEN erhalten bleiben
        let expectedUrgent: Bool?           // Erwartete Dringlichkeit (nil = egal)
        let expectedHasDate: Bool           // Soll ein Datum extrahiert werden?
        let description: String             // Beschreibung fuer Fehlerausgabe
    }

    /// Die komplette Test-Matrix mit realistischen Eingaben
    private var testCases: [TitleTestCase] { [
        // === Eigennamen mit Sonderzeichen ===
        TitleTestCase(
            input: "Kruder & Dorfmeister buchen",
            mustContainWords: ["Kruder", "Dorfmeister", "buchen"],
            mustNotContainWords: [],
            mustPreserveChars: ["&"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Eigenname mit & muss komplett erhalten bleiben"
        ),
        TitleTestCase(
            input: "Mäx & Moritz Buch bestellen",
            mustContainWords: ["Moritz", "Buch", "bestellen"],
            mustNotContainWords: [],
            mustPreserveChars: ["&", "ä"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Eigenname mit Umlaut und & erhalten"
        ),

        // === Umlaute und ß ===
        TitleTestCase(
            input: "Bücher für Maria kaufen",
            mustContainWords: ["Maria", "kaufen"],
            mustNotContainWords: ["fuer", "Buecher"],
            mustPreserveChars: ["ü", "ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Umlaute duerfen nicht zu ASCII konvertiert werden"
        ),
        TitleTestCase(
            input: "Größe für Schuhe prüfen",
            mustContainWords: ["prüfen"],
            mustNotContainWords: ["Groesse", "fuer", "pruefen"],
            mustPreserveChars: ["ö", "ü", "ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Mehrere Umlaute + ß muessen erhalten bleiben"
        ),
        TitleTestCase(
            input: "Müller anrufen wegen Straßensperrung",
            mustContainWords: ["Müller", "anrufen"],
            mustNotContainWords: ["Mueller", "Strassensperrung"],
            mustPreserveChars: ["ü", "ß"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Eigenname Müller mit ü + Straße mit ß"
        ),

        // === Inhaltswoerter erhalten ===
        TitleTestCase(
            input: "Wolle waschen im Next up heute dringend",
            mustContainWords: ["Wolle", "waschen"],
            mustNotContainWords: [],
            mustPreserveChars: [],
            expectedUrgent: true,
            expectedHasDate: true,
            description: "Wolle ist Inhaltswort — WAS gewaschen wird darf nicht verloren gehen"
        ),
        TitleTestCase(
            input: "Rote Linsen für Suppe kaufen",
            mustContainWords: ["Rote", "Linsen", "Suppe", "kaufen"],
            mustNotContainWords: ["fuer"],
            mustPreserveChars: ["ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Alle Spezifikationen (Rote Linsen, Suppe) muessen bleiben"
        ),
        TitleTestCase(
            input: "3x Druckerpatronen schwarz bestellen",
            mustContainWords: ["Druckerpatronen", "schwarz", "bestellen"],
            mustNotContainWords: [],
            mustPreserveChars: [],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Mengenangabe und Farbe sind wichtiger Kontext"
        ),

        // === E-Mail Artefakte (korrekt entfernen) ===
        TitleTestCase(
            input: "Re: Fwd: AW: Quarterly Budget Review",
            mustContainWords: ["Quarterly", "Budget", "Review"],
            mustNotContainWords: ["Re:", "Fwd:", "AW:"],
            mustPreserveChars: [],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "E-Mail-Artefakte entfernen, Inhalt behalten"
        ),

        // === Einleitungsfloskeln (korrekt entfernen) ===
        TitleTestCase(
            input: "Erinnere mich daran Herrn Müller anzurufen",
            mustContainWords: ["Müller", "anzurufen"],
            mustNotContainWords: ["Erinnere", "Mueller"],
            mustPreserveChars: ["ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Floskel entfernen, Eigenname mit Umlaut behalten"
        ),
        TitleTestCase(
            input: "Ich muss noch die Steuererklärung machen",
            mustContainWords: ["Steuererklärung"],
            mustNotContainWords: ["Steuererklaerung"],
            mustPreserveChars: ["ä"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Floskel weg, Fachwort mit Umlaut behalten"
        ),

        // === Dringlichkeit + Datum ===
        TitleTestCase(
            input: "Dringend: Zahnarzttermin morgen absagen",
            mustContainWords: ["Zahnarzttermin", "absagen"],
            mustNotContainWords: ["Dringend"],
            mustPreserveChars: [],
            expectedUrgent: true,
            expectedHasDate: true,
            description: "Dringend entfernen, morgen als Datum, Inhalt behalten"
        ),

        // === Gemischte Sprache ===
        TitleTestCase(
            input: "JIRA Ticket für Login-Bug erstellen",
            mustContainWords: ["JIRA", "Ticket", "Login-Bug", "erstellen"],
            mustNotContainWords: ["fuer"],
            mustPreserveChars: ["ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Technische Begriffe (JIRA, Login-Bug) unverändert lassen"
        ),
        TitleTestCase(
            input: "Pull Request für Feature #42 reviewen",
            mustContainWords: ["Pull", "Request", "Feature", "reviewen"],
            mustNotContainWords: ["fuer"],
            mustPreserveChars: ["#", "ü"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Englisch-deutsche Mischung mit Sonderzeichen"
        ),

        // === Kurze Titel (sollen unverändert bleiben) ===
        TitleTestCase(
            input: "Einkaufen",
            mustContainWords: ["Einkaufen"],
            mustNotContainWords: [],
            mustPreserveChars: [],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Einwort-Titel darf nicht verändert werden"
        ),
        TitleTestCase(
            input: "Öl wechseln",
            mustContainWords: ["wechseln"],
            mustNotContainWords: ["Oel"],
            mustPreserveChars: ["Ö"],
            expectedUrgent: nil,
            expectedHasDate: false,
            description: "Kurzer Titel mit Umlaut am Anfang"
        ),
    ]}

    /// Fuehrt die gesamte Test-Matrix gegen das aktuelle TaskTitleEngine aus.
    /// Dieser Test zeigt WELCHE Eingaben problematisch sind.
    @available(iOS 26.0, macOS 26.0, *)
    func test_currentEngine_titleQuality() async throws {
        guard TaskTitleEngine.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar")
        }

        let context = container.mainContext
        var failures: [(input: String, output: String, reason: String)] = []

        for testCase in testCases {
            let task = LocalTask(title: testCase.input)
            task.needsTitleImprovement = true
            context.insert(task)
            try context.save()

            let engine = TaskTitleEngine(modelContext: context)
            await engine.improveTitleIfNeeded(task)

            let output = task.title

            // Pruefe mustContainWords
            for word in testCase.mustContainWords {
                if !output.contains(word) {
                    failures.append((testCase.input, output,
                        "\(testCase.description): '\(word)' fehlt im Output"))
                }
            }

            // Pruefe mustNotContainWords
            for word in testCase.mustNotContainWords {
                if output.contains(word) {
                    failures.append((testCase.input, output,
                        "\(testCase.description): '\(word)' sollte nicht im Output sein"))
                }
            }

            // Pruefe mustPreserveChars
            for char in testCase.mustPreserveChars {
                if !output.contains(String(char)) {
                    failures.append((testCase.input, output,
                        "\(testCase.description): Zeichen '\(char)' fehlt im Output"))
                }
            }

            // Pruefe Urgency
            if let expectedUrgent = testCase.expectedUrgent {
                let isUrgent = task.urgency == "urgent"
                if isUrgent != expectedUrgent {
                    failures.append((testCase.input, output,
                        "\(testCase.description): Urgency erwartet=\(expectedUrgent), got=\(isUrgent)"))
                }
            }

            // Pruefe Date
            if testCase.expectedHasDate && task.dueDate == nil {
                // Nur warnen wenn titleContainsDateKeyword true ist
                if TaskTitleEngine.titleContainsDateKeyword(testCase.input) {
                    failures.append((testCase.input, output,
                        "\(testCase.description): Datum erwartet aber nicht extrahiert"))
                }
            }

            // Cleanup fuer naechsten Test
            context.delete(task)
            try context.save()

            // Kurze Pause zwischen AI-Aufrufen
            try await Task.sleep(for: .milliseconds(300))
        }

        // Report
        if !failures.isEmpty {
            var report = "AI Title Quality: \(failures.count) Fehler gefunden:\n\n"
            for (i, f) in failures.enumerated() {
                report += "[\(i+1)] Input:  \(f.input)\n"
                report += "     Output: \(f.output)\n"
                report += "     Grund:  \(f.reason)\n\n"
            }
            XCTFail(report)
        }
    }

    // MARK: - Kategorie 4: AI Kategorisierung + Dauer-Schaetzung (RW_1.4)

    // MARK: - Kategorie 7: Kann Apple Intelligence beim Kategorisieren helfen?

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct CategorizedTask {
        @Guide(description: "The task category", .anyOf(["income", "maintenance", "recharge", "learning", "giving_back"]))
        var category: String

        @Guide(description: "Confidence: high, medium, or low", .anyOf(["high", "medium", "low"]))
        var confidence: String
    }

    @available(iOS 26.0, macOS 26.0, *)
    func test_categorization() async throws {
        guard SystemLanguageModel.default.availability == .available else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar")
        }

        let session = LanguageModelSession {
            "Categorize tasks into exactly one category:"
            "- income: Work, earning money, career, freelance, invoices, clients"
            "- maintenance: Household, errands, repairs, cleaning, groceries, health appointments"
            "- recharge: Exercise, rest, hobbies, meditation, wellness, fun"
            "- learning: Study, reading, courses, skills, research, training"
            "- giving_back: Family, friends, volunteering, gifts, social events, helping others"
        }

        struct CatTest {
            let input: String
            let expected: String
            let label: String
        }

        let cases: [CatTest] = [
            // --- Income ---
            CatTest(input: "Rechnung an Kunden schicken", expected: "income", label: "Earn"),
            CatTest(input: "Quartalsbericht fertigstellen", expected: "income", label: "Earn"),
            CatTest(input: "Bewerbung schreiben", expected: "income", label: "Earn"),
            CatTest(input: "Meeting mit Chef vorbereiten", expected: "income", label: "Earn"),
            CatTest(input: "Freelance-Projekt abrechnen", expected: "income", label: "Earn"),

            // --- Maintenance ---
            CatTest(input: "Wohnung aufräumen", expected: "maintenance", label: "Essentials"),
            CatTest(input: "Einkaufen gehen", expected: "maintenance", label: "Essentials"),
            CatTest(input: "Zahnarzt anrufen", expected: "maintenance", label: "Essentials"),
            CatTest(input: "Steuererklärung abgeben", expected: "maintenance", label: "Essentials"),
            CatTest(input: "Auto zum TÜV bringen", expected: "maintenance", label: "Essentials"),

            // --- Recharge ---
            CatTest(input: "Joggen gehen", expected: "recharge", label: "Self Care"),
            CatTest(input: "Sauna besuchen", expected: "recharge", label: "Self Care"),
            CatTest(input: "Neue Serie auf Netflix schauen", expected: "recharge", label: "Self Care"),
            CatTest(input: "Meditation 20 Minuten", expected: "recharge", label: "Self Care"),
            CatTest(input: "Gitarre üben", expected: "recharge", label: "Self Care"),

            // --- Learning ---
            CatTest(input: "Swift-Kurs weitermachen", expected: "learning", label: "Learn"),
            CatTest(input: "Buch über Produktivität lesen", expected: "learning", label: "Learn"),
            CatTest(input: "WWDC-Session anschauen", expected: "learning", label: "Learn"),
            CatTest(input: "Spanisch-Vokabeln lernen", expected: "learning", label: "Learn"),
            CatTest(input: "Podcast über KI hören", expected: "learning", label: "Learn"),

            // --- Social ---
            CatTest(input: "Mama anrufen", expected: "giving_back", label: "Social"),
            CatTest(input: "Geschenk für Sarahs Geburtstag kaufen", expected: "giving_back", label: "Social"),
            CatTest(input: "Nachbarin beim Umzug helfen", expected: "giving_back", label: "Social"),
            CatTest(input: "Abendessen mit Freunden organisieren", expected: "giving_back", label: "Social"),
            CatTest(input: "Ehrenamt im Tierheim", expected: "giving_back", label: "Social"),

            // --- Grenzfälle ---
            CatTest(input: "Kruder & Dorfmeister Tickets kaufen", expected: "recharge", label: "Self Care"),
            CatTest(input: "Wolle waschen", expected: "maintenance", label: "Essentials"),
            CatTest(input: "Pull Request reviewen", expected: "income", label: "Earn"),
            CatTest(input: "Kindergeburtstag planen", expected: "giving_back", label: "Social"),
            CatTest(input: "Erste-Hilfe-Kurs machen", expected: "learning", label: "Learn"),
        ]

        var report = "\n=== KATEGORISIERUNG MIT APPLE INTELLIGENCE ===\n\n"
        var correct = 0
        var errors = 0

        for c in cases {
            do {
                let response = try await session.respond(
                    to: "Categorize: \(c.input)",
                    generating: CategorizedTask.self
                )
                let r = response.content
                let ok = r.category == c.expected
                if ok { correct += 1 }
                let marker = ok ? "OK" : "MISS"

                report += "[\(marker)] \(c.input)\n"
                report += "  Erwartet: \(c.label) (\(c.expected))  →  Got: \(r.category) [\(r.confidence)]\n"
                if !ok { report += "  ^^^ FALSCH\n" }
                report += "\n"
            } catch {
                errors += 1
                report += "[ERROR] \(c.input)\n  \(error)\n\n"
            }

            try await Task.sleep(for: .milliseconds(200))
        }

        report += "=== Score: \(correct)/\(cases.count) korrekt, \(errors) Errors ===\n"
        print(report)
    }

    // MARK: - Kategorie 8: Kann Apple Intelligence Zeitaufwand schaetzen?

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct EstimatedTask {
        @Guide(description: "Estimated duration in minutes: 5 for quick tasks, 15 for short tasks, 30 for medium tasks, 60 for long tasks", .anyOf(["5", "15", "30", "60"]))
        var durationMinutes: String

        @Guide(description: "Confidence: high, medium, or low", .anyOf(["high", "medium", "low"]))
        var confidence: String
    }

    @available(iOS 26.0, macOS 26.0, *)
    func test_durationEstimation() async throws {
        guard SystemLanguageModel.default.availability == .available else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar")
        }

        let session = LanguageModelSession {
            "Estimate how long a task takes in minutes. Consider:"
            "- Quick calls/messages: 5-10 min"
            "- Simple errands (groceries, pickup): 15-30 min"
            "- Focused work (writing, coding): 30-60 min"
            "- Appointments (doctor, meeting): 30-60 min"
            "- Deep work (tax return, project): 60-120 min"
            "- Household chores: 15-45 min"
        }

        struct DurTest {
            let input: String
            let minMinutes: Int
            let maxMinutes: Int
            let label: String
        }

        let cases: [DurTest] = [
            // --- Schnelle Aufgaben → 5 min ---
            DurTest(input: "Mama anrufen", minMinutes: 5, maxMinutes: 15, label: "5 oder 15"),
            DurTest(input: "E-Mail an Chef schreiben", minMinutes: 5, maxMinutes: 15, label: "5 oder 15"),
            DurTest(input: "Termin beim Zahnarzt machen", minMinutes: 5, maxMinutes: 5, label: "5"),
            DurTest(input: "Medikamente bestellen", minMinutes: 5, maxMinutes: 15, label: "5 oder 15"),

            // --- Kurze Aufgaben → 15 min ---
            DurTest(input: "Einkaufen gehen", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),
            DurTest(input: "Wohnung aufräumen", minMinutes: 30, maxMinutes: 60, label: "30 oder 60"),
            DurTest(input: "Wolle waschen", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),
            DurTest(input: "Paket zur Post bringen", minMinutes: 15, maxMinutes: 15, label: "15"),

            // --- Mittlere Aufgaben → 30 min ---
            DurTest(input: "Quartalsbericht schreiben", minMinutes: 30, maxMinutes: 60, label: "30 oder 60"),
            DurTest(input: "Pull Request reviewen", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),
            DurTest(input: "Bewerbung schreiben", minMinutes: 30, maxMinutes: 60, label: "30 oder 60"),
            DurTest(input: "Präsentation vorbereiten", minMinutes: 30, maxMinutes: 60, label: "30 oder 60"),

            // --- Lange Aufgaben → 60 min ---
            DurTest(input: "Steuererklärung machen", minMinutes: 60, maxMinutes: 60, label: "60"),
            DurTest(input: "Umzugskartons packen", minMinutes: 60, maxMinutes: 60, label: "60"),
            DurTest(input: "WWDC-Session anschauen und Notizen machen", minMinutes: 30, maxMinutes: 60, label: "30 oder 60"),

            // --- Sport/Freizeit ---
            DurTest(input: "Joggen gehen", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),
            DurTest(input: "Meditation 20 Minuten", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),
            DurTest(input: "Gitarre üben", minMinutes: 15, maxMinutes: 30, label: "15 oder 30"),

            // --- Mit expliziter Zeitangabe ---
            DurTest(input: "30 Minuten Spanisch lernen", minMinutes: 30, maxMinutes: 30, label: "30"),
            DurTest(input: "1 Stunde lesen", minMinutes: 60, maxMinutes: 60, label: "60"),
        ]

        var report = "\n=== ZEITSCHAETZUNG MIT APPLE INTELLIGENCE ===\n\n"
        var correct = 0
        var errors = 0

        for c in cases {
            do {
                let response = try await session.respond(
                    to: "Estimate duration: \(c.input)",
                    generating: EstimatedTask.self
                )
                let r = response.content
                let dur = Int(r.durationMinutes) ?? 0
                let inRange = dur >= c.minMinutes && dur <= c.maxMinutes
                if inRange { correct += 1 }
                let marker = inRange ? "OK" : "MISS"

                report += "[\(marker)] \(c.input)\n"
                report += "  Geschätzt: \(dur) min [\(r.confidence)]  Erwartet: \(c.minMinutes)-\(c.maxMinutes) min (\(c.label))\n"
                if !inRange { report += "  ^^^ AUSSERHALB\n" }
                report += "\n"
            } catch {
                errors += 1
                report += "[ERROR] \(c.input)\n  \(error)\n\n"
            }

            try await Task.sleep(for: .milliseconds(200))
        }

        report += "=== Score: \(correct)/\(cases.count) in Range, \(errors) Errors ===\n"
        print(report)
    }

    #endif
}
