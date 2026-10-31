import AppKit
import Carbon.HIToolbox
import SwiftUI

extension ShortcutsSettingsPage {
    /// Click, then press the new combination (esc cancels). It needs ⌘, ⌥ or ⌃, except ↩ and ⇥ in the clipboard window.
    struct ShortcutRecorder: View {
        let shortcut: Shortcut
        @State private var isRecording = false
        @State private var monitor: Any?
        private var store: HotKeyStore { .shared }

        var body: some View {
            HStack(spacing: Spacing.sm) {
                if store[shortcut] != shortcut.standard {
                    Button(L(.actionReset)) { store.set(shortcut.standard, for: shortcut) }.buttonStyle(.borderless)
                }
                Button { isRecording ? stop() : start() } label: {
                    Text(isRecording ? L(.shortcutPressKeys) : store[shortcut].displayText)
                        .font(.callout.monospaced())
                        .frame(minWidth: Metrics.Settings.shortcutRecorderWidth)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)
                .accessibilityIdentifier("settings.shortcut.\(shortcut.rawValue)")
            }
            .onDisappear(perform: stop)
        }

        private func start() {
            isRecording = true
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if Int(event.keyCode) == kVK_Escape {
                    stop()
                } else if let binding = HotKeyBinding(event: event, allowsPlainReturn: !shortcut.isGlobal) {
                    store.set(binding, for: shortcut)
                    stop()
                }
                return nil
            }
        }

        private func stop() {
            isRecording = false
            removeMonitor()
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
