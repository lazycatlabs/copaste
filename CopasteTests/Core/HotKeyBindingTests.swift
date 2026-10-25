import AppKit
import Carbon.HIToolbox
import Testing
@testable import Copaste

struct HotKeyBindingTests {
    @Test func defaultIsShiftCommandV() {
        #expect(HotKeyBinding.standard.displayText == "⇧⌘V")
        #expect(HotKeyBinding.standard.carbonModifiers == cmdKey | shiftKey)
    }

    @Test func showsModifiersInMenuOrder() {
        let binding = HotKeyBinding(keyCode: UInt16(kVK_Space), characters: " ",
                                    modifiers: NSEvent.ModifierFlags([.command, .option, .control]).rawValue)
        #expect(binding.displayText == "⌃⌥⌘Space")
    }

    @Test @MainActor func storeRemembersTheRecordedShortcut() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let binding = HotKeyBinding(keyCode: UInt16(kVK_ANSI_C), characters: "c", modifiers: NSEvent.ModifierFlags.option.rawValue)
        HotKeyStore(defaults: defaults).set(binding)
        #expect(HotKeyStore(defaults: defaults).binding == binding)
    }

    @Test @MainActor func windowShortcutsMatchKeyPressesAndCanBeChanged() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let store = HotKeyStore(defaults: defaults)
        #expect(store.shortcut(for: try key(kVK_Return, "\r")) == .paste)
        #expect(store.shortcut(for: try key(kVK_ANSI_KeypadEnter, "\u{3}", .command)) == .copy)
        #expect(store.shortcut(for: try key(kVK_ANSI_K, "k")) == nil)

        let commandJ = HotKeyBinding(keyCode: UInt16(kVK_ANSI_J), characters: "j", modifiers: NSEvent.ModifierFlags.command.rawValue)
        store.set(commandJ, for: .actions)
        #expect(HotKeyStore(defaults: defaults)[.actions].displayText == "⌘J")
        #expect(store.shortcut(for: try key(kVK_ANSI_J, "j", .command)) == .actions)
        #expect(store.shortcut(for: try key(kVK_ANSI_K, "k", .command)) == nil)
    }

    private func key(_ code: Int, _ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                      context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                      isARepeat: false, keyCode: UInt16(code)))
    }
}
