import AppKit
import ServiceManagement
import SwiftUI

struct GeneralSettingsPage: View {
    @Environment(AppContainer.self) private var container
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        SettingsGroup(L(.settingsVault), footer: L(.vaultHint)) {
            SettingsRow(L(.settingsVaultFolder), symbol: "folder", subtitle: container.session?.root.path) {
                HStack {
                    if let root = container.session?.root {
                        Button(L(.vaultReveal)) { NSWorkspace.shared.activateFileViewerSelecting([root]) }
                    }
                    VaultFolderButton(title: L(.vaultChange))
                }
            }
        }
        SettingsGroup(L(.settingsStartup)) {
            SettingsRow(L(.settingsLaunchAtLogin), symbol: "power") {
                SettingsToggle(L(.settingsLaunchAtLogin), isOn: $launchAtLogin)
            }
        }
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSApp.presentError(error)
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
