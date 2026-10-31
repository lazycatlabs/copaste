import SwiftUI

extension ClipboardPage {
    /// One entry in the history list: icon, title (with the search term marked), note, group and pin or ⌘ number.
    struct EntryItem: View {
        let item: ClipItem
        var query = ""
        /// Shown while ⌘ is held: the number ⌘1…⌘9 that pastes this entry.
        var quickKey: Int?
        @Environment(ClipboardSession.self) private var session

        var body: some View {
            HStack(spacing: Spacing.lg) {
                ClipIcon(item: item, size: Metrics.rowIcon * TextScale.shared.factor)
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
}
