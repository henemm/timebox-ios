import Foundation
import SwiftData

/// Handles the shake-to-undo flow with a confirmation dialog.
/// Bug #225: Shake should ask before undoing, not execute immediately.
@MainActor
final class ShakeUndoHandler: ObservableObject {
    @Published var showUndoConfirmation = false
    @Published var showUndoAlert = false
    @Published var undoResultMessage = ""

    /// Called by .onShake — shows confirmation dialog instead of executing undo.
    func requestShakeUndo() {
        guard TaskCompletionUndoService.canUndo else {
            undoResultMessage = "Nichts zum Rückgängigmachen"
            showUndoAlert = true
            return
        }
        showUndoConfirmation = true
    }

    /// Called when user confirms the undo in the dialog.
    func confirmShakeUndo(in modelContext: ModelContext) {
        showUndoConfirmation = false
        do {
            if let title = try TaskCompletionUndoService.undo(in: modelContext) {
                undoResultMessage = "\(title) wiederhergestellt"
            }
        } catch {
            undoResultMessage = "Fehler: \(error.localizedDescription)"
        }
        showUndoAlert = true
    }

    /// Called when user cancels the undo dialog.
    func cancelShakeUndo() {
        showUndoConfirmation = false
    }
}
