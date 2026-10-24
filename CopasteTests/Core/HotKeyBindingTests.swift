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
}
