import Testing
import SwiftUI
@testable import FocusBlox

/// Regression tests for TaskCategory enum properties.
/// Verifies that all category display values remain correct after
/// replacing hardcoded switches with TaskCategory delegation (BACKLOG-008).
struct TaskCategoryTests {

    // MARK: - Raw Value Resolution

    @Test func allRawValues_resolveCorrectly() {
        #expect(TaskCategory(rawValue: "income") == .income)
        #expect(TaskCategory(rawValue: "maintenance") == .essentials)
        #expect(TaskCategory(rawValue: "recharge") == .selfCare)
        #expect(TaskCategory(rawValue: "learning") == .learn)
        #expect(TaskCategory(rawValue: "giving_back") == .social)
    }

    @Test func unknownRawValue_returnsNil() {
        #expect(TaskCategory(rawValue: "unknown") == nil)
        #expect(TaskCategory(rawValue: "") == nil)
        #expect(TaskCategory(rawValue: "deep_work") == nil)
    }

    // MARK: - Color Property

    @Test func color_returnsExpectedValues() {
        #expect(TaskCategory.income.color == .green)
        #expect(TaskCategory.essentials.color == .orange)
        #expect(TaskCategory.selfCare.color == .cyan)
        #expect(TaskCategory.learn.color == .purple)
        #expect(TaskCategory.social.color == .pink)
    }

    // MARK: - Icon Property

    @Test func icon_returnsExpectedValues() {
        #expect(TaskCategory.income.icon == "dollarsign.circle")
        #expect(TaskCategory.essentials.icon == "wrench.and.screwdriver.fill")
        #expect(TaskCategory.selfCare.icon == "heart.circle")
        #expect(TaskCategory.learn.icon == "book")
        #expect(TaskCategory.social.icon == "person.2")
    }

    // MARK: - Display Name Property

    @Test func displayName_returnsExpectedValues() {
        #expect(TaskCategory.income.displayName == "Earn")
        #expect(TaskCategory.essentials.displayName == "Essentials")
        #expect(TaskCategory.selfCare.displayName == "Self Care")
        #expect(TaskCategory.learn.displayName == "Learn")
        #expect(TaskCategory.social.displayName == "Social")
    }

    // MARK: - Localized Name Property

    @Test func localizedName_returnsGermanLabels() {
        #expect(TaskCategory.income.localizedName == "Geld")
        #expect(TaskCategory.essentials.localizedName == "Pflege")
        #expect(TaskCategory.selfCare.localizedName == "Energie")
        #expect(TaskCategory.learn.localizedName == "Lernen")
        #expect(TaskCategory.social.localizedName == "Geben")
    }

    // MARK: - CaseIterable

    @Test func allCases_containsFiveCategories() {
        #expect(TaskCategory.allCases.count == 5)
    }
}
