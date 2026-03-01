---
entity_id: itb-g-proactive-suggestions
type: feature
created: 2026-02-23
updated: 2026-02-23
status: draft
version: "1.0"
tags: [system-integration, siri, spotlight, widgets, intents-the-box]
---

# ITB-G: Proaktive System-Vorschlaege

## Approval

- [ ] Approved

## Purpose

ITB-G macht FocusBlox im iOS/macOS-System proaktiv sichtbar durch Intent Donations (Siri-Lernfaehigkeit), Spotlight-Indexierung (Systemsuche), Widget Relevance (Smart Stack-Platzierung) und Siri Tips (Onboarding). Ziel: FocusBlox taucht zur richtigen Zeit am richtigen Ort auf, ohne dass der User aktiv danach suchen muss.

## Source

Multi-Component Feature mit 4 unabhaengigen Teilbereichen:

- **ITB-G1:** Intent Donation (~6 Dateien)
- **ITB-G2:** Spotlight Indexing (~1 neue + 1 modifizierte Datei)
- **ITB-G3:** Widget Relevance (~1 Datei)
- **ITB-G4:** Siri Tips (~3 Dateien)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| AppIntents Framework | System | Intent Donation API |
| CoreSpotlight Framework | System | Spotlight Indexierung |
| WidgetKit Framework | System | Widget Relevance API |
| SharedModelContainer | Service | SwiftData Container fuer Intents |
| LocalTask | Model | Task-Entity fuer Indexierung |
| QuickCaptureState | Service | State fuer Quick Capture Intent |
| FocusBlockActionService | Service | Focus Block Actions |
| SyncEngine | Service | Task Sync nach Erstellung |

## Scoping Limits

**Betroffene Dateien:** 10 modifiziert + 1 neu = 11 total

**Neue Dateien:**
- `Sources/Services/SpotlightIndexingService.swift` (~60 LoC)

**Modifizierte Dateien:**
- `Sources/Intents/QuickCaptureSubIntents.swift` (+3 LoC)
- `Sources/Intents/CompleteTaskIntent.swift` (+3 LoC)
- `Sources/Views/QuickCaptureView.swift` (+3 LoC)
- `Sources/Views/TaskFormSheet.swift` (+3 LoC)
- `Sources/Services/SyncEngine.swift` (+5 LoC)
- `Sources/Services/FocusBlockActionService.swift` (+3 LoC)
- `FocusBloxWidgets/QuickCaptureWidget.swift` (+30 LoC)
- `Sources/Components/Backlog/BacklogView.swift` (+5 LoC)
- `Sources/ContentView.swift` (+5 LoC)
- `Sources/Views/Settings/SettingsView.swift` (+3 LoC)

**Gesamtschaetzung:** ~115 LoC (innerhalb Limit)

**Files:** 11 (ueber Limit von 4-5, aber 4 unabhaengige Teilbereiche — jeder einzelne Teilbereich ist innerhalb Limit)

## Implementation Details

### ITB-G1: Intent Donation

**Problem:** FocusBlox donated ZERO Intents — Siri kann keine Nutzungsmuster lernen.

**Loesung:** IntentDonationManager.shared.donate(intent:) an 6 strategischen Donation-Punkten.

**Pattern:**
```swift
// Nach erfolgreichem Task-Save
let intent = SaveQuickCaptureIntent(taskTitle: task.title)
IntentDonationManager.shared.donate(intent: intent)
```

**Donation-Punkte:**

1. **SaveQuickCaptureIntent** (Sources/Intents/QuickCaptureSubIntents.swift:125)
   - Nach `context.save()` in `perform()`
   - Intent: SaveQuickCaptureIntent mit taskTitle

2. **CompleteTaskIntent** (Sources/Intents/CompleteTaskIntent.swift:40)
   - Nach `context.save()` in `perform()`
   - Intent: CompleteTaskIntent mit task.id

3. **QuickCaptureView** (Sources/Views/QuickCaptureView.swift:300+)
   - In `saveTask()` nach erfolgreichem Save
   - Intent: SaveQuickCaptureIntent mit title

4. **TaskFormSheet** (Sources/Views/TaskFormSheet.swift:416+)
   - In `saveTask()` nach erfolgreichem Save
   - Intent: CreateTaskIntent mit title/category/importance

