import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Whether this Mac has seen the welcome window's introduction. Per Mac, so it lives in `AppDefaults.store`.
nonisolated enum Onboarding {
    static let storageKey = "onboardingSeen"
    /// Posted when the global shortcut is pressed while there's no vault yet, so the introduction can react to it.
    static let shortcutPressed = Notification.Name("com.lazycatlabs.copaste.onboardingShortcut")

    static var isSeen: Bool {
        get { AppDefaults.store.bool(forKey: storageKey) }
        set { AppDefaults.store.set(newValue, forKey: storageKey) }
    }
}

nonisolated enum OnboardingPage: Int, CaseIterable, Sendable {
    case welcome, shortcut, sync, organize

    var id: String { String(describing: self) }
}

/// Which page is shown, and the "try the shortcut" demo: the keys held right now and whether the whole
/// combination was pressed.
@Observable
final class OnboardingModel {
    private(set) var page = OnboardingPage.welcome
    /// Which way the pages slide.
    private(set) var movesForward = true
    private(set) var heldModifiers: NSEvent.ModifierFlags = []
    private(set) var triedShortcut = false
    let binding: HotKeyBinding

    init(binding: HotKeyBinding = HotKeyStore.shared.binding) {
        self.binding = binding
    }

    var isLastPage: Bool { page == OnboardingPage.allCases.last }

    func go(to target: OnboardingPage) {
        movesForward = target.rawValue > page.rawValue
        page = target
    }

    func next() {
        if let following = OnboardingPage(rawValue: page.rawValue + 1) { go(to: following) }
    }

    func back() {
        if let previous = OnboardingPage(rawValue: page.rawValue - 1) { go(to: previous) }
    }

    /// Whether the key cap at `index` of `binding.keys` is held down. The last cap is the key itself, lit once pressed.
    func isHeld(_ index: Int) -> Bool {
        let keys = binding.keys
        guard index < keys.count - 1 else { return triedShortcut }
        let glyphs: [String: NSEvent.ModifierFlags] = ["⌃": .control, "⌥": .option, "⇧": .shift, "⌘": .command]
        return glyphs[keys[index]].map { heldModifiers.contains($0) } ?? false
    }

    func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        heldModifiers = flags.intersection([.command, .option, .control, .shift])
    }

    func pressedShortcut() {
        triedShortcut = true
        if page != .shortcut { go(to: .shortcut) }
    }

    /// Arrow keys turn the pages; the shortcut lights its caps. Returns whether the event was used.
    func handle(_ event: NSEvent) -> Bool {
        if event.type == .flagsChanged {
            modifiersChanged(event.modifierFlags)
            return false
        }
        if binding.matches(event) {
            pressedShortcut()
            return true
        }
        guard event.modifierFlags.isDisjoint(with: [.command, .option, .control]) else { return false }
        switch Int(event.keyCode) {
        case kVK_RightArrow: next()
        case kVK_LeftArrow: back()
        default: return false
        }
        return true
    }
}

/// The pages before the vault folder picker: what Copaste does, with a shortcut to try and features to hover.
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var model = OnboardingModel()
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: Spacing.section) {
            ZStack {
                page(model.page)
                    .id(model.page)
                    .transition(.asymmetric(
                        insertion: .move(edge: model.movesForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: model.movesForward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            footer
        }
        .animation(.spring(duration: Metrics.Onboarding.pageAnimation), value: model.page)
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
        .onReceive(NotificationCenter.default.publisher(for: Onboarding.shortcutPressed)) { _ in model.pressedShortcut() }
    }

    @ViewBuilder
    private func page(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.section) {
            switch page {
            case .welcome: WelcomePage()
            case .shortcut: ShortcutPage(model: model)
            case .sync: SyncPage()
            case .organize: OrganizePage()
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }

    private var footer: some View {
        HStack {
            Group {
                if model.page == .welcome {
                    Button(L(.onboardingSkip), action: finish).accessibilityIdentifier("onboarding.skip")
                } else {
                    Button(L(.onboardingBack), action: model.back).accessibilityIdentifier("onboarding.back")
                }
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)

            PageDots(current: model.page, select: model.go)

            Button(model.isLastPage ? L(.onboardingStart) : L(.onboardingNext)) {
                if model.isLastPage { finish() } else { model.next() }
            }
            .accessibilityIdentifier(model.isLastPage ? "onboarding.start" : "onboarding.next")
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

// MARK: - Pages

private struct WelcomePage: View {
    @State private var floats = false

    var body: some View {
        AppIconImage(size: Metrics.Onboarding.heroIcon)
            .offset(y: floats ? -Metrics.Onboarding.floatOffset : Metrics.Onboarding.floatOffset)
            .shadow(color: .accentColor.opacity(Opacity.border), radius: Spacing.xxl, y: Spacing.md)
            .onAppear {
                withAnimation(.easeInOut(duration: Metrics.Onboarding.floatDuration).repeatForever()) { floats = true }
            }
        PageText(title: Text(.onboardingTitle), subtitle: Text(.onboardingSubtitle))
    }
}

private struct ShortcutPage: View {
    let model: OnboardingModel

    var body: some View {
        PageText(title: Text(.onboardingShortcutTitle), subtitle: Text(.onboardingShortcut(model.binding.displayText)))
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

private struct SyncPage: View {
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
        PageText(title: Text(.onboardingSyncTitle), subtitle: Text(.onboardingSync))
    }
}

private struct OrganizePage: View {
    private let features: [(symbol: String, title: LocalizedStringResource)] = [
        ("magnifyingglass", .onboardingSearch), ("pin.fill", .onboardingPin), ("folder.fill", .onboardingGroups),
        ("pencil.tip.crop.circle", .actionAnnotate), ("note.text", .onboardingNotes),
    ]

    var body: some View {
        PageText(title: Text(.onboardingOrganizeTitle), subtitle: Text(.onboardingOrganize))
        HStack(spacing: Spacing.md) {
            ForEach(features, id: \.symbol) { FeatureTile(symbol: $0.symbol, title: $0.title) }
        }
        Text(.onboardingOrganizeHint).font(.footnote).foregroundStyle(.tertiary)
    }
}

// MARK: - Pieces

private struct PageText: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(spacing: Spacing.md) {
            title.font(.largeTitle.bold())
            subtitle.foregroundStyle(.secondary)
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

/// One dot per page; the current one is a wider capsule. Clicking a dot opens its page.
private struct PageDots: View {
    let current: OnboardingPage
    let select: (OnboardingPage) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                Button { select(page) } label: {
                    Capsule()
                        .fill(page == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: page == current ? Metrics.Onboarding.activeDotWidth : Metrics.Onboarding.dot,
                               height: Metrics.Onboarding.dot)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.dot.\(page.id)")
            }
        }
    }
}
