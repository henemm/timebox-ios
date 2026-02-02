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
        ZStack {
            // Linke Klammer [
            Path { path in
                let arm = width * 0.08
                let h = width * 0.22
                path.move(to: CGPoint(x: arm, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: arm, y: h))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: width * 0.035, lineCap: .round, lineJoin: .round))
            .offset(x: -width * 0.12, y: -width * 0.11)

            // Rechte Klammer ]
            Path { path in
                let arm = width * 0.08
                let h = width * 0.22
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: arm, y: 0))
                path.addLine(to: CGPoint(x: arm, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: width * 0.035, lineCap: .round, lineJoin: .round))
            .offset(x: width * 0.12, y: -width * 0.11)

            // Zen Dot
            Circle()
                .fill(Color.white)
                .frame(width: width * 0.07)
        }
    }
}

// MARK: - Render to PNG

@MainActor
func renderIconToPNG() {
    let size: CGFloat = 1024
    let icon = FocusBloxIcon()
        .frame(width: size, height: size)

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else {
        print("ERROR: Failed to render icon to CGImage")
        exit(1)
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("ERROR: Failed to convert to PNG")
        exit(1)
    }

    // Get script directory and navigate to AppIcon.icon/Assets
    let scriptPath = URL(fileURLWithPath: #file)
    let projectRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
    let foregroundPath = projectRoot.appendingPathComponent("AppIcon.icon/Assets/foreground.png")

    do {
        try pngData.write(to: foregroundPath)
        print("SUCCESS: Icon rendered to \(foregroundPath.path)")
    } catch {
        print("ERROR: Failed to write PNG: \(error)")
        exit(1)
    }
}

// Run on MainActor
Task { @MainActor in
    renderIconToPNG()
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
