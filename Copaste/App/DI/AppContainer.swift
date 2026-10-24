import Foundation
import Observation

/// The composition root: the vault location, and the clipboard session for the open vault.
@Observable
final class AppContainer {
    @ObservationIgnored let vaults: VaultRepository
    private(set) var session: ClipboardSession?
    var errorMessage: String?

    init(vaults: VaultRepository = UserDefaultsVaultRepository()) {
        self.vaults = vaults
        if let url = vaults.resolveVault() { session = ClipboardSession(root: url) }
    }

    func open(_ url: URL) {
        do {
            try vaults.prepare(url)
            session = ClipboardSession(root: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
