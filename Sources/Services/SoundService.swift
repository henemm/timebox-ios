import AudioToolbox
import UIKit

/// Service for playing audio feedback sounds
@MainActor
enum SoundService {
    /// Plays the end-of-block gong sound
    /// Only plays if sound is enabled in AppSettings
    static func playEndGong() {
        guard AppSettings.shared.soundEnabled else { return }
        // System sound ID 1007 = "Tink" (short, pleasant)
        AudioServicesPlaySystemSound(1007)
    }

    /// Plays warning sound and haptic before block ends
    /// Only plays if both sound and warning are enabled in AppSettings
    static func playWarning() {
        guard AppSettings.shared.soundEnabled else { return }
        guard AppSettings.shared.warningEnabled else { return }
        // System sound ID 1005 = "Alarm" (different from end gong)
        AudioServicesPlaySystemSound(1005)
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
