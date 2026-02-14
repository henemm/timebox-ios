import Foundation
import CoreData
import Observation
import SwiftData

/// Monitors CloudKit sync events via NSPersistentCloudKitContainer notifications.
/// SwiftData uses NSPersistentCloudKitContainer internally - its events are observable
/// through NSPersistentCloudKitContainer.eventChangedNotification.
@Observable
@MainActor
final class CloudKitSyncMonitor {

    // MARK: - Sync State

    enum SyncState: Equatable {
        case notStarted
        case inProgress(started: Date)
        case succeeded(started: Date, ended: Date)
        case failed(started: Date, ended: Date, error: String)

        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted): return true
            case (.inProgress, .inProgress): return true
            case (.succeeded, .succeeded): return true
            case (.failed, .failed): return true
            default: return false
            }
        }
    }

    enum SyncEventType {
        case setup
        case `import`
        case export
    }

    // MARK: - State

    private(set) var setupState: SyncState = .notStarted
    private(set) var importState: SyncState = .notStarted
    private(set) var exportState: SyncState = .notStarted

    /// Increments on each successful import - observe this to auto-refresh views.
    private(set) var importSuccessCount: Int = 0

    // MARK: - Computed Properties

    var isSyncing: Bool {
        if case .inProgress = importState { return true }
        if case .inProgress = exportState { return true }
        return false
    }

    var hasSyncError: Bool {
        if case .failed = setupState { return true }
        if case .failed = importState { return true }
        if case .failed = exportState { return true }
        return false
    }

    var lastSuccessfulSync: Date? {
        let dates: [Date?] = [
            { if case .succeeded(_, let ended) = importState { return ended }; return nil }(),
            { if case .succeeded(_, let ended) = exportState { return ended }; return nil }()
        ]
        return dates.compactMap { $0 }.max()
    }

    var errorMessage: String? {
        if case .failed(_, _, let msg) = setupState { return msg }
        if case .failed(_, _, let msg) = importState { return msg }
        if case .failed(_, _, let msg) = exportState { return msg }
        return nil
    }

    // MARK: - Observation

    @ObservationIgnored
    private var syncEventTask: Task<Void, Never>?

    @ObservationIgnored
    private var remoteChangeTask: Task<Void, Never>?

    @ObservationIgnored
    private var modelContainer: ModelContainer?

    /// Snapshot of task attributes for diff-based change logging.
    @ObservationIgnored
    private var lastSnapshot: [String: String] = [:]

    init() {
        syncEventTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification
            )
            for await notification in notifications {
                self?.handleEvent(notification)
            }
        }

        remoteChangeTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSPersistentStoreRemoteChange
            )
            for await _ in notifications {
                print("[CloudKit Debug] >>> NSPersistentStoreRemoteChange FIRED <<<")
                self?.handleRemoteStoreChange()
            }
        }

        print("[CloudKit Sync] Monitor started")
    }

    /// Call after ModelContainer is available to enable attribute-level debug logging.
    func startRemoteChangeMonitoring(container: ModelContainer) {
        self.modelContainer = container
        print("[CloudKit Sync] Remote change monitoring started")
        checkForChanges(eventType: "Init")
    }

    deinit {
        syncEventTask?.cancel()
        remoteChangeTask?.cancel()
    }

    // MARK: - Remote Store Change

    @MainActor
    private func handleRemoteStoreChange() {
        remoteChangeCount += 1
        print("[CloudKit Debug] remoteChangeCount incremented to \(remoteChangeCount)")
        checkForChanges(eventType: "RemoteChange")
    }

    /// Increments on each NSPersistentStoreRemoteChange - the proper signal for data availability.
    private(set) var remoteChangeCount: Int = 0

    // MARK: - Change Detection

    @MainActor
    private func checkForChanges(eventType: String) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<LocalTask>())
            var newSnapshot: [String: String] = [:]
            for task in tasks {
                let attrs = "imp=\(task.importance.map(String.init) ?? "nil") urg=\(task.urgency ?? "nil") dur=\(task.estimatedDuration.map(String.init) ?? "nil") type=\(task.taskType) nextUp=\(task.isNextUp) done=\(task.isCompleted)"
                newSnapshot[task.title] = attrs
            }

            if lastSnapshot.isEmpty {
                lastSnapshot = newSnapshot
                print("[CloudKit Sync] Snapshot initialized: \(tasks.count) tasks")
                return
            }

            var changes: [String] = []
            for (title, attrs) in newSnapshot {
                if let oldAttrs = lastSnapshot[title] {
                    if attrs != oldAttrs {
                        changes.append("[CloudKit Sync] CHANGED \"\(title)\": \(oldAttrs) -> \(attrs)")
                    }
                } else {
                    changes.append("[CloudKit Sync] NEW \"\(title)\": \(attrs)")
                }
            }
            for title in lastSnapshot.keys where newSnapshot[title] == nil {
                changes.append("[CloudKit Sync] DELETED \"\(title)\"")
            }

            if changes.isEmpty {
                print("[CloudKit Sync] \(eventType) OK - no changes detected")
            } else {
                print("[CloudKit Sync] \(eventType) - \(changes.count) change(s):")
                for change in changes {
                    print(change)
                }
            }

            lastSnapshot = newSnapshot
        } catch {
            print("[CloudKit Sync] Failed to check changes: \(error)")
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }

        let newState: SyncState
        if event.endDate == nil {
            newState = .inProgress(started: event.startDate)
        } else if event.succeeded {
            newState = .succeeded(started: event.startDate, ended: event.endDate!)
        } else {
            newState = .failed(
                started: event.startDate,
                ended: event.endDate!,
                error: event.error?.localizedDescription ?? "Unknown error"
            )
        }

        let typeLabel: String
        switch event.type {
        case .setup:
            setupState = newState
            typeLabel = "Setup"
        case .import:
            importState = newState
            typeLabel = "Import"
        case .export:
            exportState = newState
            typeLabel = "Export"
        @unknown default:
            typeLabel = "Unknown"
        }

        // Debug logging
        let statusLabel: String
        switch newState {
        case .inProgress: statusLabel = "STARTED"
        case .succeeded: statusLabel = "OK"
        case .failed(_, _, let err): statusLabel = "FAILED: \(err)"
        case .notStarted: statusLabel = "not started"
        }
        print("[CloudKit Sync] \(typeLabel) \(statusLabel)")

        if case .succeeded = newState {
            if event.type == .import {
                importSuccessCount += 1
                print("[CloudKit Debug] importSuccessCount incremented to \(importSuccessCount)")
                // Check for changes after delay - Core Data needs time to merge
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    checkForChanges(eventType: "Import (delayed)")
                }
            } else {
                checkForChanges(eventType: typeLabel)
            }
        }
    }

    // MARK: - Manual Sync Trigger

    /// Triggers a CloudKit sync cycle by saving the context (forces export, usually triggers import too).
    func triggerSync() {
        guard let container = modelContainer else {
            print("[CloudKit Sync] Cannot trigger sync - no ModelContainer")
            return
        }
        do {
            try container.mainContext.save()
            print("[CloudKit Sync] Manual sync triggered")
        } catch {
            print("[CloudKit Sync] Manual sync trigger failed: \(error)")
        }
    }

    // MARK: - Test Support

    /// Simulate a sync event for unit testing (no real CloudKit needed).
    func simulateEvent(type: SyncEventType, started: Date, ended: Date?, succeeded: Bool, error: Error?) {
        let newState: SyncState
        if ended == nil {
            newState = .inProgress(started: started)
        } else if succeeded {
            newState = .succeeded(started: started, ended: ended!)
        } else {
            newState = .failed(
                started: started,
                ended: ended!,
                error: error?.localizedDescription ?? "Unknown error"
            )
        }

        switch type {
        case .setup:  setupState = newState
        case .import: importState = newState
        case .export: exportState = newState
        }
    }
}
