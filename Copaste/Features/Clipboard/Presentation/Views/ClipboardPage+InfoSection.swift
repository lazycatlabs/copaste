import SwiftUI

extension ClipboardPage {
    /// The "Information" table under the preview.
    struct InfoSection: View {
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Spacing.md) {
                        Text(row.label).foregroundStyle(.secondary)
                            .frame(width: Metrics.Detail.infoLabelWidth * TextScale.shared.factor, alignment: .leading)
                        if row.isSource, item.sourceBundleID != nil { AppIconView(bundleID: item.sourceBundleID) }
                        Text(row.value).foregroundStyle(.primary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                    .font(.scaled(.body))
                }
            }
        }

        private var rows: [InfoRow] {
            var rows: [InfoRow] = []
            if let source = item.sourceName { rows.append(InfoRow(label: L(.infoSource), value: source, isSource: true)) }
            rows.append(InfoRow(label: L(.infoType), value: item.kind.title))
            if let group = session.group(of: item) { rows.append(InfoRow(label: L(.infoGroup), value: group.name)) }
            rows += kindRows
            rows.append(InfoRow(label: L(.infoTimesCopied), value: item.copyCount.formatted()))
            rows.append(InfoRow(label: L(.infoTimesPasted), value: item.pasteCount.formatted()))
            rows.append(InfoRow(label: L(.infoFirstCopied), value: Self.dateFormatter.string(from: item.firstCopied)))
            rows.append(InfoRow(label: L(.infoLastCopied), value: Self.dateFormatter.string(from: item.lastCopied)))
            if let date = item.firstPasted {
                rows.append(InfoRow(label: L(.infoFirstPasted), value: Self.dateFormatter.string(from: date)))
            }
            if let date = item.lastPasted {
                rows.append(InfoRow(label: L(.infoLastPasted), value: Self.dateFormatter.string(from: date)))
            }
            if let device = item.device { rows.append(InfoRow(label: L(.infoDevice), value: device)) }
            return rows
        }

        /// The stored image's size on disk.
        private var imageFileSize: Int64? {
            guard let url = session.blobURL(item.blob),
                  let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
            return Int64(size)
        }

        private var kindRows: [InfoRow] {
            switch item.kind {
            case .text:
                let text = item.text ?? ""
                let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                return [InfoRow(label: L(.infoCharacters), value: text.count.formatted()),
                        InfoRow(label: L(.infoWords), value: words.formatted())]
            case .link:
                var rows = [InfoRow(label: L(.infoURL), value: item.url?.absoluteString ?? item.text ?? "")]
                if let title = item.link?.title { rows.append(InfoRow(label: L(.infoTitleLabel), value: title)) }
                return rows
            case .email:
                return [InfoRow(label: L(.infoAddress), value: item.text ?? "")]
            case .color:
                guard let color = item.color else { return [] }
                return [InfoRow(label: "HEX", value: color.hex), InfoRow(label: "RGB", value: color.rgb),
                        InfoRow(label: "HSL", value: color.hsl)]
            case .image:
                var rows = [InfoRow(label: L(.infoDimensions), value: "\(item.pixelWidth ?? 0) × \(item.pixelHeight ?? 0)")]
                if let size = imageFileSize { rows.append(InfoRow(label: L(.infoSize), value: size.formatted(.byteCount(style: .file)))) }
                if let text = item.recognizedText {
                    rows.append(InfoRow(label: L(.infoRecognizedText), value: text.replacingOccurrences(of: "\n", with: " ")))
                }
                return rows
            case .file:
                let files = item.files ?? []
                var rows = [InfoRow(label: L(.infoFiles), value: files.count.formatted())]
                let size = files.compactMap(\.size).reduce(0, +)
                if size > 0 { rows.append(InfoRow(label: L(.infoSize), value: size.formatted(.byteCount(style: .file)))) }
                return rows
            }
        }
    }
}

/// One line of the information table.
private struct InfoRow {
    var label: String
    var value: String
    var isSource = false
}
