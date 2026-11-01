import Foundation

/// Where clipboard entries and their images live. The vault implementation is `FileClipRepository`.
nonisolated protocol ClipRepository: Sendable {
    func loadAll() -> [ClipItem]
    func save(_ item: ClipItem) throws
    /// Removes the entry and every image it references.
    func delete(_ item: ClipItem) throws
    /// Stores image data and returns its vault-relative path.
    func writeBlob(_ data: Data, name: String) throws -> String
    func blobURL(_ path: String) -> URL
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
    /// Bytes on disk for these entries and the images they reference.
    func size(of items: [ClipItem]) -> Int64
    /// Bytes on disk for the whole history: entries, images and settings.
    func totalSize() -> Int64
}
