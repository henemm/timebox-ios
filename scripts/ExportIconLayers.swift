#!/usr/bin/env swift
//  ExportIconLayers.swift
//  Renders IconBackgroundLayer + IconForegroundLayer as separate PNGs
//  for the iOS 26 Liquid Glass layered icon system.
//
//  Background: opaque 1024x1024, no corner radius
//  Foreground: transparent 1024x1024, no corner radius
//
//  Usage: swift scripts/ExportIconLayers.swift

import SwiftUI
import AppKit

let SIZE: CGFloat = 1024

// MARK: - Colors

let focusCyan = Color(red: 0, green: 0.784, blue: 1.0)
let deepCyan = Color(red: 0, green: 0.60, blue: 0.80)

// MARK: - Proposal 1: "Bold Single Ring"
// Inspired by Healthy Habits: ONE thick closed ring + large center dot
// Clean, minimalist, maximum recognition

struct Proposal1_BG: View {
    var body: some View {
        ZStack {
            Color.white

            // One bold closed ring
            Circle()
                .stroke(focusCyan, style: StrokeStyle(lineWidth: SIZE * 0.16, lineCap: .round))
                .frame(width: SIZE * 0.58, height: SIZE * 0.58)

            // Large center dot
            Circle()
                .fill(focusCyan)
                .frame(width: SIZE * 0.22, height: SIZE * 0.22)
        }
        .frame(width: SIZE, height: SIZE)
    }
}

struct Proposal1_FG: View {
    var body: some View {
        // Ring shape for glass depth
        Circle()
            .stroke(Color.white, style: StrokeStyle(lineWidth: SIZE * 0.16, lineCap: .round))
            .frame(width: SIZE * 0.58, height: SIZE * 0.58)
            .frame(width: SIZE, height: SIZE)
    }
}

// MARK: - Proposal 2: "Two Rings + Dot"
// Two concentric rings with different thickness, gradient opacity
// More "FocusBlox" identity (multiple rings = focus zones)

struct Proposal2_BG: View {
    var body: some View {
        ZStack {
            Color.white

            // Outer ring (thicker, lighter)
            Circle()
                .stroke(focusCyan.opacity(0.50), style: StrokeStyle(lineWidth: SIZE * 0.10, lineCap: .round))
                .frame(width: SIZE * 0.72, height: SIZE * 0.72)

            // Inner ring (thinner, full opacity)
            Circle()
                .stroke(focusCyan, style: StrokeStyle(lineWidth: SIZE * 0.12, lineCap: .round))
                .frame(width: SIZE * 0.42, height: SIZE * 0.42)

            // Center dot (darker cyan)
            Circle()
                .fill(deepCyan)
                .frame(width: SIZE * 0.14, height: SIZE * 0.14)
        }
        .frame(width: SIZE, height: SIZE)
    }
}

struct Proposal2_FG: View {
    var body: some View {
        ZStack {
            // Inner ring for glass
            Circle()
                .stroke(Color.white, style: StrokeStyle(lineWidth: SIZE * 0.12, lineCap: .round))
                .frame(width: SIZE * 0.42, height: SIZE * 0.42)
            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: SIZE * 0.14, height: SIZE * 0.14)
        }
        .frame(width: SIZE, height: SIZE)
    }
}

// MARK: - Proposal 3: "Ring + Block"
// Bold ring with the "Blox" element visible — brand identity
// White block sits inside the ring, ring extends behind it

struct Proposal3_BG: View {
    var body: some View {
        ZStack {
            Color.white

            // Bold ring
            Circle()
                .stroke(focusCyan, style: StrokeStyle(lineWidth: SIZE * 0.13, lineCap: .round))
                .frame(width: SIZE * 0.62, height: SIZE * 0.62)

            // White block overlaying the ring
            RoundedRectangle(cornerRadius: SIZE * 0.06, style: .continuous)
                .fill(Color.white)
                .frame(width: SIZE * 0.44, height: SIZE * 0.34)

            // Smaller inner ring visible inside block
            Circle()
                .stroke(focusCyan, style: StrokeStyle(lineWidth: SIZE * 0.05, lineCap: .round))
                .frame(width: SIZE * 0.28, height: SIZE * 0.28)

            // Center dot
            Circle()
                .fill(focusCyan)
                .frame(width: SIZE * 0.10, height: SIZE * 0.10)
        }
        .frame(width: SIZE, height: SIZE)
    }
}

