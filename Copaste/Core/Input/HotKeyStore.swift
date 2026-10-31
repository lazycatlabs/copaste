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

    /// One glyph per key, for key caps: ["⇧", "⌘", "V"].
    var keys: [String] {
        var keys: [String] = []
        if flags.contains(.control) { keys.append("⌃") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }
        switch Int(keyCode) {
        case kVK_Space: keys.append("Space")
        case kVK_Return, kVK_ANSI_KeypadEnter: keys.append("↩")
        case kVK_Tab: keys.append("⇥")
        case kVK_Delete: keys.append("⌫")
        case kVK_ForwardDelete: keys.append("⌦")
        default: keys.append(characters.uppercased())
        }
        return keys
    }

    var displayText: String { keys.joined() }

    /// Whether a key press is this combination. The keypad's enter counts as return.
    func matches(_ event: NSEvent) -> Bool {
        let code = Int(event.keyCode) == kVK_ANSI_KeypadEnter ? kVK_Return : Int(event.keyCode)
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return code == Int(keyCode) && flags.rawValue == modifiers
    }

    init(keyCode: UInt16, characters: String, modifiers: UInt) {
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
    }

    /// A binding from a key press, or nil without ⌘, ⌥ or ⌃ (a plain key would fire while typing).
    /// `allowsPlainReturn` lets ↩ and ⇥ through on their own, for the clipboard window, where they don't type text.
    init?(event: NSEvent, allowsPlainReturn: Bool = false) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let plainAllowed = allowsPlainReturn && [kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab].contains(Int(event.keyCode))
        guard !flags.subtracting(.shift).isEmpty || plainAllowed, Int(event.keyCode) != kVK_Escape else { return nil }
        self.init(keyCode: event.keyCode, characters: (event.charactersIgnoringModifiers ?? "").lowercased(), modifiers: flags.rawValue)
    }
}

/// The shortcuts that can be changed in Settings: the global ones (open the clipboard window, Paste Special the
/// latest copy), and the ones the clipboard window handles.
nonisolated enum Shortcut: String, CaseIterable, Identifiable, Sendable {
    case openHistory, pasteSpecialLatest, paste, copy, pasteSpecial, actions, open, annotate, save, pin, delete

    var id: String { rawValue }

    /// The section it's listed in, in Settings.
    var group: ShortcutGroup {
        switch self {
        case .openHistory, .pasteSpecialLatest: .anywhere
        case .paste, .copy, .pasteSpecial, .actions: .window
        case .open, .annotate, .save, .pin, .delete: .entry
        }
    }

    /// Only the global shortcuts work while another app is in front.
    var isGlobal: Bool { self == .openHistory || self == .pasteSpecialLatest }

    var standard: HotKeyBinding {
        switch self {
        case .openHistory: .standard
        case .paste: Self.binding(kVK_Return, "\r", [])
        case .copy: Self.binding(kVK_Return, "\r", .command)
        case .pasteSpecialLatest: Self.binding(kVK_ANSI_V, "v", [.control, .command])
        case .pasteSpecial: Self.binding(kVK_Return, "\r", .option)
        case .actions: Self.binding(kVK_ANSI_K, "k", .command)
        case .open: Self.binding(kVK_ANSI_O, "o", .command)
        case .annotate: Self.binding(kVK_ANSI_E, "e", .command)
        case .save: Self.binding(kVK_ANSI_S, "s", .command)
        case .pin: Self.binding(kVK_ANSI_P, "p", .command)
        case .delete: Self.binding(kVK_Delete, "", .command)
        }
    }

    var title: String {
        switch self {
        case .openHistory: L(.settingsShortcut)
        case .paste: L(.actionPaste)
        case .copy: L(.actionCopy)
        case .pasteSpecialLatest: L(.shortcutPasteSpecial)
        case .pasteSpecial: L(.shortcutPasteSpecialSelected)
        case .actions: L(.actionsTitle)
        case .open: L(.actionOpen)
        case .annotate: L(.actionAnnotate)
        case .save: L(.actionSaveToFile)
        case .pin: L(.shortcutPin)
        case .delete: L(.actionDelete)
        }
    }

    /// The global shortcut keeps the key it was stored under before the others could be changed.
    fileprivate var storageKey: String { self == .openHistory ? "globalShortcut" : "shortcut.\(rawValue)" }

    private static func binding(_ keyCode: Int, _ characters: String, _ flags: NSEvent.ModifierFlags) -> HotKeyBinding {
        HotKeyBinding(keyCode: UInt16(keyCode), characters: characters, modifiers: flags.rawValue)
    }
}

/// The sections of Settings › Shortcuts: where a shortcut works, and what it acts on.
nonisolated enum ShortcutGroup: CaseIterable, Sendable {
    /// Global: in any app.
    case anywhere
    /// In the clipboard window: pasting and copying.
    case window
    /// In the clipboard window, on the selected entry.
    case entry

    var title: String {
        switch self {
        case .anywhere: L(.shortcutGroupAnywhere)
        case .window: L(.shortcutGroupWindow)
        case .entry: L(.shortcutGroupEntry)
        }
    }

    var shortcuts: [Shortcut] { Shortcut.allCases.filter { $0.group == self } }
}

/// The shortcuts as set in Settings. Stored per Mac, not in the vault.
@Observable
final class HotKeyStore {
    static let shared = HotKeyStore()

    private var bindings: [Shortcut: HotKeyBinding] = [:]
    /// Called after a change, to register the new global combinations.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = AppDefaults.store) {
        self.defaults = defaults
        for shortcut in Shortcut.allCases {
            bindings[shortcut] = defaults.data(forKey: shortcut.storageKey)
                .flatMap { try? JSONDecoder().decode(HotKeyBinding.self, from: $0) }
        }
    }

    /// The global shortcut that opens the clipboard window.
    var binding: HotKeyBinding { self[.openHistory] }

    subscript(shortcut: Shortcut) -> HotKeyBinding { bindings[shortcut] ?? shortcut.standard }

    func set(_ binding: HotKeyBinding, for shortcut: Shortcut = .openHistory) {
        bindings[shortcut] = binding
        defaults.set(try? JSONEncoder().encode(binding), forKey: shortcut.storageKey)
        onChange?()
    }

    /// The window shortcut a key press triggers, if any.
    func shortcut(for event: NSEvent) -> Shortcut? {
        Shortcut.allCases.first { !$0.isGlobal && self[$0].matches(event) }
    }
}
