#if os(macOS)
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Copaste on macOS lives in the menu bar: a global shortcut (⇧⌘V) opens the floating clipboard window.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    private(set) lazy var panel = ClipboardPanelController(container: container)
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.showSettings = { [weak self] in self?.showSettings() }
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in self?.panel.toggle() }
        if container.session == nil { showWelcome() }
    }

    func showSettings() {
        MacWindows.show(id: "settings", title: L(.settingsTitle), size: Metrics.Settings.windowSize) {
            SettingsView().environment(container)
        }
    }

    func showWelcome() {
        MacWindows.show(id: "welcome", title: L(.appName), size: Metrics.Settings.welcomeSize) {
            VaultPickerView { MacWindows.close(id: "welcome") }.environment(container)
        }
    }
}

/// The menu bar item's menu.
struct MacMenu: View {
    let delegate: MacAppDelegate

    var body: some View {
        Button(L(.menuOpenHistory)) { delegate.panel.show() }
        if let session = delegate.container.session {
            Toggle(L(.menuPause), isOn: Binding(get: { session.isPaused }, set: { session.isPaused = $0 }))
        }
        Divider()
        Button(L(.menuSettings)) { delegate.showSettings() }.keyboardShortcut(",")
        Button(L(.menuQuit)) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
#endif
