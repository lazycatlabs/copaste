import AppKit
import SwiftUI

extension ClipboardPage {
    /// The content itself, shown the way its kind is best read.
    struct PreviewSection: View {
        let item: ClipItem
        @Environment(ClipboardSession.self) private var session

        var body: some View {
            switch item.kind {
            case .image:
                image(session.blobURL(item.blob))
            case .link:
                if let preview = session.blobURL(item.link?.image).flatMap(Self.preview) {
                    Image(nsImage: preview).resizable().scaledToFit().clipShape(.rect(cornerRadius: Radius.md))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    text
                }
            case .color:
                colorPreview
            case .file:
                files
            default:
                text
            }
        }

        private static func preview(_ url: URL) -> NSImage? {
            ImageCache.image(at: url, maxPixelSize: Metrics.Clipboard.previewMaxPixelSize)
        }

        private var text: some View {
            ScrollView {
                Text(String((item.text ?? "").prefix(Metrics.Clipboard.previewTextLimit)))
                    .font(.scaled(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        @ViewBuilder
        private func image(_ url: URL?) -> some View {
            if let image = url.flatMap(Self.preview) {
                Image(nsImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: Radius.sm))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label(L(.previewUnavailable), systemImage: "photo.badge.exclamationmark").foregroundStyle(.secondary)
            }
        }

        @ViewBuilder
        private var colorPreview: some View {
            if let color = item.color {
                VStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: Radius.lg).fill(Color(color))
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.border)))
                        .frame(width: Metrics.Panel.colorPreview, height: Metrics.Panel.colorPreview)
                    Text(color.hex).font(.scaled(.title3, design: .monospaced))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        private var files: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(item.files ?? [], id: \.path) { file in
                    HStack {
                        ClipIcon(item: ClipItem(kind: .file, files: [file], hash: "", firstCopied: .now, lastCopied: .now))
                        VStack(alignment: .leading) {
                            Text(file.name)
                            Text(file.path).font(.scaled(.caption)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }
}
