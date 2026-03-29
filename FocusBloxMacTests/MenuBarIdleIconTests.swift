//
//  MenuBarIdleIconTests.swift
//  FocusBloxMacTests
//
//  Tests for menu bar idle icon: programmatic concentric circles as template image
//

import XCTest
@testable import FocusBloxMac

final class MenuBarIdleIconTests: XCTestCase {

    // MARK: - Signatur & Grundeigenschaften

    /// Verhalten: makeMenuBarIcon(size:) erzeugt Image in gewuenschter Groesse OHNE Bitmap-Input
    /// Bricht wenn: Signatur noch (from:size:) erwartet oder Groesse falsch gesetzt
    func test_makeMenuBarIcon_resizesToTargetSize() {
        let result = MenuBarController.makeMenuBarIcon(size: NSSize(width: 18, height: 18))
        XCTAssertEqual(result.size.width, 18, accuracy: 0.1)
        XCTAssertEqual(result.size.height, 18, accuracy: 0.1)
    }

    /// Verhalten: makeMenuBarIcon erzeugt Template-Image (System passt Farbe an Dark/Light Mode an)
    /// Bricht wenn: isTemplate = true fehlt in makeMenuBarIcon
    func test_makeMenuBarIcon_isTemplate() {
        let result = MenuBarController.makeMenuBarIcon(size: NSSize(width: 18, height: 18))
        XCTAssertTrue(result.isTemplate, "Menu bar icon must be template for automatic Dark/Light Mode adaptation")
    }

    // MARK: - Alpha-Gradient (konzentrische Kreise)

    /// Verhalten: Aeusserer Rand hat niedrigere Alpha als innerer Kern (Tiefeneffekt)
    /// Bricht wenn: Alle Kreise mit gleicher Alpha gezeichnet werden oder Zeichenlogik fehlt
    func test_makeMenuBarIcon_hasAlphaGradient() {
        // Groesseres Image fuer zuverlaessigere Pixel-Analyse
        let size = NSSize(width: 100, height: 100)
        let image = MenuBarController.makeMenuBarIcon(size: size)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Konnte Bitmap-Representation nicht erzeugen")
            return
        }

        // Mittelpunkt: hohe Alpha (innerer Kern)
        let centerX = bitmap.pixelsWide / 2
        let centerY = bitmap.pixelsHigh / 2
        let centerColor = bitmap.colorAt(x: centerX, y: centerY)
        let centerAlpha = centerColor?.alphaComponent ?? 0

        // Rand: niedrige Alpha (aeusserer Ring)
        // Punkt bei ~90% des Radius (nah am Rand, aber innerhalb des aeusseren Kreises)
        let edgeX = Int(Double(bitmap.pixelsWide) * 0.92)
        let edgeY = bitmap.pixelsHigh / 2
        let edgeColor = bitmap.colorAt(x: edgeX, y: edgeY)
        let edgeAlpha = edgeColor?.alphaComponent ?? 0

        XCTAssertGreaterThan(centerAlpha, 0.8, "Kern muss hohe Alpha haben (erwartet >0.8, bekommen \(centerAlpha))")
        XCTAssertLessThan(edgeAlpha, 0.6, "Rand muss niedrigere Alpha als Kern haben (erwartet <0.6, bekommen \(edgeAlpha))")
        XCTAssertGreaterThan(centerAlpha, edgeAlpha, "Kern-Alpha (\(centerAlpha)) muss groesser sein als Rand-Alpha (\(edgeAlpha))")
    }

    /// Verhalten: Zwischen den Ringen muss eine transparente Luecke sein (nicht gefuellt)
    /// Bricht wenn: Ringe als gefuellte Scheiben statt stroke() gezeichnet werden (Luecke verschwindet)
    func test_makeMenuBarIcon_hasGapBetweenRings() {
        let size = NSSize(width: 100, height: 100)
        let image = MenuBarController.makeMenuBarIcon(size: size)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Konnte Bitmap-Representation nicht erzeugen")
            return
        }

        // Punkt bei ~65% des Radius: Luecke zwischen aeusserem Ring (endet bei ~82%) und mittlerem Ring (endet bei ~58%+9%)
        let gapX = Int(Double(bitmap.pixelsWide) * 0.65)
        let gapY = bitmap.pixelsHigh / 2
        let gapColor = bitmap.colorAt(x: gapX, y: gapY)
        let gapAlpha = gapColor?.alphaComponent ?? 1.0

        XCTAssertLessThan(gapAlpha, 0.1, "Luecke zwischen Ringen muss transparent sein (erwartet <0.1, bekommen \(gapAlpha))")
    }

    /// Verhalten: Ausserhalb des aeusseren Kreises ist das Image transparent
    /// Bricht wenn: Hintergrund nicht transparent oder Kreise ueber Bounds hinaus gezeichnet
    func test_makeMenuBarIcon_transparentOutsideCircle() {
        let size = NSSize(width: 100, height: 100)
        let image = MenuBarController.makeMenuBarIcon(size: size)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Konnte Bitmap-Representation nicht erzeugen")
            return
        }

        // Ecke (0,0) muss transparent sein — Kreise fuellen nur den ovalen Bereich
        let cornerColor = bitmap.colorAt(x: 0, y: 0)
        let cornerAlpha = cornerColor?.alphaComponent ?? 1.0
        XCTAssertLessThan(cornerAlpha, 0.05, "Ecke muss transparent sein (erwartet ~0, bekommen \(cornerAlpha))")
    }
}
