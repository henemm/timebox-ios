import SwiftUI
import UIKit

/// Central design system for "Futuristic Spatial Style" UI
/// Supports both Light and Dark mode with adaptive colors
enum DesignSystem {

    // MARK: - Colors (Adaptive)

    enum Colors {
        /// Deep space background (Dark) / System grouped background (Light)
        static var appBackground: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.02, green: 0.02, blue: 0.063, alpha: 1) // #050510
                    : UIColor.systemGroupedBackground
            })
        }

        /// Glass surface material tint (5% white in Dark mode)
        static var glassSurfaceTint: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.05)
                    : UIColor.clear
            })
        }

        /// Primary text color
        static var primaryText: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor.white
                    : UIColor.label
            })
        }

        /// Secondary text color
        static var secondaryText: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.7)
                    : UIColor.secondaryLabel
            })
        }

        /// Gold accent color (brighter in Dark, muted in Light)
        static var goldAccent: Color {
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 1.0, green: 0.84, blue: 0, alpha: 1) // #FFD700
                    : UIColor(red: 0.83, green: 0.66, blue: 0, alpha: 1) // #D4A800
            })
        }

        /// Cyan/Blue gradient for glow effects
        static var accentGlow: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0, green: 0.8, blue: 1),      // Cyan
                    Color(red: 0.2, green: 0.4, blue: 1)     // Blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Cyan color for neon glow shadow
        static var glowCyan: Color {
            Color(red: 0, green: 0.8, blue: 1)
        }

        /// Blue color for neon glow shadow
        static var glowBlue: Color {
            Color(red: 0.2, green: 0.4, blue: 1)
        }
    }

    // MARK: - Spacing & Shapes

    enum Spacing {
        /// Corner radius for cards (continuous)
        static let cardCornerRadius: CGFloat = 24

        /// Padding inside cards
        static let cardPadding: CGFloat = 20

        /// Spacing between list rows
        static let listRowSpacing: CGFloat = 16

        /// Standard icon size
        static let iconSize: CGFloat = 28
    }

    // MARK: - Typography

    enum Typography {
        /// Title font - headline, bold, rounded
        static var titleFont: Font {
            .headline.bold().rounded()
        }

        /// Body font - rounded design
        static var bodyFont: Font {
            .body.rounded()
        }

        /// Caption font - rounded design
        static var captionFont: Font {
            .caption.rounded()
        }

        /// Monospaced digits for numbers/timers
        static var monospacedNumbers: Font {
            .body.monospacedDigit()
        }
    }
}

// MARK: - Font Extension for Rounded Design

private extension Font {
    func rounded() -> Font {
        self.weight(.regular)
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies glass card styling with ultraThinMaterial and corner radius
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(DesignSystem.Colors.glassSurfaceTint)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
    }

    /// Adds neon glow shadow effect
    func glowEffect(color: Color = DesignSystem.Colors.glowCyan, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
    }

    /// Sets the adaptive app background
    func appBackground() -> some View {
        self.background(DesignSystem.Colors.appBackground.ignoresSafeArea())
    }

    /// Conditionally applies a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