5. **SyncEngine** (Sources/Services/SyncEngine.swift:171)
   - Nach erfolgreichem Sync in `syncTasks()`
   - Intent: CreateTaskIntent fuer neu erstellte Tasks

6. **FocusBlockActionService** (Sources/Services/FocusBlockActionService.swift:58)
   - Nach `completeTask()` in `modelContext.save()`
   - Intent: CompleteTaskIntent mit task.id

**Anti-Pattern:**
```swift
// FALSCH: Timestamps donated
let intent = CreateTaskIntent(
    title: task.title,
    createdAt: Date() // ❌ Nicht donaten - verhindert Pattern-Erkennung
)

// RICHTIG: Nur stabile Parameter
let intent = CreateTaskIntent(
    title: task.title,
    category: task.taskType
)
```

**Implementierung:**

```swift
// Sources/Intents/QuickCaptureSubIntents.swift
struct SaveQuickCaptureIntent: AppIntent {
    // ... existing code ...

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        // ... task creation ...

        context.insert(task)
        try context.save()

        // DONATION POINT
        let donationIntent = SaveQuickCaptureIntent(taskTitle: taskTitle)
        IntentDonationManager.shared.donate(intent: donationIntent)

        return .result(dialog: "Task '\(taskTitle)' erstellt.")
    }
}
```

### ITB-G2: Spotlight Indexing

**Problem:** Tasks sind in iOS/macOS Spotlight unsichtbar.

**Loesung:** Neuer Service `SpotlightIndexingService` fuer CSSearchableItem-Indexierung.

**Service-Architektur:**

```swift
// Sources/Services/SpotlightIndexingService.swift
import CoreSpotlight
import SwiftData

actor SpotlightIndexingService {
    static let shared = SpotlightIndexingService()
    private let searchableIndex = CSSearchableIndex.default()

    private init() {}

    /// Index a single task after creation/update
    func indexTask(_ task: LocalTask) async throws {
        guard !task.isCompleted else { return }
        guard task.recurrencePattern == "none" else { return } // No templates

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = task.title
        attributes.contentDescription = task.taskDescription
        attributes.keywords = task.tags.components(separatedBy: ",")
        attributes.contentCreationDate = task.createdAt
        attributes.contentModificationDate = task.updatedAt

        // Custom attributes
        attributes.setValue(task.taskType, forCustomKey: "taskType")
        attributes.setValue(task.importance, forCustomKey: "importance")
        attributes.setValue(task.urgency, forCustomKey: "urgency")
        if let dueDate = task.dueDate {
            attributes.setValue(dueDate, forCustomKey: "dueDate")
        }

        let item = CSSearchableItem(
            uniqueIdentifier: task.uuid.uuidString,
            domainIdentifier: "com.focusblox.tasks",
            attributeSet: attributes
        )

        try await searchableIndex.indexSearchableItems([item])
    }

    /// Remove task from index after deletion
    func deindexTask(uuid: UUID) async throws {
        try await searchableIndex.deleteSearchableItems(withIdentifiers: [uuid.uuidString])
    }

    /// Reindex all incomplete tasks (called at app start)
    func reindexAllTasks(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { task in
                !task.isCompleted && task.recurrencePattern == "none"
            }
        )
        let tasks = try context.fetch(descriptor)

        // Delete all existing items first
        try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["com.focusblox.tasks"])

        // Index all tasks
        for task in tasks {
            try await indexTask(task)
        }
    }
}
```

**Integration-Punkte:**

1. **Nach Task-Erstellung:** TaskFormSheet, QuickCaptureView, SyncEngine
2. **Nach Task-Update:** TaskFormSheet (beim Bearbeiten)
3. **Nach Task-Loeschung:** Deletion-Handler
4. **App-Start:** FocusBloxApp.init()

**Beispiel-Integration:**

```swift
// Sources/Views/TaskFormSheet.swift
private func saveTask() {
    // ... existing save logic ...
    try context.save()

    // Spotlight indexing
    Task {
        try await SpotlightIndexingService.shared.indexTask(task)
    }
}
```

### ITB-G3: Widget Relevance

**Problem:** QuickCaptureWidget hat keinen Relevance-Score — taucht nie in Smart Stack auf.

**Loesung:** `TimelineEntryRelevance` basierend auf aktuellem Kontext.

**Relevance-Logik:**

