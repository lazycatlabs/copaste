import AppKit
import SwiftUI

/// Picks a folder and opens it as the vault.
struct VaultFolderButton: View {
    let title: String
    var onPicked: () -> Void = {}
    @Environment(AppContainer.self) private var container
    @State private var isImporting = false

    var body: some View {
        @Bindable var container = container
        Button(title, action: pick)
            .accessibilityIdentifier("vault.choose")
            .alert(L(.errorTitle),
                   isPresented: Binding(get: { container.errorMessage != nil }, set: { _ in container.errorMessage = nil })) {
                Button(L(.actionOK)) {}
            } message: {
                Text(container.errorMessage ?? "")
            }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L(.vaultUseFolder)
        panel.message = L(.vaultIntro)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    private func open(_ url: URL) {
        container.open(url)
        if container.session != nil { onPicked() }
    }
}
