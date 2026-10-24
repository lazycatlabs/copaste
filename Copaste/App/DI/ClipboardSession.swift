import OSLog
import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

/// The open vault's clipboard history: what every screen reads, and the one place entries change.
@Observable
final class ClipboardSession {
    let root: URL
    private(set) var items: [ClipItem] = []
    var settings: AppSettings {
        didSet { if settings != oldValue { persist { try repository.saveSettings(settings) } } }
    }
    /// macOS: stop recording for a while, e.g. while handling secrets.
    var isPaused = false
    /// Shown as an alert. A failed save must never be silent.
    var errorMessage: String?

    @ObservationIgnored let repository: ClipRepository
    @ObservationIgnored let pasteboard = SystemPasteboard()

    init(root: URL, repository: ClipRepository? = nil) {
        self.root = root
        let repository = repository ?? FileClipRepository(root: root)
        self.repository = repository
        settings = repository.loadSettings()
        items = repository.loadAll()
        pruneExpired()
        #if os(macOS)
        pasteboard.onCapture = { [weak self] capture in self?.handle(capture) }
        pasteboard.startMonitoring()
        #endif
    }

    /// Picks up entries other devices added to the synced vault.
    func reload() async {
        let repository = repository
        let loaded = await Task.detached { repository.loadAll() }.value
        items = loaded
        pruneExpired()
    }

    func blobURL(_ path: String?) -> URL? {
        path.map(repository.blobURL)
    }

    // MARK: Recording

    #if os(iOS)
    /// iOS can't watch the clipboard, so it is read when Copaste comes to the front.
    func captureFromPasteboard() {
        guard let content = pasteboard.readIfChanged() else { return }
        handle(Capture(content: content))
    }
    #endif

    func handle(_ capture: Capture) {
        guard !isPaused else { return }
        if let bundleID = capture.sourceBundleID, settings.ignoredApps.contains(where: { $0.bundleID == bundleID }) { return }
        var (item, isNew) = ClipUseCases.record(capture, in: items, device: DeviceInfo.name)
        if isNew, case let .image(png, _, _) = capture.content {
            guard let path = persist({ try repository.writeBlob(png, name: "\(item.id.uuidString).png") }) else { return }
            item.blob = path
        }
        save(item)
        if isNew { enrich(item, capture: capture) }
    }

    /// Fetches a link's preview and reads text in images, after the entry is already saved.
    private func enrich(_ item: ClipItem, capture: Capture) {
        let settings = settings
        Task {
            if item.kind == .link, settings.fetchLinkPreviews, let url = item.url { await addPreview(to: item.id, from: url) }
            if case let .image(png, _, _) = capture.content, settings.textRecognition,
               let text = await TextRecognitionDataSource.recognize(png, accurate: settings.accurateRecognition) {
                update(item.id) { $0.recognizedText = text }
            }
        }
    }

    private func addPreview(to id: UUID, from url: URL) async {
        guard let metadata = await LinkMetadataDataSource.fetch(url) else { return }
        let favicon = metadata.favicon.flatMap { data in persist { try repository.writeBlob(data, name: "\(id.uuidString)-icon") } }
        let image = metadata.image.flatMap { data in persist { try repository.writeBlob(data, name: "\(id.uuidString)-preview") } }
        update(id) { $0.link = LinkMetadata(title: metadata.title, favicon: favicon, image: image) }
    }

    /// Adds an image made in Copaste (an annotated copy) as a new entry, and puts it on the clipboard.
    func addImage(_ png: Data, width: Int, height: Int) {
        handle(Capture(content: .image(png: png, width: width, height: height), sourceName: "Copaste", sourceBundleID: nil))
        if let item = items.first(where: { $0.hash == ClipUseCases.hash(of: .image(png: png, width: width, height: height)) }) {
            write(item)
        }
    }

    // MARK: Using entries

    /// Puts the entry on the clipboard. `text` overrides what is written, e.g. a colour in another format.
    func copy(_ item: ClipItem, as text: String? = nil) {
        write(item, as: text)
        save(ClipUseCases.markCopied(item))
    }

    /// Puts the entry on the clipboard and counts a paste; the platform layer sends the keystroke.
    func preparePaste(_ item: ClipItem) {
        write(item)
        save(ClipUseCases.markPasted(item))
    }

    private func write(_ item: ClipItem, as text: String? = nil) {
        switch item.kind {
        case .image: if let url = blobURL(item.blob) { pasteboard.write(.image(url)) }
        case .file: pasteboard.write(.files((item.files ?? []).map { URL(filePath: $0.path) }))
        default: pasteboard.write(.text(text ?? item.text ?? ""))
        }
    }

    func togglePin(_ item: ClipItem) {
        update(item.id) { $0.pinned.toggle() }
    }

    func delete(_ item: ClipItem) {
        guard persist({ try repository.delete(item) }) != nil else { return }
        items.removeAll { $0.id == item.id }
    }

    /// Deletes every entry that isn't pinned.
    func clearUnpinned() {
        for item in items where !item.pinned { delete(item) }
    }

    // MARK: Helpers

    private func pruneExpired() {
        for item in ClipUseCases.expired(items, retention: settings.retention) { delete(item) }
    }

    private func update(_ id: UUID, _ change: (inout ClipItem) -> Void) {
        guard var item = items.first(where: { $0.id == id }) else { return }
        change(&item)
        save(item)
    }

    private func save(_ item: ClipItem) {
        guard persist({ try repository.save(item) }) != nil else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    /// Runs a vault write, reporting a failure to the user instead of throwing.
    @discardableResult
    private func persist<T>(_ write: () throws -> T) -> T? {
        do {
            return try write()
        } catch {
            Log.storage.error("Vault write failed: \(error.localizedDescription, privacy: .public)")
            #if os(macOS)
            NSApp.presentError(error)
            #else
            errorMessage = error.localizedDescription
            #endif
            return nil
        }
    }
}
