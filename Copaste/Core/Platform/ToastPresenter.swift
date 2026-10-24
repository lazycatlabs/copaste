import AppKit
import SwiftUI

/// Shows a toast near the bottom of the screen the pointer is on, over every app, then fades it out.
/// It never takes the keyboard or the mouse.
final class ToastPresenter {
    static let shared = ToastPresenter()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: ToastLabel(message: message).padding(Spacing.xxl))
        panel.contentView = host
        let size = host.fittingSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + Metrics.Toast.bottomOffset,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = Task { [weak panel] in
            try? await Task.sleep(for: .seconds(Metrics.Panel.toastDuration))
            guard !Task.isCancelled, let panel else { return }
            await NSAnimationContext.runAnimationGroup { $0.duration = Metrics.Toast.fadeDuration; panel.animator().alphaValue = 0 }
            if !Task.isCancelled { panel.orderOut(nil) }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        return panel
    }
}
