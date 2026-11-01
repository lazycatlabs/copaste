import SwiftUI

/// First run: a short introduction (once per Mac, see `OnboardingPage`), then the folder that holds the clipboard
/// history. A folder inside iCloud Drive, Google Drive or OneDrive shares the history between devices.
struct VaultPickerPage: View {
    var onPicked: () -> Void = {}
    @State private var showsIntro = !Onboarding.isSeen

    var body: some View {
        VStack(spacing: Spacing.section) {
            Group {
                if showsIntro {
                    OnboardingPage { withAnimation { showsIntro = false } }
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
