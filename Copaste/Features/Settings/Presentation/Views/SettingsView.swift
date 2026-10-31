import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// The Settings pages, in sidebar order.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general, history, pasting, appearance, shortcuts, groups, privacy, importing, updates, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: L(.settingsGeneral)
        case .history: L(.settingsHistory)
        case .pasting: L(.settingsPasting)
        case .appearance: L(.settingsAppearance)
        case .shortcuts: L(.settingsShortcuts)
        case .groups: L(.settingsGroups)
        case .privacy: L(.settingsPrivacy)
        case .importing: L(.importTitle)
        case .updates: L(.settingsUpdates)
        case .about: L(.settingsAbout)
        }
    }

    var subtitle: String {
        switch self {
        case .general: L(.settingsGeneralSubtitle)
        case .history: L(.settingsHistorySubtitle)
        case .pasting: L(.settingsPastingSubtitle)
        case .appearance: L(.settingsAppearanceSubtitle)
        case .shortcuts: L(.settingsShortcutsSubtitle)
        case .groups: L(.settingsGroupsSubtitle)
        case .privacy: L(.settingsPrivacySubtitle)
        case .importing: L(.importSubtitle)
        case .updates: L(.settingsUpdatesSubtitle)
        case .about: L(.aboutSubtitle)
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .history: "clock.arrow.circlepath"
        case .pasting: "doc.on.clipboard"
        case .appearance: "paintbrush"
        case .shortcuts: "keyboard"
        case .groups: "folder"
        case .privacy: "hand.raised"
        case .importing: "square.and.arrow.down.on.square"
        case .updates: "arrow.down.circle"
        case .about: "info.circle"
        }
    }

    /// What the sidebar search matches: the page's name and the settings on it.
    var searchText: String {
        let settings: [LocalizedStringResource] = switch self {
        case .general: [.settingsVault, .settingsVaultFolder, .vaultChange, .settingsLaunchAtLogin]
        case .history: [.settingsKeepHistory, .settingsLinkPreviews, .settingsUniversalClipboard, .settingsTextRecognition,
                        .settingsRecognitionMode, .storageTitle, .storageUsed, .cleanupTitle, .cleanupPeriod]
        case .pasting: [.settingsPasteDirectly, .settingsSounds, .settingsCopySound, .settingsPasteSound]
        case .appearance: [.settingsTextSize, .settingsShowToasts, .settingsWindowPosition]
        case .shortcuts: [.settingsShortcut, .actionPaste, .actionCopy, .actionsTitle, .shortcutQuickPaste]
        case .groups: [.groupAdd, .groupNewName]
        case .privacy: [.settingsIgnoredApps, .settingsAddApp]
        case .importing: [.importFromRaycast]
        case .updates: [.updateCheck, .changelogTitle, .updateDownload]
        case .about: [.aboutVersion, .aboutLicense, .aboutSourceCode, .aboutSponsor, .supportFeedback, .supportBugReport, .supportWebsite]
        }
        return ([title, subtitle] + settings.map(L)).joined(separator: " ")
    }

    /// Pages about the open vault's history; without a vault only General and About apply.
    var needsVault: Bool { ![.general, .updates, .about].contains(self) }
}

/// A sidebar page's icon: accent-colored, but in the selected row's text color while that row is highlighted, so it
/// doesn't vanish into the accent-colored selection.
private struct SidebarIcon: View {
    let symbol: String
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Image(systemName: symbol).foregroundStyle(prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
    }
}

