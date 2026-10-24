import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Vault, history, text recognition, pasting, sounds, ignored apps and support.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            vaultSection
            if let session = container.session {
                SessionSettings(session: session)
            }
            AboutSection()
        }
        .formStyle(.grouped)
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
                if let root = container.session?.root {
                    Button(L(.vaultReveal)) { NSWorkspace.shared.activateFileViewerSelecting([root]) }
                }
            }
            Text(.vaultHint).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SessionSettings: View {
    @Bindable var session: ClipboardSession
    @State private var confirmsClear = false

    var body: some View {
        Section(L(.settingsAppearance)) {
            Picker(L(.settingsTextSize), selection: Bindable(TextScale.shared).size) {
                ForEach(TextSize.allCases) { Text($0.title).tag($0) }
            }
            Toggle(L(.settingsShowToasts), isOn: $session.settings.showToasts)
        }
        Section(L(.settingsHistory)) {
            Picker(L(.settingsKeepHistory), selection: $session.settings.retention) {
                ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle(L(.settingsLinkPreviews), isOn: $session.settings.fetchLinkPreviews)
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
        PastingSection(session: session)
        Section(L(.settingsSounds)) {
            soundPicker(L(.settingsCopySound), selection: $session.settings.copySound)
            soundPicker(L(.settingsPasteSound), selection: $session.settings.pasteSound)
        }
        IgnoredAppsSection(session: session)
        RaycastImportSection(session: session)
        Section {
            Button(L(.settingsClearHistory), role: .destructive) { confirmsClear = true }
                .confirmationDialog(L(.settingsClearConfirm), isPresented: $confirmsClear) {
                    Button(L(.settingsClearHistory), role: .destructive) { session.clearUnpinned() }
                }
        } footer: {
            Text(.settingsClearFooter)
        }
    }

    /// Choosing a sound plays it, so it can be heard before it's kept.
    private func soundPicker(_ title: String, selection: Binding<ClipSound>) -> some View {
        Picker(title, selection: selection) {
            ForEach(ClipSound.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .onChange(of: selection.wrappedValue) { _, sound in SoundPlayer.play(sound) }
    }
}

private struct PastingSection: View {
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
            LabeledContent(L(.settingsShortcut)) { ShortcutRecorder() }
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
    }
}

/// Click, then press the new combination (esc cancels). It needs ⌘, ⌥ or ⌃.
private struct ShortcutRecorder: View {
    @State private var isRecording = false
    @State private var monitor: Any?
    private var store: HotKeyStore { .shared }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button { isRecording ? stop() : start() } label: {
                Text(isRecording ? L(.shortcutPressKeys) : store.binding.displayText)
                    .font(.callout.monospaced())
                    .frame(minWidth: Metrics.Settings.shortcutRecorderWidth)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .accessibilityIdentifier("settings.shortcut")
            if store.binding != .standard {
                Button(L(.actionReset)) { store.set(.standard) }.buttonStyle(.borderless)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
            } else if let binding = HotKeyBinding(event: event) {
                store.set(binding)
                stop()
            }
            return nil
        }
    }

    private func stop() {
        isRecording = false
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private struct IgnoredAppsSection: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        Section {
            ForEach(session.settings.ignoredApps, id: \.bundleID) { app in
                HStack(spacing: Spacing.md) {
                    AppIconView(bundleID: app.bundleID, size: Metrics.Settings.ignoredAppIcon)
                    Text(app.name)
                    Spacer()
                    Button(L(.actionRemove), systemImage: "minus.circle") {
                        session.settings.ignoredApps.removeAll { $0.bundleID == app.bundleID }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            HStack {
                Text(.settingsIgnoredApps)
                Spacer()
                Button(L(.settingsAddApp), systemImage: "plus", action: addApp)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("settings.addIgnoredApp")
            }
        } footer: {
            Text(.settingsIgnoredAppsFooter)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let bundleID = Bundle(url: url)?.bundleIdentifier,
              !session.settings.ignoredApps.contains(where: { $0.bundleID == bundleID }) else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        session.settings.ignoredApps.append(IgnoredApp(bundleID: bundleID, name: name))
    }
}

private struct AboutSection: View {
    var body: some View {
        Section(L(.settingsAbout)) {
            LabeledContent(L(.aboutVersion), value: SupportLinks.appVersion)
            HStack {
                if let url = SupportLinks.feedback() {
                    Link(destination: url) { Label(L(.supportFeedback), systemImage: "bubble.left") }
                }
                if let url = SupportLinks.bugReport() {
                    Link(destination: url) { Label(L(.supportBugReport), systemImage: "ladybug") }
                }
                Spacer()
                Link(destination: SupportLinks.website) { Label(L(.supportWebsite), systemImage: "safari") }
            }
        }
    }
}
