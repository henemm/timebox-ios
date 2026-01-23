//
//  FocusBloxRebrandTests.swift
//  TimeBoxTests
//
//  Created by Claude on 2026-01-23.
//

import XCTest
@testable import FocusBlox

/// Unit tests for FocusBlox rebrand
/// Verifies that app branding constants are updated
final class FocusBloxRebrandTests: XCTestCase {

    /// Test that the app has FocusBlox branding configured
    /// EXPECTED TO FAIL in RED phase: App still uses TimeBox branding
    func testAppBrandingIsFocusBlox() throws {
        // Check that the app's display name is FocusBlox
        // This is read from Info.plist at runtime
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String

        XCTAssertEqual(displayName, "FocusBlox", "App display name should be 'FocusBlox'")
    }

    /// Test that URL schemes include focusblox
    /// EXPECTED TO FAIL in RED phase: Only timebox:// is registered
    func testFocusBloxURLSchemeRegistered() throws {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
              let firstType = urlTypes.first,
              let schemes = firstType["CFBundleURLSchemes"] as? [String] else {
            XCTFail("No URL schemes found in Info.plist")
            return
        }

        XCTAssertTrue(schemes.contains("focusblox"), "URL schemes should include 'focusblox'")
    }
}
