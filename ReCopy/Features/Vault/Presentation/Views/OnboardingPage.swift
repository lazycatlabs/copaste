import AppKit
import SwiftUI

/// The steps before the vault folder picker: what ReCopy does, with a shortcut to try and features to hover.
struct OnboardingPage: View {
    var onFinish: () -> Void
    @State private var model = OnboardingModel()
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: Spacing.section) {
            ZStack {
                step(model.step)
                    .id(model.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: model.movesForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: model.movesForward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            footer
        }
        .animation(.spring(duration: Metrics.Onboarding.pageAnimation), value: model.step)
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
        .onReceive(NotificationCenter.default.publisher(for: Onboarding.shortcutPressed)) { _ in model.pressedShortcut() }
    }

    @ViewBuilder
    private func step(_ step: OnboardingStep) -> some View {
        VStack(spacing: Spacing.section) {
            switch step {
            case .welcome: WelcomeSection()
            case .shortcut: ShortcutSection(model: model)
            case .sync: SyncSection()
            case .organize: OrganizeSection()
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(step.id)")
    }

    private var footer: some View {
        HStack {
            Group {
                if model.step == .welcome {
                    Button(L(.onboardingSkip), action: finish).accessibilityIdentifier("onboarding.skip")
                } else {
                    Button(L(.onboardingBack), action: model.back).accessibilityIdentifier("onboarding.back")
                }
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)

            StepDots(current: model.step, select: model.go)

            Button(model.isLastStep ? L(.onboardingStart) : L(.onboardingNext)) {
                if model.isLastStep { finish() } else { model.next() }
            }
            .accessibilityIdentifier(model.isLastStep ? "onboarding.start" : "onboarding.next")
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func finish() {
        Onboarding.isSeen = true
        onFinish()
    }

    private func startListening() {
        guard keyMonitor == nil else { return }
        let model = model
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            model.handle(event) ? nil : event
        }
    }

    private func stopListening() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}

extension OnboardingPage {
    /// A step's title and explanation.
    struct Heading: View {
        let title: Text
        let subtitle: Text

        var body: some View {
            VStack(spacing: Spacing.md) {
                title.font(.largeTitle.bold())
                subtitle.foregroundStyle(.secondary)
            }
        }
    }
}

/// One dot per step; the current one is a wider capsule. Clicking a dot opens its step.
private struct StepDots: View {
    let current: OnboardingStep
    let select: (OnboardingStep) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Button { select(step) } label: {
                    Capsule()
                        .fill(step == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: step == current ? Metrics.Onboarding.activeDotWidth : Metrics.Onboarding.dot,
                               height: Metrics.Onboarding.dot)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.dot.\(step.id)")
            }
        }
    }
}
