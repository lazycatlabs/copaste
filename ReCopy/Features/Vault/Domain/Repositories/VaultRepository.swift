import Foundation

/// Knows which folder is this device's vault. Vault *contents* belong to the clipboard repository.
protocol VaultRepository: AnyObject {
    /// The remembered vault.
    func resolveVault() -> URL?
    /// Creates the vault structure if needed and remembers the folder.
    func prepare(_ url: URL) throws
    func forget()
}
