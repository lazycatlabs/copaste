import AppKit
import SwiftUI

/// Where the clipboard window sits on a screen. Stored as the offset of its center from the center of the screen's
/// visible area, so (0, 0) is centered on any monitor and a position carries over between monitors.
///
/// Layout rules while dragging: the window stays inside the visible area, and its center snaps onto the screen's
/// vertical and horizontal center lines when within `Metrics.Panel.snapDistance`; guides show those lines.
enum PanelPlacement {
    private static let storageKey = "panelOffset"

    /// Until the user moves it: centered, a little above the middle.
    static func defaultOffset(in visible: CGRect) -> CGSize {
        CGSize(width: 0, height: visible.height / 8)
    }

    static var savedOffset: CGSize? {
        guard let values = AppDefaults.store.array(forKey: storageKey) as? [Double], values.count == 2 else { return nil }
        return CGSize(width: values[0], height: values[1])
    }

    static func save(_ offset: CGSize) {
        AppDefaults.store.set([Double(offset.width), Double(offset.height)], forKey: storageKey)
    }

    static func origin(size: CGSize, in visible: CGRect, offset: CGSize) -> CGPoint {
        clamp(CGPoint(x: visible.midX + offset.width - size.width / 2, y: visible.midY + offset.height - size.height / 2),
              size: size, in: visible)
    }

    /// A popup's origin with its top-left corner at `point` (the pointer), moved inside the visible area if it would stick out.
    static func origin(topLeftAt point: CGPoint, size: CGSize, in visible: CGRect) -> CGPoint {
        clamp(CGPoint(x: point.x, y: point.y - size.height), size: size, in: visible)
    }

    static func offset(of origin: CGPoint, size: CGSize, in visible: CGRect) -> CGSize {
        CGSize(width: origin.x + size.width / 2 - visible.midX, height: origin.y + size.height / 2 - visible.midY)
    }

    struct Snap: Equatable {
        var origin: CGPoint
        /// On the screen's vertical center line.
        var centeredX: Bool
        /// On the screen's horizontal center line.
        var centeredY: Bool
    }

    static func snap(_ origin: CGPoint, size: CGSize, in visible: CGRect, distance: CGFloat) -> Snap {
        var origin = clamp(origin, size: size, in: visible)
        let centered = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        let centeredX = abs(origin.x - centered.x) <= distance
        let centeredY = abs(origin.y - centered.y) <= distance
        if centeredX { origin.x = centered.x }
        if centeredY { origin.y = centered.y }
        return Snap(origin: origin, centeredX: centeredX, centeredY: centeredY)
    }

    private static func clamp(_ origin: CGPoint, size: CGSize, in visible: CGRect) -> CGPoint {
        CGPoint(x: min(max(origin.x, visible.minX), visible.maxX - size.width),
                y: min(max(origin.y, visible.minY), visible.maxY - size.height))
    }
}

/// The screen's center lines, shown while the clipboard window is dragged. A line turns accent-colored
/// when the window is snapped onto it.
@Observable
final class PanelGuides {
    var centeredX = false
    var centeredY = false
    @ObservationIgnored private var window: NSPanel?

    func show(on visible: CGRect, below panel: NSWindow) {
        let window = window ?? makeWindow()
        self.window = window
        if window.frame != visible { window.setFrame(visible, display: true) }
        if !window.isVisible { window.order(.below, relativeTo: panel.windowNumber) }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSPanel {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PanelGuidesView(guides: self))
        return window
    }
}

private struct PanelGuidesView: View {
    let guides: PanelGuides

    var body: some View {
        ZStack {
            line(on: guides.centeredX).frame(width: width(guides.centeredX)).frame(maxHeight: .infinity)
            line(on: guides.centeredY).frame(height: width(guides.centeredY)).frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func line(on: Bool) -> some View {
        Rectangle().fill(on ? Color.accentColor : Color.white.opacity(Opacity.border))
    }

    private func width(_ on: Bool) -> CGFloat {
        on ? Metrics.Panel.guideWidth * 2 : Metrics.Panel.guideWidth
    }
}

/// An empty area that moves the window when dragged: reports each mouse move, then the release.
/// AppKit rather than a SwiftUI gesture, which doesn't get the mouse in the non-activating panel.
struct WindowDragHandle: NSViewRepresentable {
    let onDrag: (_ ended: Bool) -> Void

    func makeNSView(context: Context) -> HandleView { HandleView() }

    func updateNSView(_ view: HandleView, context: Context) {
        view.onDrag = onDrag
    }

    final class HandleView: NSView {
        var onDrag: (Bool) -> Void = { _ in }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        // Mouse-down starts tracking, so the window keeps the exact distance to the pointer.
        override func mouseDown(with event: NSEvent) { onDrag(false) }
        override func mouseDragged(with event: NSEvent) { onDrag(false) }
        override func mouseUp(with event: NSEvent) { onDrag(true) }
    }
}
