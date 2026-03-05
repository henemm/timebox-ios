#!/usr/bin/env swift
//  GenerateIcon.swift — FocusBlox icon for iOS 26 Liquid Glass
//  V10b design: dark bg + cyan block (background) + white rings + dot (foreground)
//  Two separate layers for Liquid Glass depth effect

import Cocoa

let SIZE = 1024
let S = CGFloat(SIZE)
let cx = S / 2
let cy = S / 2
let globalScale: CGFloat = 1.18

// MARK: - Paths

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let baseDir = scriptDir.deletingLastPathComponent()
let previewDir = baseDir.appendingPathComponent("icon_previews")
let assetDir = baseDir.appendingPathComponent("AppIcon.icon/Assets")
try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: assetDir, withIntermediateDirectories: true)

// MARK: - Helpers

func makeContext(opaque: Bool = true) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let alphaInfo: CGImageAlphaInfo = opaque ? .premultipliedLast : .premultipliedLast
    let ctx = CGContext(data: nil, width: SIZE, height: SIZE,
                        bitsPerComponent: 8, bytesPerRow: SIZE * 4, space: cs,
                        bitmapInfo: alphaInfo.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    if !opaque {
        ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))
    }
    return ctx
}

func savePNG(_ img: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("  → \(url.lastPathComponent)")
}

func resizeSave(_ img: CGImage, to url: URL, size: Int) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: size * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: size, height: size))
    savePNG(ctx.makeImage()!, to: url)
}

// MARK: - Background layer (dark bg + cyan block)

func renderBackground() -> CGImage {
    let ctx = makeContext(opaque: true)

    // 1. Dark gradient background
    for y in 0..<SIZE {
        let t = CGFloat(y) / S
        ctx.setFillColor(red: (14 + t * 6)/255, green: (16 + t * 8)/255,
                         blue: (24 + t * 12)/255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: CGFloat(SIZE - 1 - y), width: S, height: 1))
    }

    // 2. Cyan block
    let bw = S * 0.58 * globalScale
    let bh = S * 0.44 * globalScale
    let bx = (S - bw) / 2
    let byFlipped = S - ((S - bh) / 2) - bh
    let br = min(bw, bh) * 0.20
    let blockRect = CGRect(x: bx, y: byFlipped, width: bw, height: bh)
    let blockPath = CGPath(roundedRect: blockRect, cornerWidth: br, cornerHeight: br, transform: nil)

    // Subtle glow
    for i in stride(from: 45, through: 1, by: -2) {
        let expand = CGFloat(i)
        let alpha = 0.006 * (1.0 - CGFloat(i) / 45.0)
        let r = blockRect.insetBy(dx: -expand, dy: -expand)
        let p = CGPath(roundedRect: r, cornerWidth: br + expand, cornerHeight: br + expand, transform: nil)
        ctx.setFillColor(red: 15/255, green: 195/255, blue: 225/255, alpha: alpha)
        ctx.addPath(p)
        ctx.fillPath()
    }

    // Block gradient
    ctx.saveGState()
    ctx.addPath(blockPath)
    ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(colorSpace: cs, components: [15/255, 215/255, 235/255, 1])!,
        CGColor(colorSpace: cs, components: [20/255, 165/255, 210/255, 1])!,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: cx, y: byFlipped + bh),
                           end: CGPoint(x: cx, y: byFlipped),
                           options: [])
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - Foreground layer (white rings + dot on transparent)

func renderForeground() -> CGImage {
    let ctx = makeContext(opaque: false)
    let cyCG = S / 2

    struct Ring {
        let radiusPct: CGFloat
        let thicknessPct: CGFloat
        let fillAlpha: CGFloat
    }

    let rings: [Ring] = [
        Ring(radiusPct: 0.40, thicknessPct: 0.070, fillAlpha: 1.00),   // outer
        Ring(radiusPct: 0.27, thicknessPct: 0.075, fillAlpha: 1.00),   // mid
        Ring(radiusPct: 0.15, thicknessPct: 0.070, fillAlpha: 1.00),   // inner
    ]

    for ring in rings {
        let radius = S * ring.radiusPct * globalScale
        let thickness = S * ring.thicknessPct * globalScale
        let innerR = radius - thickness

        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: cx - radius, y: cyCG - radius,
                                    width: radius * 2, height: radius * 2))
        path.addEllipse(in: CGRect(x: cx - innerR, y: cyCG - innerR,
                                    width: innerR * 2, height: innerR * 2))

        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: ring.fillAlpha)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    // Center dot
    let dotR = S * 0.025 * globalScale
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cyCG - dotR, width: dotR * 2, height: dotR * 2))

    return ctx.makeImage()!
}

// MARK: - Composite preview (for platform fallback icons)

func renderComposite() -> CGImage {
    let bg = renderBackground()
    let fg = renderForeground()
    let ctx = makeContext(opaque: true)
    ctx.draw(bg, in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.draw(fg, in: CGRect(x: 0, y: 0, width: S, height: S))
    return ctx.makeImage()!
}

// MARK: - Generate

print("Generating V10b icon (2-layer)...")

let background = renderBackground()
let foreground = renderForeground()
let composite = renderComposite()

print("\nLiquid Glass layers:")
savePNG(background, to: assetDir.appendingPathComponent("background.png"))
savePNG(foreground, to: assetDir.appendingPathComponent("foreground.png"))

print("\nPreview:")
savePNG(composite, to: previewDir.appendingPathComponent("V_final_composite.png"))

print("\nPlatform fallback icons:")
// Platform icons use composite (non-Liquid-Glass platforms)
savePNG(composite, to: baseDir.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))

let watchDir = baseDir.appendingPathComponent("FocusBloxWatch Watch App/Assets.xcassets/AppIcon.appiconset")
if FileManager.default.fileExists(atPath: watchDir.path) {
    savePNG(composite, to: watchDir.appendingPathComponent("AppIcon.png"))
}

let widgetDir = baseDir.appendingPathComponent("FocusBloxWidgets/Assets.xcassets/AppIcon.appiconset")
if FileManager.default.fileExists(atPath: widgetDir.path) {
    savePNG(composite, to: widgetDir.appendingPathComponent("AppIcon.png"))
}

let macDir = baseDir.appendingPathComponent("FocusBloxMac/Assets.xcassets/AppIcon.appiconset")
if FileManager.default.fileExists(atPath: macDir.path) {
    for (name, size) in [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ] as [(String, Int)] {
        resizeSave(composite, to: macDir.appendingPathComponent(name), size: size)
    }
}

print("\nDone!")