| Kontext | Score | Begruendung |
|---------|-------|-------------|
| Aktiver Focus Block | 100 | Hoechste Prioritaet - User ist gerade produktiv |
| Dringende Tasks (urgent) | 80 | Tasks mit Deadline stehen an |
| Normale Tasks (not_urgent) | 40 | Tasks vorhanden, aber nicht kritisch |
| Idle (keine Tasks) | 10 | Fallback - Widget immer verfuegbar |

**Implementierung:**

```swift
// FocusBloxWidgets/QuickCaptureWidget.swift

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    let relevance: TimelineEntryRelevance?
}

struct QuickCaptureProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        Task {
            let container = try SharedModelContainer.create()
            let modelContext = ModelContext(container)

            // Check for active focus block
            let focusDescriptor = FetchDescriptor<FocusBlock>(
                predicate: #Predicate { block in block.isActive }
            )
            let activeFocusBlock = try? modelContext.fetch(focusDescriptor).first

            // Check for urgent tasks
            let urgentDescriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { task in
                    !task.isCompleted && task.urgency == "urgent"
                }
            )
            let urgentCount = (try? modelContext.fetchCount(urgentDescriptor)) ?? 0

            // Check for any incomplete tasks
            let taskDescriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { task in !task.isCompleted }
            )
            let taskCount = (try? modelContext.fetchCount(taskDescriptor)) ?? 0

            // Calculate relevance score
            let score: Double
            if activeFocusBlock != nil {
                score = 100.0
            } else if urgentCount > 0 {
                score = 80.0
            } else if taskCount > 0 {
                score = 40.0
            } else {
                score = 10.0
            }

            let relevance = TimelineEntryRelevance(score: score)
            let entry = QuickCaptureEntry(date: Date(), relevance: relevance)

            // Update every 15 minutes to refresh relevance
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

            completion(timeline)
        }
    }
}
```

**Timeline-Policy Aenderung:**

```swift
// VORHER:
let timeline = Timeline(entries: [entry], policy: .never)

// NACHHER:
let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
```

### ITB-G4: Siri Tip Views

**Problem:** User entdecken App Shortcuts nicht.

**Loesung:** Apple's native `SiriTipView` (AppIntents Framework, seit iOS 16) an 3 strategischen Stellen. Keine Custom-Komponente noetig — Apple liefert fertige UI mit korrektem Siri-Branding.

**Pattern:**

```swift
import AppIntents

// Apple's native SiriTipView — zeigt Siri-Phrase + Branding
SiriTipView(intent: CreateTaskIntent(), isVisible: $showCreateTip)
```

**Integration-Stellen:**

1. **BacklogView** (Sources/Components/Backlog/BacklogView.swift)
   - Intent: CreateTaskIntent()
   - Phrase: "Erstelle Task in FocusBlox"

2. **ContentView** (Sources/ContentView.swift)
   - Intent: GetNextUpIntent()
   - Phrase: "Was steht an in FocusBlox"

3. **SettingsView** (Sources/Views/Settings/SettingsView.swift)
   - Intent: CompleteTaskIntent()
   - Phrase: "Markiere als erledigt in FocusBlox"

**Beispiel-Integration:**

```swift
// Sources/Components/Backlog/BacklogView.swift
struct BacklogView: View {
    @State private var showCreateTaskTip = true

    var body: some View {
        VStack(spacing: 16) {
            SiriTipView(intent: CreateTaskIntent(), isVisible: $showCreateTaskTip)

            // ... existing backlog content ...
        }
    }
}
```

**Hinweis:** Apple's SiriTipView handhabt Dismiss automatisch (setzt isVisible auf false). Kein UserDefaults noetig — das System merkt sich den Dismiss-State.

## Expected Behavior

### ITB-G1: Intent Donation

**Input:** User erstellt Task via QuickCaptureView
**Output:**
- Intent wird donated
- Siri lernt Pattern (z.B. "Montag 9 Uhr → Task erstellen")
- Nach 2-3 Wiederholungen: Siri schlaegt Shortcut proaktiv vor

**Side Effects:**
- Intent erscheint in iOS Settings → Siri & Search → Shortcuts
- Intent kann in Shortcuts App verwendet werden
- Spotlight zeigt Intent bei relevanten Suchen

### ITB-G2: Spotlight Indexing

**Input:** User erstellt Task "Einkaufen: Milch, Brot, Butter"
**Output:**
- Task erscheint in Spotlight-Suche bei "Einkaufen"
- Task erscheint bei "Milch", "Brot", "Butter" (Keywords)
- Tap auf Suchergebnis → oeffnet FocusBlox mit diesem Task

