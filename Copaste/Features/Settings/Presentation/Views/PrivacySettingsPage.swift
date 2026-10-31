import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsGroup(L(.settingsIgnoredApps), footer: L(.settingsIgnoredAppsFooter)) {
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
