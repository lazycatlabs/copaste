import SwiftUI
import AppKit

/// The list's icon for an entry: a thumbnail for images, a favicon for links, a swatch for colours.
struct ClipIconView: View {
    let item: ClipItem
    var size: CGFloat = Metrics.rowIcon
    @Environment(ClipboardSession.self) private var session
    @Environment(\.displayScale) private var displayScale

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
        let pixels = size * displayScale
        switch item.kind {
        case .image: return session.blobURL(item.blob).flatMap { ImageCache.image(at: $0, maxPixelSize: pixels) }
        case .link: return session.blobURL(item.link?.favicon).flatMap { ImageCache.image(at: $0, maxPixelSize: pixels) }
        case .file:
            return item.files?.first.map { NSWorkspace.shared.icon(forFile: $0.path) }
        default: return nil
        }
    }
}

struct ClipRowView: View {
    let item: ClipItem
    var query = ""
    /// Shown while ⌘ is held: the number ⌘1…⌘9 that pastes this entry.
    var quickKey: Int?
    @Environment(ClipboardSession.self) private var session

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ClipIconView(item: item, size: Metrics.rowIcon * TextScale.shared.factor)
            VStack(alignment: .leading, spacing: 0) {
                Text(highlighted(item.title.isEmpty ? item.kind.title : item.title))
                    .font(.scaled(.body)).foregroundStyle(.primary).lineLimit(1).truncationMode(.tail)
                // The search found the entry by its note: show why.
                if let note = matchingNote {
                    Text(highlighted(note)).font(.scaled(.caption)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 0)
            if item.note != nil {
                Image(systemName: "note.text").font(.scaled(.callout)).foregroundStyle(.secondary)
                    .help(item.note ?? "")
            }
            if let group = session.group(of: item) {
                Text(group.name)
                    .font(.scaled(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.primary.opacity(Opacity.fill), in: .capsule)
            }
            if let quickKey {
                KeyCaps(keys: ["⌘", "\(quickKey)"])
            } else if item.pinned {
                Image(systemName: "pin.fill").font(.scaled(.callout)).foregroundStyle(.orange).rotationEffect(.degrees(45))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(quickKey == nil ? "row" : "row.quickKey")
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// The note on one line, while the search term is in it.
    private var matchingNote: String? {
        guard let note = item.note, !trimmedQuery.isEmpty, note.localizedStandardContains(trimmedQuery) else { return nil }
        return note.components(separatedBy: .newlines).joined(separator: " ")
    }

    /// The text with the search term marked, as in Spotlight.
    private func highlighted(_ string: String) -> AttributedString {
        var text = AttributedString(string)
        let query = trimmedQuery
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