**Side Effects:**
- Task-Metadata in CoreSpotlight Index
- Index wird bei App-Start refreshed
- Bei Task-Deletion: Automatisches Deindexing

### ITB-G3: Widget Relevance

**Input:** User startet Focus Block
**Output:**
- QuickCaptureWidget erhaelt Relevance-Score 100
- Widget rutscht in Smart Stack nach oben
- Widget wird automatisch angezeigt wenn User zum Home Screen geht

**Side Effects:**
- Timeline-Update alle 15 Minuten
- Widget-Refresh bei Kontext-Aenderung

### ITB-G4: Siri Tips

**Input:** User oeffnet App zum ersten Mal
**Output:**
- SiriTipView erscheint in BacklogView
- Text: "Sage 'Hey Siri, Task erstellen'"
- Dismissible via X-Button

**Side Effects:**
- UserDefaults-Flag gesetzt nach Dismiss
- Tip erscheint nur einmal pro Location

## Test Plan

### Unit Tests

#### ITB-G1: Intent Donation Tests

**File:** `Tests/IntentDonationTests.swift`

```swift
final class IntentDonationTests: XCTestCase {
    func test_saveQuickCaptureIntent_donatesAfterSave() async throws {
        // Arrange
        let intent = SaveQuickCaptureIntent(taskTitle: "Test Task")

        // Act
        _ = try await intent.perform()

        // Assert
        let donations = await IntentDonationManager.shared.getDonations()
        XCTAssertEqual(donations.count, 1)
        XCTAssertEqual(donations.first?.title, "Test Task")
    }

    func test_completeTaskIntent_donatesAfterSave() async throws {
        // Arrange
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let task = LocalTask(title: "Test")
        context.insert(task)
        try context.save()

        let intent = CompleteTaskIntent(task: TaskEntity(id: task.uuid.uuidString, title: "Test"))

        // Act
        _ = try await intent.perform()

        // Assert
        let donations = await IntentDonationManager.shared.getDonations()
        XCTAssertTrue(donations.contains { $0.id == task.uuid.uuidString })
    }

    func test_donation_excludesTimestamps() async throws {
        // Arrange
        let intent = CreateTaskIntent(title: "Test")

        // Act
        await IntentDonationManager.shared.donate(intent: intent)

        // Assert
        let donations = await IntentDonationManager.shared.getDonations()
        let donated = donations.first!
        // Verify no timestamp properties were donated
        XCTAssertNil(donated.createdAt)
        XCTAssertNil(donated.updatedAt)
    }
}
```

#### ITB-G2: Spotlight Indexing Tests

**File:** `Tests/SpotlightIndexingServiceTests.swift`

```swift
final class SpotlightIndexingServiceTests: XCTestCase {
    var service: SpotlightIndexingService!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        service = SpotlightIndexingService.shared
        container = try SharedModelContainer.create()
        context = ModelContext(container)
    }

    func test_indexTask_createsSearchableItem() async throws {
        // Arrange
        let task = LocalTask(
            title: "Einkaufen",
            taskDescription: "Milch, Brot, Butter",
            tags: "shopping,groceries"
        )
        context.insert(task)
        try context.save()

        // Act
        try await service.indexTask(task)

        // Assert
        let items = try await fetchIndexedItems(for: task.uuid)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.attributeSet.title, "Einkaufen")
        XCTAssertEqual(items.first?.attributeSet.keywords, ["shopping", "groceries"])
    }

    func test_indexTask_skipsCompletedTasks() async throws {
        // Arrange
        let task = LocalTask(title: "Completed", isCompleted: true)
        context.insert(task)
        try context.save()

        // Act
        try await service.indexTask(task)

        // Assert
        let items = try await fetchIndexedItems(for: task.uuid)
        XCTAssertEqual(items.count, 0)
    }

    func test_indexTask_skipsRecurringTemplates() async throws {
        // Arrange
        let task = LocalTask(title: "Template", recurrencePattern: "daily")
        context.insert(task)
        try context.save()

        // Act
        try await service.indexTask(task)

        // Assert
        let items = try await fetchIndexedItems(for: task.uuid)
        XCTAssertEqual(items.count, 0)
    }

    func test_deindexTask_removesFromSpotlight() async throws {
        // Arrange
        let task = LocalTask(title: "To Delete")
        context.insert(task)
        try context.save()
        try await service.indexTask(task)

        // Act
        try await service.deindexTask(uuid: task.uuid)

        // Assert
        let items = try await fetchIndexedItems(for: task.uuid)
        XCTAssertEqual(items.count, 0)
    }

    func test_reindexAllTasks_indexesOnlyActiveTasks() async throws {
        // Arrange
        let active1 = LocalTask(title: "Active 1")
        let active2 = LocalTask(title: "Active 2")
        let completed = LocalTask(title: "Completed", isCompleted: true)
        let template = LocalTask(title: "Template", recurrencePattern: "weekly")

        [active1, active2, completed, template].forEach { context.insert($0) }
        try context.save()

        // Act
        try await service.reindexAllTasks(context: context)

        // Assert
        let allItems = try await fetchAllIndexedItems()
        XCTAssertEqual(allItems.count, 2)
        XCTAssertTrue(allItems.contains { $0.attributeSet.title == "Active 1" })
        XCTAssertTrue(allItems.contains { $0.attributeSet.title == "Active 2" })
    }
}
```

