import SwiftUI
import AppKit

/// The list's icon for an entry: a thumbnail for images, a favicon for links, a swatch for colours.
struct ClipIconView: View {
    let item: ClipItem
    var size: CGFloat = Metrics.rowIcon
    @Environment(ClipboardSession.self) private var session

    var body: some View {
        Group {
            if let image = thumbnail {
                Image(nsImage: image).resizable().scaledToFill()
            } else if let color = item.color {
                RoundedRectangle(cornerRadius: Radius.xs).fill(Color(color))
                    .overlay(RoundedRectangle(cornerRadius: Radius.xs).strokeBorder(.primary.opacity(Opacity.border)))
            } else {
                Image(systemName: item.kind.symbolName).resizable().scaledToFit().padding(size / 6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: Radius.xs))
        .accessibilityLabel(item.kind.title)
    }

    private var thumbnail: NSImage? {
        switch item.kind {
        case .image: return session.blobURL(item.blob).flatMap(ImageCache.image)
        case .link: return session.blobURL(item.link?.favicon).flatMap(ImageCache.image)
        case .file:
            return item.files?.first.map { NSWorkspace.shared.icon(forFile: $0.path) }
        default: return nil
        }
    }
}

struct ClipRowView: View {
    let item: ClipItem
    var query = ""

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ClipIconView(item: item)
            Text(highlighted).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }

    /// The title with the search term marked, as in Spotlight.
    private var highlighted: AttributedString {
        var text = AttributedString(item.title.isEmpty ? item.kind.title : item.title)
        let query = query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty, let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].backgroundColor = .accentColor.opacity(Opacity.border)
        }
        return text
    }
}

extension Color {
    init(_ value: ColorValue) {
        self.init(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }
}
