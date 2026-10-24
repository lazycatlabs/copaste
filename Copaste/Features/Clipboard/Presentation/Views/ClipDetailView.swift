import SwiftUI
import AppKit

/// An entry's content and its information (type, source, counts, dates).
struct ClipDetailView: View {
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ClipPreviewView(item: item)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: Metrics.Detail.previewHeight, alignment: .topLeading)
            ScrollView {
                ClipInfoView(item: item)
            }
            .scrollIndicators(.automatic)
        }
    }
}

/// The content itself, shown the way its kind is best read.
struct ClipPreviewView: View {
    let item: ClipItem
    @Environment(ClipboardSession.self) private var session

    var body: some View {
        switch item.kind {
        case .image:
            image(session.blobURL(item.blob))
        case .link:
            if let preview = session.blobURL(item.link?.image).flatMap(ImageCache.image) {
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
        if let image = url.flatMap(ImageCache.image) {
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
                    ClipIconView(item: ClipItem(kind: .file, files: [file], hash: "", firstCopied: .now, lastCopied: .now))
                    VStack(alignment: .leading) {
                        Text(file.name)
                        Text(file.path).font(.scaled(.caption)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        }
    }
}

/// The "Information" table under the preview.
struct ClipInfoView: View {
    let item: ClipItem
    @Environment(ClipboardSession.self) private var session

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(.infoTitle).font(.scaled(.caption)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: Spacing.md) {
                        Text(row.label).foregroundStyle(.secondary)
                            .frame(width: Metrics.Detail.infoLabelWidth, alignment: .leading)
                        Spacer(minLength: 0)
                        if row.isSource, item.sourceBundleID != nil { AppIconView(bundleID: item.sourceBundleID) }
                        Text(row.value).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                    .font(.scaled(.caption))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(index.isMultiple(of: 2) ? Color.primary.opacity(Opacity.hover) : .clear)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.sm))
        }
    }

    private struct Row {
        var label: String
        var value: String
        var isSource = false
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let source = item.sourceName { rows.append(Row(label: L(.infoSource), value: source, isSource: true)) }
        rows.append(Row(label: L(.infoType), value: item.kind.title))
        rows += kindRows
        rows.append(Row(label: L(.infoTimesCopied), value: item.copyCount.formatted()))
        rows.append(Row(label: L(.infoTimesPasted), value: item.pasteCount.formatted()))
        rows.append(Row(label: L(.infoFirstCopied), value: Self.dateFormatter.string(from: item.firstCopied)))
        rows.append(Row(label: L(.infoLastCopied), value: Self.dateFormatter.string(from: item.lastCopied)))
        if let date = item.firstPasted { rows.append(Row(label: L(.infoFirstPasted), value: Self.dateFormatter.string(from: date))) }
        if let date = item.lastPasted { rows.append(Row(label: L(.infoLastPasted), value: Self.dateFormatter.string(from: date))) }
        if let device = item.device { rows.append(Row(label: L(.infoDevice), value: device)) }
        return rows
    }

    /// The stored image's size on disk.
    private var imageFileSize: Int64? {
        guard let url = session.blobURL(item.blob),
              let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
        return Int64(size)
    }

    private var kindRows: [Row] {
        switch item.kind {
        case .text:
            let text = item.text ?? ""
            return [Row(label: L(.infoCharacters), value: text.count.formatted()),
                    Row(label: L(.infoWords), value: text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count.formatted())]
        case .link:
            var rows = [Row(label: L(.infoURL), value: item.url?.absoluteString ?? item.text ?? "")]
            if let title = item.link?.title { rows.append(Row(label: L(.infoTitleLabel), value: title)) }
            return rows
        case .email:
            return [Row(label: L(.infoAddress), value: item.text ?? "")]
        case .color:
            guard let color = item.color else { return [] }
            return [Row(label: "HEX", value: color.hex), Row(label: "RGB", value: color.rgb), Row(label: "HSL", value: color.hsl)]
        case .image:
            var rows = [Row(label: L(.infoDimensions), value: "\(item.pixelWidth ?? 0) × \(item.pixelHeight ?? 0)")]
            if let size = imageFileSize { rows.append(Row(label: L(.infoSize), value: size.formatted(.byteCount(style: .file)))) }
            if let text = item.recognizedText {
                rows.append(Row(label: L(.infoRecognizedText), value: text.replacingOccurrences(of: "\n", with: " ")))
            }
            return rows
        case .file:
            let files = item.files ?? []
            var rows = [Row(label: L(.infoFiles), value: files.count.formatted())]
            let size = files.compactMap(\.size).reduce(0, +)
            if size > 0 { rows.append(Row(label: L(.infoSize), value: size.formatted(.byteCount(style: .file)))) }
            return rows
        }
    }
}
