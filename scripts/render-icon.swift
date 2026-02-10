#!/usr/bin/env swift
// Renders FocusBloxIcon SwiftUI view to PNG for Icon Composer
// Usage: swift render-icon.swift

import SwiftUI
import AppKit
import Foundation

// MARK: - Icon Components (Copy from FocusBloxIconLayers.swift)

struct FocusBloxIcon: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cornerRadius = width * 0.225

            ZStack {
                // LAYER 0: THE VOID (Hintergrund)
                Color(red: 0.08, green: 0.08, blue: 0.10)

                RadialGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.8
                )

                VStack(spacing: height * 0.06) {
                    // BLOCK 1 (Oben): Inaktives "Rauchglas"
                    GlassBlock(width: width * 0.6, height: height * 0.18, isActive: false)

                    // BLOCK 2 (Mitte): Aktives "Neon-Glas" (Der Fokus)
                    ZStack {
                        GlassBlock(width: width * 0.9, height: height * 0.38, isActive: true)
                        ViewfinderSymbol(width: width)
                            .shadow(color: Color.white.opacity(0.8), radius: width * 0.02)
                    }

                    // BLOCK 3 (Unten): Inaktives "Rauchglas"
                    GlassBlock(width: width * 0.6, height: height * 0.18, isActive: false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct GlassBlock: View {
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool

    var body: some View {
        let cornerRadius = width * (isActive ? 0.09 : 0.08)

        ZStack {
            // LAYER 1: SHADOW
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black)
                .blur(radius: isActive ? 15 : 5)
                .offset(y: isActive ? 10 : 5)
                .opacity(0.6)
                .frame(width: width * 0.9, height: height)

            // LAYER 2: BODY
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: isActive
                        ? [
                            Color(red: 0.1, green: 0.9, blue: 0.95).opacity(0.9),
                            Color(red: 0.0, green: 0.5, blue: 0.6).opacity(0.8)
                          ]
                        : [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                          ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)

            // LAYER 3: INNER GLOW
            if isActive {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.2))
                    .blur(radius: 10)
                    .padding(5)
            }

            // LAYER 4: SPECULAR HIGHLIGHT
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.9 : 0.4),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width, height: height)

            // LAYER 5: REFLECTION
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: width, height: height)
                .padding(1)
        }
    }
}

struct ViewfinderSymbol: View {
    let width: CGFloat

    var body: some View {
        let symbolWidth = width * 0.32
        let symbolHeight = width * 0.22
        let arm = width * 0.08
        let strokeWidth = width * 0.035

        return Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2
            let halfW = symbolWidth / 2
            let halfH = symbolHeight / 2

            // Linke Klammer [
            var leftBracket = Path()
            leftBracket.move(to: CGPoint(x: centerX - halfW + arm, y: centerY - halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW, y: centerY - halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW, y: centerY + halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW + arm, y: centerY + halfH))

            context.stroke(
                leftBracket,
                with: .color(.white),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Rechte Klammer ]
            var rightBracket = Path()
            rightBracket.move(to: CGPoint(x: centerX + halfW - arm, y: centerY - halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW, y: centerY - halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW, y: centerY + halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW - arm, y: centerY + halfH))

            context.stroke(
                rightBracket,
                with: .color(.white),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Zen-Punkt
            let dotSize = width * 0.07
            let dotRect = CGRect(
                x: centerX - dotSize / 2,
                y: centerY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))
        }
        .frame(width: width * 0.5, height: width * 0.4)
    }
}

// MARK: - Render to PNG

@MainActor
func renderIcon(size: CGFloat) -> Data? {
    let icon = FocusBloxIcon()
        .frame(width: size, height: size)

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else {
        print("ERROR: Failed to render icon at size \(Int(size))")
        return nil
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: .png, properties: [:])
}

@MainActor
func renderAllIcons() {
    let scriptPath = URL(fileURLWithPath: #file)
    let projectRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()

    // 1. Render for iOS Icon Composer (foreground.png) AND iOS Assets (AppIcon.png)
    if let pngData = renderIcon(size: 1024) {
        // Icon Composer foreground
        let foregroundPath = projectRoot.appendingPathComponent("AppIcon.icon/Assets/foreground.png")
        do {
            try pngData.write(to: foregroundPath)
            print("✓ iOS Icon Composer: foreground.png (1024x1024)")
        } catch {
            print("✗ Failed: foreground.png - \(error)")
        }

        // iOS Assets AppIcon.png
        let iOSIconPath = projectRoot.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        do {
            try pngData.write(to: iOSIconPath)
            print("✓ iOS Assets: AppIcon.png (1024x1024)")
        } catch {
            print("✗ Failed: AppIcon.png - \(error)")
        }
    }

    // 2. Render for macOS (all sizes)
    let macOSPath = projectRoot.appendingPathComponent("FocusBloxMac/Assets.xcassets/AppIcon.appiconset")

    // macOS icon sizes: base size -> @1x and @2x
    let macOSSizes: [(base: Int, scale: String, pixels: Int)] = [
        (16, "1x", 16),
        (16, "2x", 32),
        (32, "1x", 32),
        (32, "2x", 64),
        (128, "1x", 128),
        (128, "2x", 256),
        (256, "1x", 256),
        (256, "2x", 512),
        (512, "1x", 512),
        (512, "2x", 1024),
    ]

    for sizeInfo in macOSSizes {
        let filename = sizeInfo.scale == "1x"
            ? "icon_\(sizeInfo.base)x\(sizeInfo.base).png"
            : "icon_\(sizeInfo.base)x\(sizeInfo.base)@2x.png"
        let filePath = macOSPath.appendingPathComponent(filename)

        if let pngData = renderIcon(size: CGFloat(sizeInfo.pixels)) {
            do {
                try pngData.write(to: filePath)
                print("✓ macOS: \(filename) (\(sizeInfo.pixels)x\(sizeInfo.pixels))")
            } catch {
                print("✗ Failed: \(filename) - \(error)")
            }
        }
    }

    print("\n🎉 Icon generation complete!")
}

// Run on MainActor
Task { @MainActor in
    renderAllIcons()
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
