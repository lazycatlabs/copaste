import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Whether this Mac has seen the welcome window's introduction. Per Mac, so it lives in `AppDefaults.store`.
nonisolated enum Onboarding {
    static let storageKey = "onboardingSeen"
    /// Posted when the global shortcut is pressed while there's no vault yet, so the introduction can react to it.
    static let shortcutPressed = Notification.Name("com.lazycatlabs.recopy.onboardingShortcut")

    static var isSeen: Bool {
        get { AppDefaults.store.bool(forKey: storageKey) }
        set { AppDefaults.store.set(newValue, forKey: storageKey) }
    }
}

nonisolated enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome, shortcut, sync, organize

    var id: String { String(describing: self) }
}

/// Which step is shown, and the "try the shortcut" demo: the keys held right now and whether the whole
/// combination was pressed.
@Observable
final class OnboardingModel {
    private(set) var step = OnboardingStep.welcome
    /// Which way the steps slide.
    private(set) var movesForward = true
    private(set) var heldModifiers: NSEvent.ModifierFlags = []
    private(set) var triedShortcut = false
    let binding: HotKeyBinding

    init(binding: HotKeyBinding = HotKeyStore.shared.binding) {
        self.binding = binding
    }

    var isLastStep: Bool { step == OnboardingStep.allCases.last }

    func go(to target: OnboardingStep) {
        movesForward = target.rawValue > step.rawValue
        step = target
    }

    func next() {
        if let following = OnboardingStep(rawValue: step.rawValue + 1) { go(to: following) }
    }

    func back() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { go(to: previous) }
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
        if step != .shortcut { go(to: .shortcut) }
    }

    /// Arrow keys turn the steps; the shortcut lights its caps. Returns whether the event was used.
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