struct Proposal3_FG: View {
    var body: some View {
        ZStack {
            // Block shape for glass
            RoundedRectangle(cornerRadius: SIZE * 0.06, style: .continuous)
                .fill(Color.white)
                .frame(width: SIZE * 0.44, height: SIZE * 0.34)
        }
        .frame(width: SIZE, height: SIZE)
    }
}

// MARK: - Rendering

@MainActor
func renderToPNG<V: View>(_ view: V, opaque: Bool) -> Data? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    renderer.isOpaque = opaque

    guard let cgImage = renderer.cgImage else {
        print("ERROR: Failed to render image")
        return nil
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

func savePNG(_ data: Data, to path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("  -> \(url.lastPathComponent)")
}

func resizeAndSave(_ data: Data, to path: String, size: Int) {
    guard let src = NSImage(data: data) else { return }
    let dst = NSImage(size: NSSize(width: size, height: size))
    dst.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    src.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    dst.unlockFocus()
    guard let tiff = dst.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    savePNG(png, to: path)
}

// MARK: - Main

@MainActor
func main() {
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let baseDir = scriptDir.deletingLastPathComponent().path

print("=== Exporting Icon: Two Rings + Dot ===\n")

// Background: full design baked in (colors preserved through glass)
print("Background layer (opaque):")
guard let bgData = renderToPNG(Proposal2_BG(), opaque: true) else {
    print("FAILED"); exit(1)
}
savePNG(bgData, to: "\(baseDir)/AppIcon.icon/Assets/background.png")

// Foreground: glass shape for depth/parallax
print("\nForeground layer (transparent):")
guard let fgData = renderToPNG(Proposal2_FG(), opaque: false) else {
    print("FAILED"); exit(1)
}
savePNG(fgData, to: "\(baseDir)/AppIcon.icon/Assets/foreground.png")

// Composite fallback (flat, for non-layered platforms)
let compData = bgData // background IS the complete design

// iOS
print("\niOS icon:")
savePNG(compData, to: "\(baseDir)/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

// watchOS
let watchDir = "\(baseDir)/FocusBloxWatch Watch App/Assets.xcassets/AppIcon.appiconset"
if FileManager.default.fileExists(atPath: watchDir) {
    print("\nWatch icon:")
    savePNG(compData, to: "\(watchDir)/AppIcon.png")
}

// Widgets
let widgetDir = "\(baseDir)/FocusBloxWidgets/Assets.xcassets/AppIcon.appiconset"
if FileManager.default.fileExists(atPath: widgetDir) {
    print("\nWidget icon:")
    savePNG(compData, to: "\(widgetDir)/AppIcon.png")
}

// macOS (multiple sizes)
let macDir = "\(baseDir)/FocusBloxMac/Assets.xcassets/AppIcon.appiconset"
if FileManager.default.fileExists(atPath: macDir) {
    print("\nmacOS icons:")
    for (name, size) in [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ] as [(String, Int)] {
        resizeAndSave(compData, to: "\(macDir)/\(name)", size: size)
    }
}

// Previews
print("\nPreviews:")
savePNG(bgData, to: "\(baseDir)/icon_previews/layer_background.png")
savePNG(fgData, to: "\(baseDir)/icon_previews/layer_foreground.png")
savePNG(compData, to: "\(baseDir)/icon_previews/layer_composite.png")

print("\n=== Done! ===")
print("iOS 26 layered icon: AppIcon.icon/Assets/")
print("Fallbacks: iOS, watchOS, Widgets, macOS")
}

MainActor.assumeIsolated {
    main()
}