/// Settings: a searchable sidebar of pages, and the chosen page.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var search = ""

    private var pages: [SettingsPage] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return SettingsPage.allCases.filter { page in
            (container.session != nil || !page.needsVault) && (query.isEmpty || page.searchText.localizedStandardContains(query))
        }
    }

    var body: some View {
        @Bindable var navigation = SettingsNavigation.shared
        NavigationSplitView {
            List(pages, selection: $navigation.page) { page in
                Label {
                    Text(page.title).font(.scaled(.body))
                } icon: {
                    SidebarIcon(symbol: page.symbol)
                }
                .tag(page)
                .accessibilityIdentifier("settings.nav.\(page.rawValue)")
            }
            .searchable(text: $search, placement: .sidebar)
            .overlay {
                if pages.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .navigationSplitViewColumnWidth(min: Metrics.Settings.sidebarWidth, ideal: Metrics.Settings.sidebarWidth)
        } detail: {
            page(pages.contains(navigation.page ?? .general) ? navigation.page ?? .general : pages.first ?? .general)
        }
        .onChange(of: search) {
            // Show the first match, so typing a setting's name opens its page.
            if let first = pages.first, !pages.contains(navigation.page ?? .general) { navigation.page = first }
        }
    }

    @ViewBuilder
    private func page(_ page: SettingsPage) -> some View {
        SettingsPageView(page: page) {
            switch page {
            case .general: GeneralPage()
            case .updates: UpdatesPage()
            case .about: AboutPage()
            default:
                if let session = container.session {
                    switch page {
                    case .history: HistoryPage(session: session)
                    case .pasting: PastingPage(session: session)
                    case .appearance: AppearancePage(session: session)
                    case .shortcuts: ShortcutsPage()
                    case .groups: GroupsPage(session: session)
                    case .privacy: PrivacyPage(session: session)
                    default: RaycastImportSection(session: session)
                    }
                }
            }
        }
        .id(page)
    }
}

// MARK: - Pages

