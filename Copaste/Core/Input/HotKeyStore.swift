import AppKit
import Carbon.HIToolbox
import Observation

/// A recorded key combination for the global shortcut: the hardware key code Carbon needs, and the
/// modifiers. Shown with the glyphs macOS menus use ("⇧⌘V").
nonisolated struct HotKeyBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    /// The key's character without modifiers ("v"), for display.
    var characters: String
    /// `NSEvent.ModifierFlags` raw value (⌘ ⌥ ⌃ ⇧ only).
    var modifiers: UInt

    static let standard = HotKeyBinding(keyCode: UInt16(kVK_ANSI_V), characters: "v",
                                        modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)

    private var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// Carbon modifier mask for `RegisterEventHotKey`.
    var carbonModifiers: Int {
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        return carbon
    }

    var displayText: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        switch Int(keyCode) {
        case kVK_Space: text += "Space"
        case kVK_Return: text += "↩"
        case kVK_Tab: text += "⇥"
        default: text += characters.uppercased()
        }
        return text
    }

    init(keyCode: UInt16, characters: String, modifiers: UInt) {
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
    }

    /// A binding from a key press, or nil without ⌘, ⌥ or ⌃ (a plain key would fire while typing anywhere).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.subtracting(.shift).isEmpty, Int(event.keyCode) != kVK_Escape else { return nil }
        self.init(keyCode: event.keyCode, characters: (event.charactersIgnoringModifiers ?? "").lowercased(), modifiers: flags.rawValue)
    }
}

/// The global shortcut that opens the clipboard window. Stored per Mac, not in the vault.
@Observable
final class HotKeyStore {
    static let shared = HotKeyStore()
    private static let storageKey = "globalShortcut"

    private(set) var binding: HotKeyBinding
    /// Called after a change, to register the new combination.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        binding = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(HotKeyBinding.self, from: $0) } ?? .standard
    }

    func set(_ binding: HotKeyBinding) {
        self.binding = binding
        defaults.set(try? JSONEncoder().encode(binding), forKey: Self.storageKey)
        onChange?()
    }
}
