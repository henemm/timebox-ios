#!/usr/bin/env swift
//  CompareIconVariants.swift — V4: Test .icon format WITHOUT glass:true
//  White block (BG) + Cyan rings (FG), no glass effect
//  Compare: ictool Light, Dark, Tinted renditions

import Cocoa

let SIZE = 1024
let S = CGFloat(SIZE)
let cx = S / 2
let cy = S / 2
let globalScale: CGFloat = 1.18

// Vibrant cyan
let cR: CGFloat = 0/255
let cG: CGFloat = 200/255
let cB: CGFloat = 255/255

// MARK: - Paths

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let baseDir = scriptDir.deletingLastPathComponent()
let previewDir = baseDir.appendingPathComponent("icon_previews/variants_v4")
let iconDir = baseDir.appendingPathComponent("AppIcon.icon")
let assetDir = iconDir.appendingPathComponent("Assets")
try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)

// MARK: - Helpers

func makeContext(opaque: Bool = true) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: SIZE, height: SIZE,
                        bitsPerComponent: 8, bytesPerRow: SIZE * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    if !opaque { ctx.clear(CGRect(x: 0, y: 0, width: S, height: S)) }
    return ctx
}

func savePNG(_ img: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Background: dark bg + white block

func renderBackground() -> CGImage {
    let ctx = makeContext(opaque: true)

    // Dark gradient
    for y in 0..<SIZE {
        let t = CGFloat(y) / S
        ctx.setFillColor(red: (14 + t * 6)/255, green: (16 + t * 8)/255,
                         blue: (24 + t * 12)/255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: CGFloat(SIZE - 1 - y), width: S, height: 1))
    }

    // White block
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
        let alpha = 0.008 * (1.0 - CGFloat(i) / 45.0)
        let r = blockRect.insetBy(dx: -expand, dy: -expand)
        let p = CGPath(roundedRect: r, cornerWidth: br + expand, cornerHeight: br + expand, transform: nil)
        ctx.setFillColor(red: 0.6, green: 0.9, blue: 1.0, alpha: alpha)
        ctx.addPath(p)
        ctx.fillPath()
    }

    // Block gradient (pure white → cool white)
    ctx.saveGState()
    ctx.addPath(blockPath)
    ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 1])!,
        CGColor(colorSpace: cs, components: [0.92, 0.94, 0.96, 1])!,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: cx, y: byFlipped + bh),
                           end: CGPoint(x: cx, y: byFlipped),
                           options: [])
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - Foreground: cyan rings + dot (transparent bg)
// Variant 07: normal V10b thickness + opacity gradient

func renderForeground() -> CGImage {
    let ctx = makeContext(opaque: false)
    let cyCG = S / 2

    struct Ring {
        let radiusPct: CGFloat
        let thicknessPct: CGFloat
        let alpha: CGFloat
    }

    let rings: [Ring] = [
        Ring(radiusPct: 0.40, thicknessPct: 0.070, alpha: 0.65),  // outer — most transparent
        Ring(radiusPct: 0.27, thicknessPct: 0.075, alpha: 0.80),  // mid
        Ring(radiusPct: 0.15, thicknessPct: 0.070, alpha: 1.00),  // inner — fully opaque
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
        ctx.setFillColor(red: cR, green: cG, blue: cB, alpha: ring.alpha)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    // Center dot
    let dotR = S * 0.025 * globalScale
    ctx.setFillColor(red: cR, green: cG, blue: cB, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cyCG - dotR, width: dotR * 2, height: dotR * 2))

    return ctx.makeImage()!
}

// MARK: - Composite (flat reference)

func renderComposite(bg: CGImage, fg: CGImage) -> CGImage {
    let ctx = makeContext(opaque: true)
    ctx.draw(bg, in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.draw(fg, in: CGRect(x: 0, y: 0, width: S, height: S))
    return ctx.makeImage()!
}

// MARK: - icon.json variants

func writeIconJSON(withGlass: Bool) {
    let glassLine = withGlass ? "\"glass\" : true,\n            " : ""
    let json = """
    {
      "fill" : "system-light",
      "groups" : [
        {
          "layers" : [
            {
              "image-name" : "background.png",
              "name" : "Background"
            }
          ]
        },
        {
          "layers" : [
            {
              \(glassLine)"image-name" : "foreground.png",
              "name" : "Rings"
            }
          ]
        }
      ],
      "supported-platforms" : {
        "circles" : [
          "watchOS"
        ],
        "squares" : "shared"
      }
    }
    """
    try! json.data(using: .utf8)!.write(to: iconDir.appendingPathComponent("icon.json"))
}

// MARK: - ictool

func runIctool(outputName: String, rendition: String, tintColor: String? = nil, tintStrength: String? = nil) -> Bool {
    let ictoolPath = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
    let outputPath = previewDir.appendingPathComponent(outputName).path

    var args = [
        iconDir.path,
        "--export-image",
        "--output-file", outputPath,
        "--platform", "iOS",
        "--rendition", rendition,
        "--width", "512",
        "--height", "512",
        "--scale", "2"
    ]
    if let tc = tintColor { args += ["--tint-color", tc] }
    if let ts = tintStrength { args += ["--tint-strength", ts] }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: ictoolPath)
    process.arguments = args
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch { return false }
}

