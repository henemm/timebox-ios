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

    /// Verhalten: Aeusserer Ring hat hoehere Alpha als innerer Kern (wie im App-Icon: aussen hell, innen dunkler)
    /// Bricht wenn: Alle Kreise mit gleicher Alpha gezeichnet werden oder Gradient umgekehrt
    func test_makeMenuBarIcon_hasAlphaGradient() {
        // Groesseres Image fuer zuverlaessigere Pixel-Analyse
        let size = NSSize(width: 100, height: 100)
        let image = MenuBarController.makeMenuBarIcon(size: size)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Konnte Bitmap-Representation nicht erzeugen")
            return
        }

        // Mittelpunkt: niedrigere Alpha (innerer Kern, dunkler)
        let centerX = bitmap.pixelsWide / 2
        let centerY = bitmap.pixelsHigh / 2
        let centerColor = bitmap.colorAt(x: centerX, y: centerY)
        let centerAlpha = centerColor?.alphaComponent ?? 0

        // Rand: hohe Alpha (aeusserer Ring, hellster)
        // Punkt bei ~92% des Radius (innerhalb des aeusseren Rings)
        let edgeX = Int(Double(bitmap.pixelsWide) * 0.92)
        let edgeY = bitmap.pixelsHigh / 2
        let edgeColor = bitmap.colorAt(x: edgeX, y: edgeY)
        let edgeAlpha = edgeColor?.alphaComponent ?? 0

        XCTAssertGreaterThan(edgeAlpha, 0.8, "Aeusserer Ring muss hohe Alpha haben (erwartet >0.8, bekommen \(edgeAlpha))")
        XCTAssertLessThan(centerAlpha, 0.65, "Kern muss niedrigere Alpha als Rand haben (erwartet <0.65, bekommen \(centerAlpha))")
        XCTAssertGreaterThan(edgeAlpha, centerAlpha, "Rand-Alpha (\(edgeAlpha)) muss groesser sein als Kern-Alpha (\(centerAlpha))")
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

        // Punkt bei ~85% des Bitmap-Breite: Luecke zwischen aeusserem und mittlerem Ring
        // (bei @2x Retina: Luecke in Points bei ~70% des Radius, in Pixel bei ~85%)
        let gapX = Int(Double(bitmap.pixelsWide) * 0.85)
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
