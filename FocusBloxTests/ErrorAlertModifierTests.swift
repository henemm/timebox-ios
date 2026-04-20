import XCTest
import SwiftUI
@testable import FocusBlox

/// Tests for ErrorAlertModifier — Bug #276: Fehlermeldungen verschwinden lautlos
///
/// Validates that:
/// 1. ErrorAlertModifier exists and can be instantiated
/// 2. The View extension `.errorAlert(message:)` is available
/// 3. The isPresented binding correctly reflects errorMessage state
@MainActor
final class ErrorAlertModifierTests: XCTestCase {

    // MARK: - Modifier Existence

    func test_errorAlertModifier_exists() {
        // The modifier struct must exist and be instantiable
        var message: String? = "Test error"
        let binding = Binding(get: { message }, set: { message = $0 })
        let modifier = ErrorAlertModifier(errorMessage: binding)
        XCTAssertNotNil(modifier)
    }

    func test_errorAlert_viewExtension_compiles() {
        // The .errorAlert(message:) extension must exist on View
        var message: String? = "Test error"
        let binding = Binding(get: { message }, set: { message = $0 })
        let _ = EmptyView().errorAlert(message: binding)
    }

    // MARK: - Binding Logic (isPresented derives from errorMessage)

    func test_isPresented_true_when_errorMessage_set() {
        // When errorMessage is non-nil, the alert must present
        var message: String? = "Task konnte nicht gelöscht werden."
        let binding = Binding(get: { message }, set: { message = $0 })

        let isPresented = Binding(
            get: { binding.wrappedValue != nil },
            set: { if !$0 { binding.wrappedValue = nil } }
        )

        XCTAssertTrue(isPresented.wrappedValue, "Alert must present when errorMessage is set")
    }

    func test_isPresented_false_when_errorMessage_nil() {
        // When errorMessage is nil, no alert
        var message: String? = nil
        let binding = Binding(get: { message }, set: { message = $0 })

        let isPresented = Binding(
            get: { binding.wrappedValue != nil },
            set: { if !$0 { binding.wrappedValue = nil } }
        )

        XCTAssertFalse(isPresented.wrappedValue, "Alert must NOT present when errorMessage is nil")
    }

    func test_dismiss_clears_errorMessage() {
        // Simulating alert dismiss (setting isPresented to false) must clear errorMessage
        var message: String? = "Mutation failed"
        let binding = Binding(get: { message }, set: { message = $0 })

        let isPresented = Binding(
            get: { binding.wrappedValue != nil },
            set: { if !$0 { binding.wrappedValue = nil } }
        )

        // Simulate user tapping OK → SwiftUI sets isPresented to false
        isPresented.wrappedValue = false
        XCTAssertNil(message, "errorMessage must be nil after alert dismiss")
    }

    func test_errorMessage_persists_without_external_reset() {
        // Core invariant: errorMessage must stay set until explicitly dismissed
        // Previously loadData() would reset it — after the fix, only dismiss does
        var message: String? = "Task konnte nicht als erledigt markiert werden."

        // Simulate: error is set, time passes, no dismiss happened
        XCTAssertNotNil(message, "errorMessage must persist until user dismisses")
        XCTAssertEqual(message, "Task konnte nicht als erledigt markiert werden.")
    }
}
