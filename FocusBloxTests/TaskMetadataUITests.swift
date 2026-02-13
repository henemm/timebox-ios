import Testing
import SwiftUI
@testable import FocusBlox

/// Regression tests for ImportanceUI and UrgencyUI helpers.
/// Verifies that shared helpers return the same values as the
/// previously hardcoded switches in 5 view files (BACKLOG-009).
struct TaskMetadataUITests {

    // MARK: - ImportanceUI Icon

    @Test func importanceIcon_allLevels() {
        #expect(ImportanceUI.icon(for: 3) == "exclamationmark.3")
        #expect(ImportanceUI.icon(for: 2) == "exclamationmark.2")
        #expect(ImportanceUI.icon(for: 1) == "exclamationmark")
    }

    @Test func importanceIcon_nilAndZero_returnQuestionmark() {
        #expect(ImportanceUI.icon(for: nil) == "questionmark")
        #expect(ImportanceUI.icon(for: 0) == "questionmark")
    }

    // MARK: - ImportanceUI Color

    @Test func importanceColor_allLevels() {
        #expect(ImportanceUI.color(for: 3) == .red)
        #expect(ImportanceUI.color(for: 2) == .yellow)
        #expect(ImportanceUI.color(for: 1) == .blue)
    }

    @Test func importanceColor_nilAndZero_returnGray() {
        #expect(ImportanceUI.color(for: nil) == .gray)
        #expect(ImportanceUI.color(for: 0) == .gray)
    }

    // MARK: - ImportanceUI Label

    @Test func importanceLabel_allLevels() {
        #expect(ImportanceUI.label(for: 3) == "Hoch")
        #expect(ImportanceUI.label(for: 2) == "Mittel")
        #expect(ImportanceUI.label(for: 1) == "Niedrig")
    }

    @Test func importanceLabel_nilAndZero_returnDefault() {
        #expect(ImportanceUI.label(for: nil) == "Nicht gesetzt")
        #expect(ImportanceUI.label(for: 0) == "Nicht gesetzt")
    }

    // MARK: - UrgencyUI Icon

    @Test func urgencyIcon_allValues() {
        #expect(UrgencyUI.icon(for: "urgent") == "flame.fill")
        #expect(UrgencyUI.icon(for: "not_urgent") == "flame")
    }

    @Test func urgencyIcon_nilAndDefault_returnQuestionmark() {
        #expect(UrgencyUI.icon(for: nil) == "questionmark")
        #expect(UrgencyUI.icon(for: "unknown") == "questionmark")
    }

    // MARK: - UrgencyUI Color

    @Test func urgencyColor_allValues() {
        #expect(UrgencyUI.color(for: "urgent") == .orange)
        #expect(UrgencyUI.color(for: "not_urgent") == .gray)
    }

    @Test func urgencyColor_nilAndDefault_returnGray() {
        #expect(UrgencyUI.color(for: nil) == .gray)
        #expect(UrgencyUI.color(for: "unknown") == .gray)
    }

    // MARK: - UrgencyUI Label

    @Test func urgencyLabel_allValues() {
        #expect(UrgencyUI.label(for: "urgent") == "Dringend")
        #expect(UrgencyUI.label(for: "not_urgent") == "Nicht dringend")
    }

    @Test func urgencyLabel_nilAndDefault_returnDefault() {
        #expect(UrgencyUI.label(for: nil) == "Nicht gesetzt")
        #expect(UrgencyUI.label(for: "unknown") == "Nicht gesetzt")
    }
}
