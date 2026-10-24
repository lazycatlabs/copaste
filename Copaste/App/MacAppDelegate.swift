import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Copaste lives in the menu bar: a global shortcut (⇧⌘V unless changed in Settings) opens the floating clipboard window.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    private(set) lazy var panel = ClipboardPanelController(container: container)
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.showSettings = { [weak self] in self?.showSettings() }
        registerHotKey()
        HotKeyStore.shared.onChange = { [weak self] in self?.registerHotKey() }
        if container.session == nil { showWelcome() }
    }

    private func registerHotKey() {
        hotKey?.unregister()
        let binding = HotKeyStore.shared.binding
        hotKey = GlobalHotKey(keyCode: Int(binding.keyCode), modifiers: binding.carbonModifiers) { [weak self] in self?.panel.toggle() }
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
        Button(L(.menuOpenHistory(HotKeyStore.shared.binding.displayText))) { delegate.panel.show() }
        if let session = delegate.container.session {
            Toggle(L(.menuPause), isOn: Binding(get: { session.isPaused }, set: { session.isPaused = $0 }))
        }
        Divider()
        Button(L(.supportFeedback)) { SupportLinks.feedback().map { _ = NSWorkspace.shared.open($0) } }
        Button(L(.supportBugReport)) { SupportLinks.bugReport().map { _ = NSWorkspace.shared.open($0) } }
        Button(L(.supportWebsite)) { NSWorkspace.shared.open(SupportLinks.website) }
        Divider()
        Button(L(.menuSettings)) { delegate.showSettings() }.keyboardShortcut(",")
        Button(L(.menuQuit)) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
