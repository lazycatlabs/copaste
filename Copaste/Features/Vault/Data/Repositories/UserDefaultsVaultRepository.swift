import Foundation

/// The vault location is device-specific (each Mac sees the synced folder at its own path), so it lives in
/// UserDefaults as a bookmark, which keeps pointing at the folder if it is moved or renamed.
final class UserDefaultsVaultRepository: VaultRepository {
    private static let bookmarkKey = "vaultBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppDefaults.store) {
        self.defaults = defaults
    }

    func resolveVault() -> URL? {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }
        if isStale, let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Self.bookmarkKey) }
        return url
    }

    func prepare(_ url: URL) throws {
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
