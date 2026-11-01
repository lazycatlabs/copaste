import SwiftUI

extension OnboardingPage {
    struct SyncSection: View {
        var body: some View {
            HStack(spacing: Spacing.xl) {
                Image(systemName: "laptopcomputer")
                Image(systemName: "arrow.left.arrow.right").font(.title2).symbolEffect(.pulse)
                Image(systemName: "icloud.fill")
                    .foregroundStyle(.tint)
                    .symbolEffect(.breathe)
                Image(systemName: "arrow.left.arrow.right").font(.title2).symbolEffect(.pulse)
                Image(systemName: "desktopcomputer")
            }
            .font(.system(size: Metrics.Onboarding.symbol))
            .foregroundStyle(.secondary)
            Heading(title: Text(.onboardingSyncTitle), subtitle: Text(.onboardingSync))
        }
    }
}
