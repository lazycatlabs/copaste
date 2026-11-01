import SwiftUI

extension OnboardingPage {
    struct OrganizeSection: View {
        private let features: [(symbol: String, title: LocalizedStringResource)] = [
            ("magnifyingglass", .onboardingSearch), ("pin.fill", .onboardingPin), ("folder.fill", .onboardingGroups),
            ("pencil.tip.crop.circle", .actionAnnotate), ("note.text", .onboardingNotes),
        ]

        var body: some View {
            Heading(title: Text(.onboardingOrganizeTitle), subtitle: Text(.onboardingOrganize))
            HStack(spacing: Spacing.md) {
                ForEach(features, id: \.symbol) { FeatureTile(symbol: $0.symbol, title: $0.title) }
            }
            Text(.onboardingOrganizeHint).font(.footnote).foregroundStyle(.tertiary)
        }
    }
}

/// A feature whose symbol plays when the pointer moves over it.
private struct FeatureTile: View {
    let symbol: String
    let title: LocalizedStringResource
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: isHovered)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(width: Metrics.Onboarding.featureTile.width, height: Metrics.Onboarding.featureTile.height)
        .background(.tint.opacity(isHovered ? Opacity.strong : Opacity.tint), in: .rect(cornerRadius: Radius.md))
        .scaleEffect(isHovered ? Metrics.Onboarding.hoverScale : 1)
        .animation(.spring(duration: Metrics.Onboarding.pageAnimation), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
