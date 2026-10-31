import CryptoKit
import Foundation

/// The clipboard history's rules, kept free of UI and storage so they can be unit-tested.
nonisolated enum ClipUseCases {
    /// The same content copied again updates the existing entry (count, last copied) instead of adding a new one.
    /// Image data is written by the caller once the result is known to be new, so `blob` is filled in there.
    static func record(_ capture: Capture, in items: [ClipItem], device: String, now: Date = .now) -> (item: ClipItem, isNew: Bool) {
        let hash = hash(of: capture.content)
        if var existing = items.first(where: { $0.hash == hash }) {
            existing.copyCount += 1
            existing.lastCopied = now
            existing.sourceName = capture.sourceName ?? existing.sourceName
            existing.sourceBundleID = capture.sourceBundleID ?? existing.sourceBundleID
            return (existing, false)
        }
        var item = ClipItem(kind: .text, hash: hash, sourceName: capture.sourceName, sourceBundleID: capture.sourceBundleID,
                            device: device, firstCopied: now, lastCopied: now)
        switch capture.content {
        case let .text(text):
            item.kind = ClipClassifier.kind(of: text)
            item.text = item.kind == .text ? text : text.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .image(_, width, height):
            item.kind = .image
            item.pixelWidth = width
            item.pixelHeight = height
        case let .files(files):
            item.kind = .file
            item.files = files
        }
        return (item, true)
    }

    static func hash(of content: CapturedContent) -> String {
        let data: Data = switch content {
        case let .text(text): Data(text.utf8)
        case let .image(png, _, _): png
        case let .files(files): Data(files.map(\.path).joined(separator: "\n").utf8)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Copying an entry from Copaste counts as copying it again and moves it to the top.
    static func markCopied(_ item: ClipItem, now: Date = .now) -> ClipItem {
        var item = item
        item.copyCount += 1
        item.lastCopied = now
        return item
    }

    /// The entry copied last, which is what's on the clipboard (copying an older entry again moves it here).
    static func latest(_ items: [ClipItem]) -> ClipItem? {
        items.max { $0.lastCopied < $1.lastCopied }
    }

    /// File names that don't clash: a repeated name gets " 2", " 3", … ("Image", "Image 2").
    static func uniqueNames(_ names: [String]) -> [String] {
        var used: Set<String> = []
        return names.map { name in
            var unique = name
            var number = 2
            while used.contains(unique) {
                unique = "\(name) \(number)"
                number += 1
            }
            used.insert(unique)
            return unique
        }
    }

    static func markPasted(_ item: ClipItem, now: Date = .now) -> ClipItem {
        var item = markCopied(item, now: now)
        item.pasteCount += 1
        item.firstPasted = item.firstPasted ?? now
        item.lastPasted = now
        return item
    }

    /// Several entries as one text, one per line, so they paste in a single ⌘V.
    /// Nil when one of them is an image or files, which can't be joined.
    static func joinedText(_ items: [ClipItem]) -> String? {
        let texts = items.compactMap { [.image, .file].contains($0.kind) ? nil : $0.text }
        return texts.count == items.count ? texts.joined(separator: "\n") : nil
    }

    /// An empty note is no note.
    static func cleanNote(_ note: String) -> String? {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
    }

    /// Entries older than the retention period. Pinned entries are kept forever.
    static func expired(_ items: [ClipItem], retention: Retention, now: Date = .now) -> [ClipItem] {
        guard let limit = retention.cutoff(from: now) else { return [] }
        return items.filter { !$0.pinned && $0.lastCopied < limit }
    }

    /// - Parameter group: only entries in this group; nil for all.
    static func filter(_ items: [ClipItem], kind: ClipKind?, query: String, created: DateFilter = .anyTime, group: UUID? = nil,
                       now: Date = .now, calendar: Calendar = .current) -> [ClipItem] {
        let query = query.trimmingCharacters(in: .whitespaces)
        let period = created.interval(now: now, calendar: calendar)
        return items.filter { item in
            (kind == nil || item.kind == kind)
                && (group == nil || item.groupID == group)
                && (period?.contains(item.firstCopied) ?? true)
                && (query.isEmpty || item.searchableText.localizedStandardContains(query))
        }
    }

    /// Pinned first, then newest first, grouped under time headings.
    static func sections(_ items: [ClipItem], now: Date = .now, calendar: Calendar = .current) -> [(TimeSection, [ClipItem])] {
        let sorted = items.sorted { $0.lastCopied > $1.lastCopied }
        var result: [(TimeSection, [ClipItem])] = []
        let pinned = sorted.filter(\.pinned)
        if !pinned.isEmpty { result.append((.pinned, pinned)) }
        for item in sorted where !item.pinned {
            let section = TimeSection.of(item.lastCopied, now: now, calendar: calendar)
            if result.last?.0 == section {
                result[result.count - 1].1.append(item)
            } else {
                result.append((section, [item]))
            }
        }
        return result
    }
}