#### ITB-G3: Widget Relevance Tests

**File:** `Tests/QuickCaptureWidgetTests.swift`

```swift
final class QuickCaptureWidgetTests: XCTestCase {
    func test_relevance_activeFocusBlock_returns100() async throws {
        // Arrange
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let block = FocusBlock(title: "Deep Work", isActive: true)
        context.insert(block)
        try context.save()

        let provider = QuickCaptureProvider()

        // Act
        let entry = await withCheckedContinuation { continuation in
            provider.getTimeline(in: TimelineProviderContext()) { timeline in
                continuation.resume(returning: timeline.entries.first!)
            }
        }

        // Assert
        XCTAssertEqual(entry.relevance?.score, 100.0)
    }

    func test_relevance_urgentTasks_returns80() async throws {
        // Arrange
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let task = LocalTask(title: "Urgent", urgency: "urgent")
        context.insert(task)
        try context.save()

        let provider = QuickCaptureProvider()

        // Act
        let entry = await withCheckedContinuation { continuation in
            provider.getTimeline(in: TimelineProviderContext()) { timeline in
                continuation.resume(returning: timeline.entries.first!)
            }
        }

        // Assert
        XCTAssertEqual(entry.relevance?.score, 80.0)
    }

    func test_relevance_normalTasks_returns40() async throws {
        // Arrange
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let task = LocalTask(title: "Normal")
        context.insert(task)
        try context.save()

        let provider = QuickCaptureProvider()

        // Act
        let entry = await withCheckedContinuation { continuation in
            provider.getTimeline(in: TimelineProviderContext()) { timeline in
                continuation.resume(returning: timeline.entries.first!)
            }
        }

        // Assert
        XCTAssertEqual(entry.relevance?.score, 40.0)
    }

    func test_relevance_noTasks_returns10() async throws {
        // Arrange
        let container = try SharedModelContainer.create()
        let provider = QuickCaptureProvider()

        // Act
        let entry = await withCheckedContinuation { continuation in
            provider.getTimeline(in: TimelineProviderContext()) { timeline in
                continuation.resume(returning: timeline.entries.first!)
            }
        }

        // Assert
        XCTAssertEqual(entry.relevance?.score, 10.0)
    }

    func test_timelinePolicy_updatesEvery15Minutes() async throws {
        // Arrange
        let provider = QuickCaptureProvider()

        // Act
        let timeline = await withCheckedContinuation { continuation in
            provider.getTimeline(in: TimelineProviderContext()) { timeline in
                continuation.resume(returning: timeline)
            }
        }

        // Assert
        if case .after(let date) = timeline.policy {
            let interval = date.timeIntervalSince(Date())
            XCTAssertEqual(interval, 15 * 60, accuracy: 10) // 15 min ± 10s
        } else {
            XCTFail("Expected .after policy")
        }
    }
}
```

#### ITB-G4: Siri Tips — kein Unit Test noetig

Apple's native `SiriTipView` braucht keine Unit Tests — das ist Apple's Komponente. Integration wird per UI Test verifiziert.

### UI Tests

**File:** `FocusBloxUITests/ITB_G_ProactiveSuggestionsUITests.swift`

