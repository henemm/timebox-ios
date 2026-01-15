import Foundation
import SwiftData

/// SwiftData model for locally stored tasks.
/// Supports CloudKit sync when enabled on the ModelContainer.
/// Note: CloudKit requires all attributes to have default values.
@Model
final class LocalTask {
    /// Unique identifier stored as UUID for SwiftData
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var priority: Int = 0
    var category: String?
    var categoryColorHex: String?
    var dueDate: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var manualDuration: Int?

    /// String id for TaskSourceData protocol conformance
    var id: String { uuid.uuidString }

    init(
        uuid: UUID = UUID(),
        title: String,
        priority: Int,
        isCompleted: Bool = false,
        category: String? = nil,
        categoryColorHex: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.uuid = uuid
        self.title = title
        self.priority = priority
        self.isCompleted = isCompleted
        self.category = category
        self.categoryColorHex = categoryColorHex
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

// MARK: - TaskSourceData Conformance

extension LocalTask: TaskSourceData {
    /// Map category to categoryTitle for TaskSourceData protocol
    var categoryTitle: String? { category }
}
