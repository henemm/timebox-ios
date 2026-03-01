import CoreSpotlight
import SwiftData

/// Indexes FocusBlox tasks in Spotlight for system-wide search (ITB-G2).
/// Active, non-template tasks are indexed; completed/template tasks are excluded.
actor SpotlightIndexingService {
    static let shared = SpotlightIndexingService()
    private let searchableIndex = CSSearchableIndex.default()
    static let domainIdentifier = "com.focusblox.tasks"

    private init() {}

    // MARK: - Filter Logic

    /// Determines whether a task should be indexed in Spotlight.
    /// Excludes completed tasks and recurring templates.
    nonisolated func shouldIndex(_ task: LocalTask) -> Bool {
        guard !task.isCompleted else { return false }
        guard !task.isTemplate else { return false }
        return true
    }

    // MARK: - Attribute Building

    /// Builds a CSSearchableItemAttributeSet from a LocalTask.
    nonisolated func buildAttributeSet(for task: LocalTask) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = task.title
        attributes.contentDescription = task.taskDescription

        // Build keywords from tags + taskType
        var keywords: [String] = task.tags.filter { !$0.isEmpty }
        if !task.taskType.isEmpty {
            keywords.append(task.taskType)
        }
        if !keywords.isEmpty {
            attributes.keywords = keywords
        }

        return attributes
    }

    /// Builds a CSSearchableItem with correct identifier and domain.
    nonisolated func buildSearchableItem(for task: LocalTask) throws -> CSSearchableItem {
        CSSearchableItem(
            uniqueIdentifier: task.uuid.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: buildAttributeSet(for: task)
        )
    }

    // MARK: - Index Operations

    /// Index a single task after creation/update.
    func indexTask(_ task: LocalTask) async throws {
        guard shouldIndex(task) else { return }
        let item = try buildSearchableItem(for: task)
        try await searchableIndex.indexSearchableItems([item])
    }

    /// Remove a task from the index after deletion/completion.
    func deindexTask(uuid: UUID) async throws {
        try await searchableIndex.deleteSearchableItems(
            withIdentifiers: [uuid.uuidString]
        )
    }

    /// Reindex all active, non-template tasks (called at app start).
    func reindexAllTasks(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { task in
                !task.isCompleted && !task.isTemplate
            }
        )
        let tasks = try context.fetch(descriptor)

        // Clear existing index
        try await searchableIndex.deleteSearchableItems(
            withDomainIdentifiers: [Self.domainIdentifier]
        )

        // Index all active tasks
        let items = try tasks.map { try buildSearchableItem(for: $0) }
        if !items.isEmpty {
            try await searchableIndex.indexSearchableItems(items)
        }
    }
}
