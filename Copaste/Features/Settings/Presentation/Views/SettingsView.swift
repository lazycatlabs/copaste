import SwiftUI
#if os(macOS)
import AppKit
import ServiceManagement
import UniformTypeIdentifiers
#endif

/// Vault, history, text recognition, pasting and ignored apps.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            vaultSection
            if let session = container.session {
                SessionSettings(session: session)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L(.settingsTitle))
    }

    private var vaultSection: some View {
        Section(L(.settingsVault)) {
            if let root = container.session?.root {
                LabeledContent(L(.settingsVaultFolder)) {
                    Text(root.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
            }
            HStack {
                VaultFolderButton(title: L(.vaultChange))
                #if os(macOS)
                if let root = container.session?.root {
                    Button(L(.vaultReveal)) { NSWorkspace.shared.activateFileViewerSelecting([root]) }
                }
                #endif
            }
            Text(.vaultHint).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SessionSettings: View {
    @Bindable var session: ClipboardSession
    @State private var confirmsClear = false

    var body: some View {
        Section(L(.settingsHistory)) {
            Picker(L(.settingsKeepHistory), selection: $session.settings.retention) {
                ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle(L(.settingsLinkPreviews), isOn: $session.settings.fetchLinkPreviews)
            #if os(iOS)
            Toggle(L(.settingsCaptureOnOpen), isOn: $session.settings.captureOnOpen)
            #endif
        }
        Section {
            Toggle(L(.settingsTextRecognition), isOn: $session.settings.textRecognition)
            Picker(L(.settingsRecognitionMode), selection: $session.settings.accurateRecognition) {
                Text(.recognitionFast).tag(false)
                Text(.recognitionAccurate).tag(true)
            }
            .disabled(!session.settings.textRecognition)
        } footer: {
            Text(.settingsTextRecognitionFooter)
        }
        #if os(macOS)
        MacSettings(session: session)
        #endif
        Section {
            Button(L(.settingsClearHistory), role: .destructive) { confirmsClear = true }
                .confirmationDialog(L(.settingsClearConfirm), isPresented: $confirmsClear) {
                    Button(L(.settingsClearHistory), role: .destructive) { session.clearUnpinned() }
                }
        } footer: {
            Text(.settingsClearFooter)
        }
    }
}

#if os(macOS)
private struct MacSettings: View {
    @Bindable var session: ClipboardSession
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Section(L(.settingsPasting)) {
            Toggle(L(.settingsPasteDirectly), isOn: $session.settings.pasteDirectly)
            if session.settings.pasteDirectly && !PasteSimulator.isTrusted {
                HStack {
                    Text(.settingsAccessibilityNeeded).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L(.settingsGrantAccess)) { PasteSimulator.requestAccess() }
                }
            }
            LabeledContent(L(.settingsShortcut)) { Text(verbatim: "⇧⌘V") }
            Toggle(L(.settingsLaunchAtLogin), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        NSApp.presentError(error)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        Section {
            ForEach(session.settings.ignoredApps, id: \.bundleID) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    Button(L(.actionRemove), systemImage: "minus.circle") {
                        session.settings.ignoredApps.removeAll { $0.bundleID == app.bundleID }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            Button(L(.settingsAddApp), action: addApp)
        } header: {
            Text(.settingsIgnoredApps)
        } footer: {
            Text(.settingsIgnoredAppsFooter)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier,
              !session.settings.ignoredApps.contains(where: { $0.bundleID == bundleID }) else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        session.settings.ignoredApps.append(IgnoredApp(bundleID: bundleID, name: name))
    }
}
#endif
