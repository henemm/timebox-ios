import Testing
import SwiftUI
@testable import FocusBlox

/// Regression tests for shared Settings components (BACKLOG-011).
/// Verifies that setMembershipBinding behaves identically to the
/// previously duplicated calendarBinding/reminderListBinding in both Settings views.
struct SettingsComponentsTests {

    // MARK: - setMembershipBinding: get

    @Test func binding_get_returnsTrueWhenIdInSet() {
        var set: Set<String> = ["cal1", "cal2"]
        let binding = setMembershipBinding(for: "cal1", in: Binding(get: { set }, set: { set = $0 }))
        #expect(binding.wrappedValue == true)
    }

    @Test func binding_get_returnsFalseWhenIdNotInSet() {
        var set: Set<String> = ["cal1", "cal2"]
        let binding = setMembershipBinding(for: "cal3", in: Binding(get: { set }, set: { set = $0 }))
        #expect(binding.wrappedValue == false)
    }

    @Test func binding_get_returnsFalseForEmptySet() {
        var set: Set<String> = []
        let binding = setMembershipBinding(for: "any", in: Binding(get: { set }, set: { set = $0 }))
        #expect(binding.wrappedValue == false)
    }

    // MARK: - setMembershipBinding: set

    @Test func binding_setTrue_insertsIdIntoSet() {
        var set: Set<String> = ["cal1"]
        let binding = setMembershipBinding(for: "cal2", in: Binding(get: { set }, set: { set = $0 }))
        binding.wrappedValue = true
        #expect(set.contains("cal2"))
        #expect(set.count == 2)
    }

    @Test func binding_setFalse_removesIdFromSet() {
        var set: Set<String> = ["cal1", "cal2"]
        let binding = setMembershipBinding(for: "cal1", in: Binding(get: { set }, set: { set = $0 }))
        binding.wrappedValue = false
        #expect(!set.contains("cal1"))
        #expect(set.count == 1)
    }

    @Test func binding_setTrue_idempotentWhenAlreadyPresent() {
        var set: Set<String> = ["cal1", "cal2"]
        let binding = setMembershipBinding(for: "cal1", in: Binding(get: { set }, set: { set = $0 }))
        binding.wrappedValue = true
        #expect(set.contains("cal1"))
        #expect(set.count == 2)
    }

    @Test func binding_setFalse_idempotentWhenNotPresent() {
        var set: Set<String> = ["cal1"]
        let binding = setMembershipBinding(for: "cal2", in: Binding(get: { set }, set: { set = $0 }))
        binding.wrappedValue = false
        #expect(!set.contains("cal2"))
        #expect(set.count == 1)
    }

    // MARK: - Multiple bindings on same set

    @Test func multipleBindings_operateIndependently() {
        var set: Set<String> = []
        let b1 = setMembershipBinding(for: "a", in: Binding(get: { set }, set: { set = $0 }))
        let b2 = setMembershipBinding(for: "b", in: Binding(get: { set }, set: { set = $0 }))

        b1.wrappedValue = true
        #expect(set == ["a"])

        b2.wrappedValue = true
        #expect(set == ["a", "b"])

        b1.wrappedValue = false
        #expect(set == ["b"])
    }
}
