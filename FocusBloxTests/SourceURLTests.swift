import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class SourceURLTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - sourceURL Property

    /// Verhalten: Neues sourceURL Property hat Default nil
    /// Bricht wenn: LocalTask kein `sourceURL: String?` Property hat oder Default != nil
    func test_sourceURL_defaultIsNil() throws {
        let task = LocalTask(title: "Test task")
        XCTAssertNil(task.sourceURL, "sourceURL should default to nil")
    }

    /// Verhalten: sourceURL wird korrekt in SwiftData persistiert
    /// Bricht wenn: sourceURL nicht als @Model-Property deklariert ist (nicht persistiert)
    func test_sourceURL_persistsInSwiftData() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Safari task")
        task.sourceURL = "https://developer.apple.com/wwdc25"
        context.insert(task)
        try context.save()

        // Neu fetchen um Persistenz zu pruefen
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.title == "Safari task" }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sourceURL, "https://developer.apple.com/wwdc25",
                       "sourceURL should persist in SwiftData")
    }

    /// Verhalten: TaskTitleEngine veraendert sourceURL NICHT wenn es den Titel verbessert
    /// Bricht wenn: TaskTitleEngine.performImprovement() sourceURL ueberschreibt oder auf nil setzt
    func test_sourceURL_preservedAfterTitleImprovement() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Re: Meeting next week")
        task.needsTitleImprovement = true
        task.sourceURL = "https://mail.example.com/thread/123"
        context.insert(task)
        try context.save()

        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "aiScoringEnabled") }

        let engine = TaskTitleEngine(modelContext: context)
        await engine.improveTitleIfNeeded(task)

        XCTAssertEqual(task.sourceURL, "https://mail.example.com/thread/123",
                       "sourceURL must NOT be modified by TaskTitleEngine")
    }
}
