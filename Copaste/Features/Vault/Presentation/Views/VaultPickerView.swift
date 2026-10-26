import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// First run: a short introduction (once per Mac), then the folder that holds the clipboard history. A folder inside
/// iCloud Drive, Google Drive or OneDrive shares the history between devices.
struct VaultPickerView: View {
    var onPicked: () -> Void = {}
    @State private var showsIntro = !Onboarding.isSeen

    var body: some View {
        VStack(spacing: Spacing.section) {
            VStack(spacing: Spacing.section) {
                AppIconImage(size: Metrics.Settings.heroIcon)
                if showsIntro { intro } else { picker }
            }
            .frame(maxHeight: .infinity)
            Link(L(.onboardingCredit), destination: SupportLinks.website)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding.credit")
        }
        .padding(Spacing.hero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var intro: some View {
        VStack(spacing: Spacing.section) {
            VStack(spacing: Spacing.md) {
                Text(.onboardingTitle).font(.largeTitle.bold())
                Text(.onboardingSubtitle).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: Spacing.xl) {
                feature("keyboard", Text(.onboardingShortcut(HotKeyStore.shared.binding.displayText)))
                feature("folder", Text(.onboardingSync))
                feature("magnifyingglass", Text(.onboardingOrganize))
            }
            Button(L(.onboardingStart)) {
                Onboarding.isSeen = true
                showsIntro = false
            }
            .accessibilityIdentifier("onboarding.start")
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var picker: some View {
        VStack(spacing: Spacing.section) {
            VStack(spacing: Spacing.md) {
                Text(.appName).font(.largeTitle.bold())
                Text(.vaultIntro).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            VaultFolderButton(title: L(.vaultChoose), onPicked: onPicked)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private func feature(_ symbol: String, _ text: Text) -> some View {
        HStack(spacing: Spacing.xl) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: Metrics.Settings.rowIcon)
            text
        }
    }
}

/// Whether this Mac has seen the welcome window's introduction. Per Mac, so it lives in `AppDefaults.store`.
nonisolated enum Onboarding {
    static let storageKey = "onboardingSeen"

    static var isSeen: Bool {
        get { AppDefaults.store.bool(forKey: storageKey) }
        set { AppDefaults.store.set(newValue, forKey: storageKey) }
    }
}

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
