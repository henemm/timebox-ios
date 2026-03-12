//
//  MenuBarIdleIconTests.swift
//  FocusBloxMacTests
//
//  Tests for menu bar idle icon: app icon in grayscale at correct size
//

import XCTest
@testable import FocusBloxMac

final class MenuBarIdleIconTests: XCTestCase {

    /// Verhalten: makeMenuBarIcon skaliert auf gewuenschte Groesse
    /// Bricht wenn: Resize-Logik fehlt oder falsche Groesse
    func test_makeMenuBarIcon_resizesToTargetSize() {
        let source = NSImage(size: NSSize(width: 512, height: 512))
        let result = MenuBarController.makeMenuBarIcon(from: source, size: NSSize(width: 18, height: 18))
        XCTAssertEqual(result.size.width, 18, accuracy: 0.1)
        XCTAssertEqual(result.size.height, 18, accuracy: 0.1)
    }

    /// Verhalten: makeMenuBarIcon ist KEIN Template-Image (Graustufen statt Silhouette)
    /// Bricht wenn: isTemplate faelschlicherweise gesetzt wird
    func test_makeMenuBarIcon_isNotTemplate() {
        let source = NSImage(size: NSSize(width: 64, height: 64))
        let result = MenuBarController.makeMenuBarIcon(from: source, size: NSSize(width: 18, height: 18))
        XCTAssertFalse(result.isTemplate, "Grayscale icon must NOT be template (template = black square)")
    }
}
