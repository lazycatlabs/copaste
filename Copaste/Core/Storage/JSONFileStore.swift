import OSLog
import Foundation

/// Fixed paths inside a vault folder.
nonisolated enum VaultLayout {
    static let marker = ".copaste"
    static let config = ".copaste/config.json"
    /// One JSON file per clipboard entry.
    static let items = "items"
    /// Image data, favicons and link previews, referenced from the entries by relative path.
    static let blobs = "blobs"
}

/// Reads and writes Codable values as pretty-printed JSON files inside a vault.
/// One file per entity keeps cloud-sync conflicts (iCloud Drive, Google Drive, OneDrive) small and readable.
nonisolated struct JSONFileStore: Sendable {
    let root: URL

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Every `.json` file in `directory`. Unreadable files are moved aside, never overwritten.
    /// Files a cloud provider hasn't downloaded yet (`.name.json.icloud`) are asked for and picked up on the next read.
    func readAll<T: Decodable>(_ type: T.Type, in directory: String) -> [T] {
        let dir = root.appending(path: directory, directoryHint: .isDirectory)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        let decoder = Self.decoder()
        for placeholder in files where placeholder.pathExtension == "icloud" {
            try? FileManager.default.startDownloadingUbiquitousItem(at: placeholder)
        }
        return files.filter { $0.pathExtension == "json" }.compactMap { read(T.self, at: $0, decoder: decoder) }
    }

    // ponytail: shallow merge, nested settings objects need a recursive merge once they exist.
    /// Decodes `path`, filling keys missing from the file (e.g. settings added in a newer version) from `defaults`.
    func read<T: Codable>(_ path: String, default defaults: T) -> T {
        guard let data = try? Data(contentsOf: root.appending(path: path)),
              let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var merged = try? JSONSerialization.jsonObject(with: Self.encoder().encode(defaults)) as? [String: Any]
        else { return defaults }
        merged.merge(stored) { _, new in new }
        guard let mergedData = try? JSONSerialization.data(withJSONObject: merged) else { return defaults }
        return (try? Self.decoder().decode(T.self, from: mergedData)) ?? defaults
    }

    func write<T: Encodable>(_ value: T, to path: String) throws {
        try writeData(Self.encoder().encode(value), to: path)
    }

    func writeData(_ data: Data, to path: String) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func remove(_ path: String) throws {
        let url = root.appending(path: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func read<T: Decodable>(_ type: T.Type, at url: URL, decoder: JSONDecoder) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Never overwrite user data: move the broken file aside so it can be inspected or recovered.
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("unreadable"))
            Log.storage.error("Moved unreadable file aside \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
