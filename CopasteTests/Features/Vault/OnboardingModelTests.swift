import AppKit
import Testing
@testable import Copaste

@MainActor
struct OnboardingModelTests {
    @Test func stepsStopAtBothEnds() {
        let model = OnboardingModel(binding: .standard)
        model.back()
        #expect(model.step == .welcome)
        for _ in OnboardingStep.allCases { model.next() }
        #expect(model.step == .organize)
        #expect(model.isLastStep)
        model.go(to: .shortcut)
        #expect(model.step == .shortcut)
        #expect(!model.movesForward)
    }

    @Test func keyCapsLightUpAsTheShortcutIsPressed() {
        let model = OnboardingModel(binding: .standard)  // ⇧ ⌘ V
        model.modifiersChanged(.shift)
        #expect(model.isHeld(0))
        #expect(!model.isHeld(1))
        #expect(!model.isHeld(2))
        model.go(to: .sync)
        model.pressedShortcut()
        #expect(model.isHeld(2))
        #expect(model.step == .shortcut, "Pressing the shortcut shows its step")
    }
}
