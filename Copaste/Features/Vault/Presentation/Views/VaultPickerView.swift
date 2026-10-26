import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// First run: a short introduction (once per Mac, see `OnboardingView`), then the folder that holds the clipboard
/// history. A folder inside iCloud Drive, Google Drive or OneDrive shares the history between devices.
struct VaultPickerView: View {
    var onPicked: () -> Void = {}
    @State private var showsIntro = !Onboarding.isSeen

    var body: some View {
        VStack(spacing: Spacing.section) {
            Group {
                if showsIntro {
                    OnboardingView { withAnimation { showsIntro = false } }
                } else {
                    picker.transition(.opacity.combined(with: .scale))
                }
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

    private var picker: some View {
        VStack(spacing: Spacing.section) {
            AppIconImage(size: Metrics.Settings.heroIcon)
            VStack(spacing: Spacing.md) {
                Text(.appName).font(.largeTitle.bold())
                Text(.vaultIntro).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            VaultFolderButton(title: L(.vaultChoose), onPicked: onPicked)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
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