```swift
final class ITB_G_ProactiveSuggestionsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    // ITB-G4: Siri Tip visibility in BacklogView
    func test_siriTip_visibleInBacklog() {
        // Navigate to BacklogView
        app.buttons["Backlog"].tap()

        // SiriTipView renders as a view containing the Siri phrase text
        let tipText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Task erstellen'"))
        XCTAssertTrue(tipText.firstMatch.waitForExistence(timeout: 3))
    }
}
```

## Acceptance Criteria

### ITB-G1: Intent Donation

- [ ] SaveQuickCaptureIntent donated nach Task-Erstellung
- [ ] CompleteTaskIntent donated nach Task-Completion
- [ ] CreateTaskIntent donated in QuickCaptureView
- [ ] CreateTaskIntent donated in TaskFormSheet
- [ ] CreateTaskIntent donated in SyncEngine (neue Tasks)
- [ ] CompleteTaskIntent donated in FocusBlockActionService
- [ ] KEINE Timestamps in donated Intents
- [ ] Intents erscheinen in iOS Settings → Siri & Search
- [ ] Intents verwendbar in Shortcuts App

### ITB-G2: Spotlight Indexing

- [ ] SpotlightIndexingService.swift erstellt
- [ ] Tasks werden nach Erstellung indexiert
- [ ] Tasks werden nach Update re-indexiert
- [ ] Tasks werden nach Deletion deindexiert
- [ ] Erledigte Tasks werden NICHT indexiert
- [ ] Recurring Templates werden NICHT indexiert
- [ ] reindexAllTasks() laeuft bei App-Start
- [ ] Tasks erscheinen in Spotlight-Suche
- [ ] Tap auf Suchergebnis oeffnet FocusBlox

### ITB-G3: Widget Relevance

- [ ] QuickCaptureEntry hat relevance-Property
- [ ] Aktiver Focus Block → Score 100
- [ ] Dringende Tasks → Score 80
- [ ] Normale Tasks → Score 40
- [ ] Keine Tasks → Score 10
- [ ] Timeline-Policy: .after(15 Minuten)
- [ ] Widget erscheint in Smart Stack bei hoher Relevance

### ITB-G4: Siri Tips

- [ ] Apple's native SiriTipView in BacklogView (CreateTaskIntent)
- [ ] Apple's native SiriTipView in ContentView (GetNextUpIntent)
- [ ] Apple's native SiriTipView in SettingsView (CompleteTaskIntent)
- [ ] Tips sind dismissible (native Apple-Handling)
- [ ] Tips erscheinen nicht erneut nach Dismiss

### Cross-Platform

- [ ] Intent Donation funktioniert auf iOS + macOS
- [ ] Spotlight Indexing funktioniert auf iOS + macOS
- [ ] Widget Relevance nur iOS (Widgets auf macOS nicht relevant)
- [ ] Siri Tips nur iOS (macOS hat andere Onboarding-Patterns)

### Testing

- [ ] Alle Unit Tests gruen (Intent Donation, Spotlight, Widget Relevance)
- [ ] UI Tests gruen (Siri Tip visibility)
- [ ] Build erfolgreich auf iOS + macOS
- [ ] Keine Compiler-Warnings

## Known Limitations

### ITB-G1: Intent Donation
- Siri-Lernfaehigkeit braucht 2-3 Wiederholungen
- Patterns nur erkennbar bei konsistentem Verhalten (z.B. immer Montag 9 Uhr)
- Donated Intents nicht sofort in Shortcuts sichtbar (iOS-Cache)

### ITB-G2: Spotlight Indexing
- Spotlight-Index nicht sofort verfuegbar (iOS-Indexierung asynchron)
- Max. 4096 Zeichen pro Attribut (CSSearchableItemAttributeSet)
- Index wird bei iOS-Updates teilweise geloescht (Reindexing noetig)

### ITB-G3: Widget Relevance
- Smart Stack Algorithmus nicht dokumentiert (Score ist nur Hint)
- Widget-Timeline-Updates kosten Battery (15min ist Kompromiss)
- Relevance auf watchOS nicht unterstuetzt

### ITB-G4: Siri Tips
- SiriTipView nur auf iOS verfuegbar (keine macOS-Component)
- Tips koennen vom User ignoriert werden (kein Zwang)
- UserDefaults nicht iCloud-synced (Tips erscheinen auf jedem Geraet neu)

## Changelog

- 2026-02-23: Initial spec created (ITB-G Proactive Suggestions)
