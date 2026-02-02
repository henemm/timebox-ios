import XCTest
import SwiftUI
@testable import FocusBlox

/// Unit tests for DesignSystem design tokens
/// TDD RED: These tests verify the existence and correctness of design tokens
final class DesignSystemTests: XCTestCase {

    // MARK: - Color Tests

    func testAppBackgroundColorExists() {
        // Test that appBackground color is defined
        let color = DesignSystem.Colors.appBackground
        XCTAssertNotNil(color, "appBackground color should exist")
    }

    func testGoldAccentColorExists() {
        // Test that goldAccent color is defined
        let color = DesignSystem.Colors.goldAccent
        XCTAssertNotNil(color, "goldAccent color should exist")
    }

    func testAccentGlowExists() {
        // Test that accentGlow gradient is defined
        let gradient = DesignSystem.Colors.accentGlow
        XCTAssertNotNil(gradient, "accentGlow gradient should exist")
    }

    func testPrimaryTextColorExists() {
        // Test that primaryText color is defined
        let color = DesignSystem.Colors.primaryText
        XCTAssertNotNil(color, "primaryText color should exist")
    }

    func testSecondaryTextColorExists() {
        // Test that secondaryText color is defined
        let color = DesignSystem.Colors.secondaryText
        XCTAssertNotNil(color, "secondaryText color should exist")
    }

    // MARK: - Spacing Tests

    func testSpacingConstantsExist() {
        // Test that all spacing constants are defined
        XCTAssertEqual(DesignSystem.Spacing.cardPadding, 20, "cardPadding should be 20")
        XCTAssertEqual(DesignSystem.Spacing.listRowSpacing, 16, "listRowSpacing should be 16")
        XCTAssertEqual(DesignSystem.Spacing.iconSize, 28, "iconSize should be 28")
    }

    func testCornerRadiusConstantsExist() {
        // Test that corner radius is defined correctly
        XCTAssertEqual(DesignSystem.Spacing.cardCornerRadius, 24, "cardCornerRadius should be 24")
    }

    // MARK: - Typography Tests

    func testTypographyTokensExist() {
        // Test that typography tokens are defined
        let titleFont = DesignSystem.Typography.titleFont
        let bodyFont = DesignSystem.Typography.bodyFont
        let captionFont = DesignSystem.Typography.captionFont

        XCTAssertNotNil(titleFont, "titleFont should exist")
        XCTAssertNotNil(bodyFont, "bodyFont should exist")
        XCTAssertNotNil(captionFont, "captionFont should exist")
    }
}
