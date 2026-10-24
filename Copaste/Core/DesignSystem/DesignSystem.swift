import SwiftUI

// MARK: - Tokens
// Every size, spacing and radius in the UI comes from here, so the look can be tuned in one place.

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 16
    static let page: CGFloat = 20
    static let section: CGFloat = 24
    static let hero: CGFloat = 32
}

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 22
}

enum Opacity {
    static let hover = 0.04
    static let tint = 0.08
    static let fill = 0.12
    static let strong = 0.2
    static let border = 0.25
    static let muted = 0.6
    /// Highlighter strokes in the annotation editor.
    static let highlighter = 0.35
}

enum Metrics {
    static let hairline: CGFloat = 1
    static let rowIcon: CGFloat = 22
    static let appIcon: CGFloat = 16
    static let swatch: CGFloat = 14

    /// The floating clipboard window on macOS.
    enum Panel {
        static let size = CGSize(width: 780, height: 500)
        static let cornerRadius: CGFloat = 26
        static let listWidth: CGFloat = 290
        static let rowHeight: CGFloat = 38
        static let searchFont: CGFloat = 20
        static let colorPreview: CGFloat = 120
        static let actionsWidth: CGFloat = 260
        /// Pressing ⌘1…⌘9 pastes one of the first nine visible entries.
        static let quickPasteCount = 9
        static let toastDuration: TimeInterval = 1.8
        /// Longer entry titles are cut short in the toast.
        static let toastTitleLength = 40
    }

    enum Detail {
        /// About half the clipboard window; the information below scrolls.
        static let previewHeight: CGFloat = Panel.size.height / 2
        static let infoLabelWidth: CGFloat = 110
        static let colorFormatWidth: CGFloat = 46
    }

    enum Settings {
        static let windowSize = CGSize(width: 520, height: 600)
        static let welcomeSize = CGSize(width: 460, height: 420)
        static let heroIcon: CGFloat = 72
        static let ignoredAppIcon: CGFloat = 20
        static let shortcutRecorderWidth: CGFloat = 80
    }

    enum Annotate {
        static let windowSize = CGSize(width: 900, height: 680)
        static let swatch: CGFloat = 20
        static let selectedRing: CGFloat = 2
        /// Stroke widths, as a share of the image's width, so a mark looks the same at any zoom.
        static let widths: [CGFloat] = [0.003, 0.006, 0.012]
        static let highlighterScale: CGFloat = 4
        static let arrowHeadAngle = Double.pi / 7
        static let arrowHeadLength: CGFloat = 6
    }

    enum Clipboard {
        /// Seconds between checks of the system clipboard on macOS.
        static let pollInterval: TimeInterval = 0.5
        /// How long to wait after hiding the window before sending ⌘V, so the previous app is in front again.
        static let pasteDelay: TimeInterval = 0.12
        static let previewTextLimit = 4000
    }
}

// MARK: - Localization

/// Localized text for APIs that take a `String` (button titles, pickers, interpolation).
/// `Text` takes the resource directly: `Text(.settingsTitle)`.
nonisolated func L(_ resource: LocalizedStringResource) -> String { // swiftlint:disable:this identifier_name
    String(localized: resource)
}

// MARK: - Components

extension View {
    /// The rounded, subtly filled surface used for cards in both light and dark mode.
    func card(cornerRadius: CGFloat = Radius.md) -> some View {
        background(.fill.quaternary, in: .rect(cornerRadius: cornerRadius))
    }
}

/// A key cap such as "↩" or "⌘", as shown next to actions.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.scaled(.caption, design: .monospaced))
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.primary.opacity(Opacity.fill), in: .rect(cornerRadius: Radius.xs))
    }
}
