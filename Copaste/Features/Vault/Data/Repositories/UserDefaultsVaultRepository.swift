import Foundation

/// The vault location is device-specific (each device sees the synced folder at its own path), so it lives in
/// UserDefaults as a bookmark. On iOS the bookmark keeps access to a folder picked in Files: iCloud Drive,
/// Google Drive, OneDrive or any other provider.
final class UserDefaultsVaultRepository: VaultRepository {
    private static let bookmarkKey = "vaultBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func resolveVault() -> URL? {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        if isStale, let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Self.bookmarkKey) }
        return url
    }

    func prepare(_ url: URL) throws {
        // Balanced by the app's lifetime: the vault stays open until Copaste quits or another vault is chosen.
        _ = url.startAccessingSecurityScopedResource()
        let store = JSONFileStore(root: url)
        if !FileManager.default.fileExists(atPath: url.appending(path: VaultLayout.config).path) {
            try store.write(AppSettings(), to: VaultLayout.config)
        }
        defaults.set(try url.bookmarkData(), forKey: Self.bookmarkKey)
    }

    func forget() {
        defaults.removeObject(forKey: Self.bookmarkKey)
    }
}
