import SwiftUI

extension OnboardingPage {
    struct ShortcutSection: View {
        let model: OnboardingModel

        var body: some View {
            Heading(title: Text(.onboardingShortcutTitle), subtitle: Text(.onboardingShortcut(model.binding.displayText)))
            HStack(spacing: Spacing.md) {
                ForEach(Array(model.binding.keys.enumerated()), id: \.offset) { index, key in
                    BigKeyCap(text: key, isHeld: model.isHeld(index))
                }
            }
            Group {
                if model.triedShortcut {
                    Label(L(.onboardingShortcutDone), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: model.triedShortcut)
                        .accessibilityIdentifier("onboarding.shortcutDone")
                } else {
                    Text(.onboardingShortcutTry).foregroundStyle(.secondary)
                }
            }
            .font(.callout.weight(.medium))
            .animation(.spring, value: model.triedShortcut)
        }
    }
}

/// A large key cap that sinks and lights up while held.
private struct BigKeyCap: View {
    let text: String
    let isHeld: Bool

    var body: some View {
        Text(text)
            .font(.title.weight(.semibold))
            .foregroundStyle(isHeld ? Color.white : .primary)
            .padding(.horizontal, Spacing.lg)
            .frame(minWidth: Metrics.Onboarding.keyCap, minHeight: Metrics.Onboarding.keyCap)
            .background(isHeld ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.fill)))
            .scaleEffect(isHeld ? Metrics.Onboarding.keyCapPressedScale : 1)
            .animation(.spring(duration: Metrics.Onboarding.pageAnimation), value: isHeld)
    }
}
