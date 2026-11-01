import SwiftUI

extension UpdatesSettingsPage {
    /// One version's notes: "### Heading" lines in bold, "- " lines as bullets, inline Markdown (bold, code) kept.
    struct ReleaseNotesItem: View {
        let release: AppRelease
        let isInstalled: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Text(release.version).font(.scaled(.title3, weight: .semibold))
                    if isInstalled {
                        Text(.changelogInstalled)
                            .font(.scaled(.caption, weight: .medium))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.accentColor.opacity(Opacity.strong), in: .capsule)
                    }
                    Spacer()
                    if let date = release.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted)).font(.scaled(.callout)).foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in line }
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.release.\(release.version)")
        }

        private var lines: [AnyView] {
            release.notes.split(separator: "\n").compactMap { raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") {
                    let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                    return AnyView(Text(Self.markdown(title)).font(.scaled(.body, weight: .semibold)).padding(.top, Spacing.xs))
                }
                if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    return AnyView(HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(verbatim: "•").foregroundStyle(.secondary)
                        Text(Self.markdown(String(line.dropFirst(2)))).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.scaled(.body)))
                }
                return AnyView(Text(Self.markdown(line)).font(.scaled(.body)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true))
            }
        }

        private static func markdown(_ text: String) -> AttributedString {
            (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(text)
        }
    }
}
