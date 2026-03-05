import SwiftUI

// MARK: - Adaptive Liquid Glass Colors

struct GlassColors {
    static var liquidCyan: Color {
        Color("LiquidCyan", bundle: .main)
    }

    static var glassPlate: Color {
        Color("GlassPlate", bundle: .main)
    }

    static var glassHighlight: Color {
        Color("GlassHighlight", bundle: .main)
    }
}

// MARK: - LAYER 1: Background (dark bg + white block)
// Exported as opaque, square image — OS applies corner radius

struct IconBackgroundLayer: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width

            ZStack {
                // Dark background
                LinearGradient(
                    colors: [
                        Color(red: 14/255, green: 16/255, blue: 24/255),
                        Color(red: 20/255, green: 24/255, blue: 36/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // White block (centered, rounded rectangle)
                RoundedRectangle(cornerRadius: s * 0.09, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(white: 0.93)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s * 0.68, height: s * 0.52)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - LAYER 2: Foreground (transparent, rings only)
// Exported as PNG with alpha channel — OS applies glass + parallax

struct IconForegroundLayer: View {
    var cyanColor: Color = GlassColors.liquidCyan

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width

            ZStack {
                // Outer ring — most transparent
                GlassRingLayer(color: cyanColor, lineWidth: s * 0.058, radius: s * 0.40)
                    .opacity(0.65)

                // Mid ring
                GlassRingLayer(color: cyanColor, lineWidth: s * 0.062, radius: s * 0.27)
                    .opacity(0.80)

                // Inner ring — fully opaque
                GlassRingLayer(color: cyanColor, lineWidth: s * 0.058, radius: s * 0.15)
                    .opacity(1.0)

                // Center dot
                Circle()
                    .fill(cyanColor)
                    .frame(width: s * 0.05, height: s * 0.05)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Ring Component

private struct GlassRingLayer: View {
    var color: Color
    var lineWidth: CGFloat
    var radius: CGFloat

    var body: some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: color.opacity(0.5), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Combined Preview (how it looks layered)

struct LiquidGlassIcon: View {
    var body: some View {
        ZStack {
            IconBackgroundLayer()
            IconForegroundLayer()
                .blendMode(.screen)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

typealias FocusBloxIcon = LiquidGlassIcon

// MARK: - Previews

#Preview("Layered (Combined)") {
    LiquidGlassIcon()
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .padding()
}

#Preview("Background Layer") {
    IconBackgroundLayer()
        .frame(width: 200, height: 200)
        .padding()
}

#Preview("Foreground Layer") {
    IconForegroundLayer()
        .frame(width: 200, height: 200)
        .padding()
        .background(Color.black.opacity(0.3))
}

#Preview("Dark Mode") {
    LiquidGlassIcon()
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .padding()
        .preferredColorScheme(.dark)
}
