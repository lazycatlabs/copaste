import Foundation

/// What can be done with an entry. Which ones apply depends on its kind and the platform.
nonisolated enum ClipAction: String, CaseIterable, Identifiable, Sendable {
    case paste, copy, open, composeEmail, copyHex, copyRGB, copyHSL, annotate, saveToFile, revealInFinder, share
    case pin, delete

    var id: String { rawValue }

    static func available(for item: ClipItem, isMac: Bool) -> [ClipAction] {
        var actions: [ClipAction] = isMac ? [.paste, .copy] : [.copy]
        switch item.kind {
        case .link: actions.append(.open)
        case .email: actions.append(.composeEmail)
        case .color: actions += [.copyHex, .copyRGB, .copyHSL]
        case .image: actions += isMac ? [.annotate, .saveToFile] : [.annotate]
        case .file: actions += isMac ? [.open, .revealInFinder] : []
        case .text: actions += isMac ? [.saveToFile] : []
        }
        if !isMac { actions.append(.share) }
        return actions + [.pin, .delete]
    }

    var symbolName: String {
        switch self {
        case .paste: "doc.on.clipboard"
        case .copy: "doc.on.doc"
        case .open: "arrow.up.forward.app"
        case .composeEmail: "envelope"
        case .copyHex, .copyRGB, .copyHSL: "eyedropper"
        case .annotate: "pencil.tip.crop.circle"
        case .saveToFile: "square.and.arrow.down"
        case .revealInFinder: "folder"
        case .share: "square.and.arrow.up"
        case .pin: "pin"
        case .delete: "trash"
        }
    }

    func title(for item: ClipItem) -> String {
        switch self {
        case .paste: L(.actionPaste)
        case .copy: L(.actionCopy)
        case .open: item.kind == .link ? L(.actionOpenInBrowser) : L(.actionOpen)
        case .composeEmail: L(.actionComposeEmail)
        case .copyHex: L(.actionCopyAs("HEX"))
        case .copyRGB: L(.actionCopyAs("RGB"))
        case .copyHSL: L(.actionCopyAs("HSL"))
        case .annotate: L(.actionAnnotate)
        case .saveToFile: L(.actionSaveToFile)
        case .revealInFinder: L(.actionRevealInFinder)
        case .share: L(.actionShare)
        case .pin: item.pinned ? L(.actionUnpin) : L(.actionPin)
        case .delete: L(.actionDelete)
        }
    }

    /// The macOS shortcut shown next to the action, and handled by the clipboard window.
    var shortcut: String? {
        switch self {
        case .paste: "↩"
        case .copy: "⌘↩"
        case .open, .composeEmail: "⌘O"
        case .annotate: "⌘E"
        case .saveToFile: "⌘S"
        case .pin: "⌘P"
        case .delete: "⌘⌫"
        default: nil
        }
    }
}
