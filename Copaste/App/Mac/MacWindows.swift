#if os(macOS)
import AppKit
import SwiftUI

/// Ordinary windows (Settings, welcome, annotation) hosted by hand, so they can be opened from the
/// floating panel and the menu bar alike. One window per id, reused.
enum MacWindows {
    private static var windows: [String: NSWindow] = [:]

    static func show<Content: View>(id: String, title: String, size: CGSize, @ViewBuilder content: () -> Content) {
        let window = windows[id] ?? {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.center()
            windows[id] = window
            return window
        }()
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    static func close(id: String) {
        windows[id]?.close()
    }
}
#endif