// MARK: - Main

print("=== V4: .icon format comparison (with glass vs without glass) ===\n")

// Backup
let origBG = try! Data(contentsOf: assetDir.appendingPathComponent("background.png"))
let origFG = try! Data(contentsOf: assetDir.appendingPathComponent("foreground.png"))
let origJSON = try! Data(contentsOf: iconDir.appendingPathComponent("icon.json"))

// Generate layers
let bg = renderBackground()
let fg = renderForeground()
let composite = renderComposite(bg: bg, fg: fg)

// Save layers
savePNG(bg, to: assetDir.appendingPathComponent("background.png"))
savePNG(fg, to: assetDir.appendingPathComponent("foreground.png"))

// Flat reference
savePNG(composite, to: previewDir.appendingPathComponent("00_flat_reference.png"))
print("  flat reference saved\n")

// --- Test A: WITHOUT glass:true ---
print("[A] Without glass:true (recommended)")
writeIconJSON(withGlass: false)

if runIctool(outputName: "A1_no-glass_light.png", rendition: "Default") {
    print("  light saved")
}
if runIctool(outputName: "A2_no-glass_dark.png", rendition: "TintedDark", tintColor: "0.55", tintStrength: "0.6") {
    print("  dark saved")
}
if runIctool(outputName: "A3_no-glass_tinted-blue.png", rendition: "Tinted", tintColor: "0.6", tintStrength: "0.7") {
    print("  tinted blue saved")
}
if runIctool(outputName: "A4_no-glass_tinted-red.png", rendition: "Tinted", tintColor: "0.0", tintStrength: "0.7") {
    print("  tinted red saved")
}
if runIctool(outputName: "A5_no-glass_tinted-green.png", rendition: "Tinted", tintColor: "0.33", tintStrength: "0.7") {
    print("  tinted green saved")
}
if runIctool(outputName: "A6_no-glass_tinted-purple.png", rendition: "Tinted", tintColor: "0.8", tintStrength: "0.7") {
    print("  tinted purple saved")
}

// --- Test B: WITH glass:true ---
print("\n[B] With glass:true (current)")
writeIconJSON(withGlass: true)

if runIctool(outputName: "B1_glass_light.png", rendition: "Default") {
    print("  light saved")
}
if runIctool(outputName: "B2_glass_dark.png", rendition: "TintedDark", tintColor: "0.55", tintStrength: "0.6") {
    print("  dark saved")
}
if runIctool(outputName: "B3_glass_tinted-blue.png", rendition: "Tinted", tintColor: "0.6", tintStrength: "0.7") {
    print("  tinted blue saved")
}
if runIctool(outputName: "B4_glass_tinted-red.png", rendition: "Tinted", tintColor: "0.0", tintStrength: "0.7") {
    print("  tinted red saved")
}
if runIctool(outputName: "B5_glass_tinted-green.png", rendition: "Tinted", tintColor: "0.33", tintStrength: "0.7") {
    print("  tinted green saved")
}
if runIctool(outputName: "B6_glass_tinted-purple.png", rendition: "Tinted", tintColor: "0.8", tintStrength: "0.7") {
    print("  tinted purple saved")
}

// Restore
try! origBG.write(to: assetDir.appendingPathComponent("background.png"))
try! origFG.write(to: assetDir.appendingPathComponent("foreground.png"))
try! origJSON.write(to: iconDir.appendingPathComponent("icon.json"))
print("\nOriginal files restored.")

print("\n=== Done! ===")
print("Previews in: icon_previews/variants_v4/")
print("\nA = ohne Glass (Empfehlung)")
print("B = mit Glass (aktuell)")
print("Renditions: light, dark, tinted-blue, tinted-red, tinted-green, tinted-purple")
