import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

/// A panel that takes the keyboard without bringing Copaste to the front, so the app the user was in
/// stays active and can receive the paste (like Spotlight).
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows and hides the clipboard window, handles its keyboard shortcuts and performs the entry actions.
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    private let container: AppContainer
    private let model = ClipboardViewModel()
    private var panel: FloatingPanel?
    private var keyMonitor: Any?
    /// Opens Settings and the annotation editor, which live in ordinary windows.
    var showSettings: () -> Void = {}

    init(container: AppContainer) {
        self.container = container
    }

    private var session: ClipboardSession? { container.session }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    /// - Parameters:
    ///   - selecting: the entry to select, e.g. one just made in the annotation editor.
    ///   - toast: a confirmation to show once the window is open.
    func show(selecting id: UUID? = nil, toast: String? = nil) {
        guard let session else { return showSettings() }
        model.reset()
        model.selectedID = id
        if let toast { model.showToast(toast) }
        Task { await session.reload() }
        let panel = panel ?? makePanel()
        self.panel = panel
        let view = ClipboardPanelView(model: model) { [weak self] action, item in
            self?.perform(action, on: item)
        } copy: { [weak self] item in
            self?.copyInPlace(item)
        }
        .environment(session)
        panel.contentView = NSHostingView(rootView: view)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.midX - Metrics.Panel.size.width / 2,
                                         y: visible.midY - Metrics.Panel.size.height / 2 + visible.height / 8))
        }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        installKeyMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func makePanel() -> FloatingPanel {
        // Borderless, so the SwiftUI content draws the whole rounded shape; the shadow follows it.
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Metrics.Panel.size),
                                  styleMask: [.nonactivatingPanel, .borderless],
                                  backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.delegate = self
        return panel
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// ↑↓ select, ↩ paste, ⌘↩ copy, ⌘K actions, ⌘1…9 quick paste, esc close. Returns whether the key was used.
    private func handle(_ event: NSEvent) -> Bool {
        guard let session else { return false }
        let command = event.modifierFlags.contains(.command)
        let selected = model.selected(in: session)
        switch Int(event.keyCode) {
        case kVK_DownArrow: model.moveSelection(by: 1, in: session)
        case kVK_UpArrow: model.moveSelection(by: -1, in: session)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard let selected else { return true }
            perform(command || !session.settings.pasteDirectly ? .copy : .paste, on: selected)
        case kVK_Escape:
            if model.showsActions { model.showsActions = false } else if !model.query.isEmpty { model.query = "" } else { hide() }
        case kVK_Delete where command:
            if let selected { perform(.delete, on: selected) }
        default:
            guard command, let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
            return handleCommand(key, selected: selected, session: session)
        }
        return true
    }

    private func handleCommand(_ key: String, selected: ClipItem?, session: ClipboardSession) -> Bool {
        if let number = Int(key), (1...Metrics.Panel.quickPasteCount).contains(number) {
            let visible = model.visibleItems(of: session)
            if number <= visible.count { perform(session.settings.pasteDirectly ? .paste : .copy, on: visible[number - 1]) }
            return true
        }
        if key == "," {
            hide()
            showSettings()
            return true
        }
        guard let selected, ["k", "p", "o", "e", "s"].contains(key) else { return false }
        if key == "k" {
            model.showsActions.toggle()
            return true
        }
        let available = ClipAction.available(for: selected)
        let action: ClipAction? = switch key {
        case "p": .pin
        case "o": available.first { $0 == .open || $0 == .composeEmail }
        case "e": available.contains(.annotate) ? .annotate : nil
        default: available.contains(.saveToFile) ? .saveToFile : nil
        }
        if let action { perform(action, on: selected) }
        return true
    }

    // MARK: Actions

    func perform(_ action: ClipAction, on item: ClipItem) {
        guard let session else { return }
        switch action {
        case .paste: paste(item, session: session)
        case .copy: session.copy(item); hide()
        case .copyHex: copyColor(item) { $0.hex }
        case .copyRGB: copyColor(item) { $0.rgb }
        case .copyHSL: copyColor(item) { $0.hsl }
        case .open, .composeEmail:
            hide()
            if let url = item.url { NSWorkspace.shared.open(url) }
        case .revealInFinder:
            hide()
            NSWorkspace.shared.activateFileViewerSelecting((item.files ?? []).map { URL(filePath: $0.path) })
        case .annotate: annotate(item, session: session)
        case .saveToFile: save(item, session: session)
        case .pin: session.togglePin(item)
        case .delete:
            model.moveSelection(by: 1, in: session)
            if model.selectedID == item.id { model.moveSelection(by: -1, in: session) }
            session.delete(item)
        }
    }

    /// Copies without closing the window, and says so.
    private func copyInPlace(_ item: ClipItem) {
        model.keepInPlace(item)
        session?.copy(item)
        let title = item.title.isEmpty ? item.kind.title : item.title
        let short = title.count > Metrics.Panel.toastTitleLength ? title.prefix(Metrics.Panel.toastTitleLength) + "…" : title
        model.showToast(L(.toastCopied(String(short))))
    }

    private func copyColor(_ item: ClipItem, format: (ColorValue) -> String) {
        guard let color = item.color else { return }
        session?.copy(item, as: format(color))
        hide()
    }

    /// Puts the entry on the clipboard, gives the previous app the focus back and sends ⌘V.
    private func paste(_ item: ClipItem, session: ClipboardSession) {
        guard session.settings.pasteDirectly else {
            session.copy(item)
            return hide()
        }
        guard PasteSimulator.isTrusted else {
            session.copy(item)
            hide()
            return PasteSimulator.requestAccess()
        }
        session.preparePaste(item)
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.Clipboard.pasteDelay) {
            PasteSimulator.pressCommandV()
        }
    }

    private func annotate(_ item: ClipItem, session: ClipboardSession) {
        guard let image = session.blobURL(item.blob).flatMap(ImageCache.image) else { return }
        hide()
        MacWindows.show(id: "annotate", title: L(.actionAnnotate), size: Metrics.Annotate.windowSize) {
            AnnotationEditor(image: image) { [weak self] png, width, height in
                let saved = session.addImage(png, width: width, height: height)
                MacWindows.close(id: "annotate")
                // Show the result, so it's clear the annotated copy was saved and is on the clipboard.
                self?.show(selecting: saved?.id, toast: L(.toastAnnotated))
            } onCancel: {
                MacWindows.close(id: "annotate")
            }
        }
    }

    private func save(_ item: ClipItem, session: ClipboardSession) {
        hide()
        if item.kind == .image, let url = session.blobURL(item.blob), let data = try? Data(contentsOf: url) {
            FileExporter.save(data, name: L(.imageFileName), type: .png)
        } else if let text = item.text {
            FileExporter.save(Data(text.utf8), name: L(.textFileName), type: .plainText)
        }
    }
}
