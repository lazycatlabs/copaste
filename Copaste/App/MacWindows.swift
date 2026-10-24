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
        // A menu bar app isn't the active app, so asking to activate may be refused; ordering the window
        // front regardless keeps it from opening behind the app the user was in.
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    static func close(id: String) {
        windows[id]?.close()
    }
}
