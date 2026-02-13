import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Service for playing audio feedback sounds
@MainActor
enum SoundService {
    /// Plays the end-of-block gong sound
    /// Only plays if sound is enabled in AppSettings
    static func playEndGong() {
        guard AppSettings.shared.soundEnabled else { return }
        #if os(macOS)
        NSSound.beep()
        #else
        AudioServicesPlaySystemSound(1007)
        #endif
    }

    /// Plays warning sound and haptic before block ends
    /// Only plays if both sound and warning are enabled in AppSettings
    static func playWarning() {
        guard AppSettings.shared.soundEnabled else { return }
        guard AppSettings.shared.warningEnabled else { return }
        #if os(macOS)
        NSSound.beep()
        #else
        AudioServicesPlaySystemSound(1005)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}
