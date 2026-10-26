import AppKit
import SwiftUI

/// Ordinary windows (Settings, welcome, annotation) hosted by hand, so they can be opened from the
/// floating panel and the menu bar alike. One window per id, reused.
///
/// Copaste is a menu bar app, and macOS often refuses to bring such an app to the front, so its windows could open
/// behind other apps, on another Space or another screen. While one of these windows is open, Copaste becomes a
/// regular app (Dock icon, ⌘Tab), which macOS lets activate; it goes back to the menu bar when the last one closes.
enum MacWindows {
    private static var windows: [String: NSWindow] = [:]
    private static var closeObserver: Any?

    /// - Parameter fullSize: content under a transparent title bar, as a sidebar window (Settings) wants.
    static func show<Content: View>(id: String, title: String, size: CGSize, fullSize: Bool = false,
                                    @ViewBuilder content: () -> Content) {
        let window = windows[id] ?? {
            var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
            if fullSize { style.insert(.fullSizeContentView) }
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = fullSize
            window.titleVisibility = fullSize ? .hidden : .visible
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace]
            window.setAccessibilityIdentifier(id)
            windows[id] = window
            return window
        }()
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        if !window.isVisible { center(window) }
        observeClosing()
        NSApp.setActivationPolicy(.regular)
        focus(window)
        // The switch to a regular app lands on a later turn of the run loop (and a menu bar menu is still closing),
        // so an activation asked for now can be dropped and the window opens without the keyboard. Ask again then.
        DispatchQueue.main.async { focus(window) }
    }

    private static func focus(_ window: NSWindow) {
        // The plain `activate()` is only a request, which macOS turns down for a menu bar app the user isn't in.
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    static func isVisible(id: String) -> Bool {
        windows[id]?.isVisible == true
    }

    static func close(id: String) {
        windows[id]?.close()
    }

    /// On the screen the pointer is on, where the user is looking.
    private static func center(_ window: NSWindow) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return window.center() }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }

    private static func observeClosing() {
        guard closeObserver == nil else { return }
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            let closing = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let closing, windows.values.contains(where: { $0 === closing }) else { return }
                if !windows.values.contains(where: { $0 !== closing && $0.isVisible }) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
