import XCTest
import SwiftUI
@testable import FocusBlox

final class LiquidGlassIconTests: XCTestCase {

    func testLiquidGlassIconExists() {
        // LiquidGlassIcon should be a SwiftUI View
        let icon = LiquidGlassIcon()
        XCTAssertNotNil(icon.body)
    }

    func testLiquidGlassIconAcceptsCustomColors() {
        let icon = LiquidGlassIcon(
            cyanColor: .cyan,
            baseColor: .white,
            highlightColor: .white
        )
        XCTAssertNotNil(icon.body)
    }

    func testFocusBloxIconAliasWorks() {
        // FocusBloxIcon should be a typealias for LiquidGlassIcon
        let icon: FocusBloxIcon = LiquidGlassIcon()
        XCTAssertNotNil(icon.body)
    }
}
