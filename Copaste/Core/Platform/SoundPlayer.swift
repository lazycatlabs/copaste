import AppKit

/// Plays the copy and paste sounds chosen in Settings.
enum SoundPlayer {
    static func play(_ sound: ClipSound) {
        guard let name = sound.soundName else { return }
        // A fresh copy so quick repeats don't cut each other off.
        (NSSound(named: name)?.copy() as? NSSound)?.play()
    }
}