private struct GeneralPage: View {
    @Environment(AppContainer.self) private var container
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        SettingsSection(L(.settingsVault), footer: L(.vaultHint)) {
            SettingsRow(L(.settingsVaultFolder), symbol: "folder", subtitle: container.session?.root.path) {
                HStack {
                    if let root = container.session?.root {
                        Button(L(.vaultReveal)) { NSWorkspace.shared.activateFileViewerSelecting([root]) }
                    }
                    VaultFolderButton(title: L(.vaultChange))
                }
            }
        }
        SettingsSection(L(.settingsStartup)) {
            SettingsRow(L(.settingsLaunchAtLogin), symbol: "power") {
                Toggle(L(.settingsLaunchAtLogin), isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
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

private struct HistoryPage: View {
    @Bindable var session: ClipboardSession
    var body: some View {
        SettingsSection(L(.settingsHistory)) {
            SettingsRow(L(.settingsKeepHistory), symbol: "calendar.badge.clock") {
                Picker(L(.settingsKeepHistory), selection: $session.settings.retention) {
                    ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(L(.settingsLinkPreviews), symbol: "link") {
                Toggle(L(.settingsLinkPreviews), isOn: $session.settings.fetchLinkPreviews).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(L(.settingsUniversalClipboard), symbol: "laptopcomputer.and.iphone",
                        subtitle: L(.settingsUniversalClipboardFooter)) {
                Toggle(L(.settingsUniversalClipboard), isOn: $session.settings.saveUniversalClipboard).labelsHidden().toggleStyle(.switch)
            }
        }
        SettingsSection(L(.settingsTextRecognition), footer: L(.settingsTextRecognitionFooter)) {
            SettingsRow(L(.settingsTextRecognition), symbol: "text.viewfinder") {
                Toggle(L(.settingsTextRecognition), isOn: $session.settings.textRecognition).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(L(.settingsRecognitionMode), symbol: "gauge.with.dots.needle.67percent") {
                Picker(L(.settingsRecognitionMode), selection: $session.settings.accurateRecognition) {
                    Text(.recognitionFast).tag(false)
                    Text(.recognitionAccurate).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .disabled(!session.settings.textRecognition)
        }
        StorageSection(session: session)
        DeleteEntriesSection(session: session)
    }
}

private struct PastingPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsSection(L(.settingsPasting)) {
            SettingsRow(L(.settingsPasteDirectly), symbol: "doc.on.clipboard", subtitle: pasteDirectlySubtitle) {
                HStack {
                    if session.settings.pasteDirectly && !PasteSimulator.isTrusted {
                        Button(L(.settingsGrantAccess)) { PasteSimulator.requestAccess() }
                    }
                    Toggle(L(.settingsPasteDirectly), isOn: $session.settings.pasteDirectly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.pasteDirectly")
                }
            }
        }
        SettingsSection(L(.settingsSounds)) {
            SettingsRow(L(.settingsCopySound), symbol: "speaker.wave.2") {
                soundPicker(L(.settingsCopySound), $session.settings.copySound)
            }
            SettingsRow(L(.settingsPasteSound), symbol: "speaker.wave.3") {
                soundPicker(L(.settingsPasteSound), $session.settings.pasteSound)
            }
        }
    }

    /// What on and off do, plus the missing permission when it's on but can't send ⌘V.
    private var pasteDirectlySubtitle: String {
        let needsAccess = session.settings.pasteDirectly && !PasteSimulator.isTrusted
        return needsAccess ? L(.settingsPasteDirectlyFooter) + "\n" + L(.settingsAccessibilityNeeded) : L(.settingsPasteDirectlyFooter)
    }

    /// Choosing a sound plays it, so it can be heard before it's kept.
    private func soundPicker(_ title: String, _ selection: Binding<ClipSound>) -> some View {
        Picker(title, selection: selection) {
            ForEach(ClipSound.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .onChange(of: selection.wrappedValue) { _, sound in SoundPlayer.play(sound) }
    }
}

private struct AppearancePage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsSection(L(.settingsTextSize), footer: L(.settingsTextSizeFooter)) {
            SettingsRow(L(.settingsTextSize), symbol: "textformat.size") {
                Picker(L(.settingsTextSize), selection: Bindable(TextScale.shared).size) {
                    ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        SettingsSection(L(.settingsClipboardWindow)) {
            SettingsRow(L(.settingsShowToasts), symbol: "checkmark.bubble") {
                Toggle(L(.settingsShowToasts), isOn: $session.settings.showToasts).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(L(.settingsWindowPosition), symbol: "macwindow", subtitle: L(.settingsWindowPositionHint)) {
                Button(L(.actionCenter)) { PanelPlacement.save(.zero) }.accessibilityIdentifier("settings.centerWindow")
            }
        }
    }
}

private struct ShortcutsPage: View {
    var body: some View {
        SettingsSection(L(.settingsShortcuts), footer: L(.settingsShortcutsFooter)) {
            ForEach(Shortcut.allCases) { shortcut in
                SettingsRow(shortcut.title, symbol: Self.symbol(of: shortcut)) { ShortcutRecorder(shortcut: shortcut) }
            }
        }
        SettingsSection(L(.settingsFixedShortcuts)) {
            fixed(L(.shortcutNavigate), symbol: "arrow.up.arrow.down", keys: ["↑", "↓"])
            fixed(L(.shortcutQuickPaste), symbol: "number", keys: ["⌘", "1…9"])
            fixed(L(.shortcutSettings), symbol: "gearshape", keys: ["⌘", ","])
            fixed(L(.shortcutClose), symbol: "escape", keys: ["esc"])
        }
    }

    private func fixed(_ title: String, symbol: String, keys: [String]) -> some View {
        SettingsRow(title, symbol: symbol) { KeyCaps(keys: keys) }
    }

    private static func symbol(of shortcut: Shortcut) -> String {
        switch shortcut {
        case .openHistory: "command"
        case .paste: "doc.on.clipboard"
        case .copy: "doc.on.doc"
        case .pasteSpecial: "wand.and.stars"
        case .actions: "ellipsis.circle"
        case .open: "arrow.up.forward.app"
        case .annotate: "pencil.tip.crop.circle"
        case .save: "square.and.arrow.down"
        case .pin: "pin"
        case .delete: "trash"
        }
    }
}

private struct GroupsPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsSection(L(.settingsGroups), footer: L(.settingsGroupsFooter)) {
            Button(L(.groupAdd), systemImage: "plus") { session.addGroup() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.addGroup")
        } content: {
            if session.settings.groups.isEmpty {
                SettingsRow(L(.groupsEmpty), symbol: "folder.badge.questionmark") { EmptyView() }
            }
            ForEach($session.settings.groups) { $group in
                let count = session.items.count { $0.groupID == group.id }
                SettingsRow(L(.groupEntries(count)), symbol: "folder") {
                    TextField(L(.groupNewName), text: $group.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: Metrics.Settings.groupNameWidth)
                        .accessibilityIdentifier("settings.groupName")
                    Button(L(.actionDelete), systemImage: "trash") { session.deleteGroup(group) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct PrivacyPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsSection(L(.settingsIgnoredApps), footer: L(.settingsIgnoredAppsFooter)) {
            Button(L(.settingsAddApp), systemImage: "plus", action: addApp)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.addIgnoredApp")
        } content: {
            ForEach(session.settings.ignoredApps, id: \.bundleID) { app in
                HStack(spacing: Spacing.xl) {
                    AppIconView(bundleID: app.bundleID, size: Metrics.Settings.rowIcon)
                    Text(app.name).font(.scaled(.body, weight: .medium))
                    Spacer()
                    Button(L(.actionRemove), systemImage: "minus.circle") {
                        session.settings.ignoredApps.removeAll { $0.bundleID == app.bundleID }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.lg)
            }
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

private struct AboutPage: View {
    var body: some View {
        SettingsSection(L(.settingsAbout), footer: L(.aboutLicenseFooter)) {
            SettingsRow(L(.aboutVersion), symbol: "info.circle") {
                Text(SupportLinks.appVersion).foregroundStyle(.secondary).textSelection(.enabled)
            }
            SettingsRow(L(.aboutLicense), symbol: "checkmark.seal") {
                Link(L(.aboutLicenseName), destination: SupportLinks.license).accessibilityIdentifier("settings.license")
            }
            SettingsRow(L(.aboutSourceCode), symbol: "chevron.left.forwardslash.chevron.right") {
                Link(L(.aboutSourceCode), destination: SupportLinks.sourceCode)
            }
            SettingsRow(L(.aboutSponsor), symbol: "heart") {
                Link(L(.aboutSponsor), destination: SupportLinks.sponsor).accessibilityIdentifier("settings.sponsor")
            }
            if let url = SupportLinks.feedback() {
                SettingsRow(L(.supportFeedback), symbol: "bubble.left") { Link(L(.supportFeedback), destination: url) }
            }
            if let url = SupportLinks.bugReport() {
                SettingsRow(L(.supportBugReport), symbol: "ladybug") { Link(L(.supportBugReport), destination: url) }
            }
            SettingsRow(L(.supportWebsite), symbol: "safari") { Link(L(.supportWebsite), destination: SupportLinks.website) }
        }
    }
}

// MARK: - Shortcut recorder

/// Click, then press the new combination (esc cancels). It needs ⌘, ⌥ or ⌃, except ↩ and ⇥ in the clipboard window.
private struct ShortcutRecorder: View {
    let shortcut: Shortcut
    @State private var isRecording = false
    @State private var monitor: Any?
    private var store: HotKeyStore { .shared }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if store[shortcut] != shortcut.standard {
                Button(L(.actionReset)) { store.set(shortcut.standard, for: shortcut) }.buttonStyle(.borderless)
            }
            Button { isRecording ? stop() : start() } label: {
                Text(isRecording ? L(.shortcutPressKeys) : store[shortcut].displayText)
                    .font(.callout.monospaced())
                    .frame(minWidth: Metrics.Settings.shortcutRecorderWidth)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .accessibilityIdentifier("settings.shortcut.\(shortcut.rawValue)")
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
            } else if let binding = HotKeyBinding(event: event, allowsPlainReturn: !shortcut.isGlobal) {
                store.set(binding, for: shortcut)
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
