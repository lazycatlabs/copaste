import SwiftUI

struct ShortcutsSettingsPage: View {
    var body: some View {
        ForEach(ShortcutGroup.allCases, id: \.self) { group in
            // How to change one, under the first section.
            SettingsGroup(group.title, footer: group == .anywhere ? L(.settingsShortcutsFooter) : nil) {
                ForEach(group.shortcuts) { shortcut in
                    SettingsRow(shortcut.title, symbol: Self.symbol(of: shortcut)) { ShortcutRecorder(shortcut: shortcut) }
                }
            }
        }
        SettingsGroup(L(.settingsFixedShortcuts)) {
            fixed(L(.shortcutNavigate), symbol: "arrow.up.arrow.down", keys: ["↑", "↓"])
            fixed(L(.shortcutQuickPaste), symbol: "number", keys: ["⌘", "1…9"])
            fixed(L(.shortcutSettings), symbol: "gearshape", keys: ["⌘", ","])
            fixed(L(.shortcutClose), symbol: "escape", keys: ["esc"])
        }
    }

    private func fixed(_ title: String, symbol: String, keys: [String]) -> some View {
        SettingsRow(title, symbol: symbol) { KeyCaps(keys: keys) }
    }

    private static func symbol(of shortcut: Shortcut) -> String {
        switch shortcut {
        case .openHistory: "command"
        case .paste: "doc.on.clipboard"
        case .copy: "doc.on.doc"
        case .pasteSpecialLatest: "wand.and.stars.inverse"
        case .pasteSpecial: "wand.and.stars"
        case .actions: "ellipsis.circle"
        case .open: "arrow.up.forward.app"
        case .annotate: "pencil.tip.crop.circle"
        case .save: "square.and.arrow.down"
        case .pin: "pin"
        case .delete: "trash"
        }
    }
}
