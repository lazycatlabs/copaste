import SwiftUI

extension OnboardingPage {
    struct WelcomeSection: View {
        @State private var floats = false

        var body: some View {
            AppIconImage(size: Metrics.Onboarding.heroIcon)
                .offset(y: floats ? -Metrics.Onboarding.floatOffset : Metrics.Onboarding.floatOffset)
                .shadow(color: .accentColor.opacity(Opacity.border), radius: Spacing.xxl, y: Spacing.md)
                .onAppear {
                    withAnimation(.easeInOut(duration: Metrics.Onboarding.floatDuration).repeatForever()) { floats = true }
                }
            Heading(title: Text(.onboardingTitle), subtitle: Text(.onboardingSubtitle))
        }
    }
}
