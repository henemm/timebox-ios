import Foundation

extension Array where Element == LocalTask {
    /// Filter analog zu LocalTaskSource.fetchIncompleteTasks() (Sources/Services/TaskSources/LocalTaskSource.swift Zeile 45).
    /// Schliesst Tasks aus, die im Hauptfenster-Backlog ebenfalls nicht erscheinen.
    /// MUSS zur Laufzeit (Post-Fetch) angewendet werden, weil isVisibleInBacklog
    /// eine Computed Property ist und nicht im SwiftData #Predicate verwendbar.
    func filteredForMenuBarPopover() -> [LocalTask] {
        self.filter {
            $0.isVisibleInBacklog
            && $0.lifecycleStatus != "raw"
            && $0.assignedFocusBlockID == nil
            && $0.blockerTaskID == nil
        }
    }
}
