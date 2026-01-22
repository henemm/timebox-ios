import AudioToolbox

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
}
