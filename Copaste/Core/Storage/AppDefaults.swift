import Foundation

/// Per-Mac preferences (vault bookmark, shortcuts, text size, window position).
/// End-to-end test runs get their own store, so they never change the user's.
nonisolated enum AppDefaults {
    // UserDefaults is thread-safe; the SDK just doesn't mark it Sendable.
    nonisolated(unsafe) static let store: UserDefaults = {
        #if DEBUG
        if E2EMode.isActive, let defaults = UserDefaults(suiteName: E2EMode.defaultsSuite) {
            if E2EMode.startsFresh { defaults.removePersistentDomain(forName: E2EMode.defaultsSuite) }
            return defaults
        }
        #endif
        return .standard
    }()
}

#if DEBUG
/// Launch flags the E2E tests (CopasteUITests) pass. Debug builds only.
nonisolated enum E2EMode {
    static let defaultsSuite = "com.lazycatlabs.copaste.e2e"
    static let notification = Notification.Name("com.lazycatlabs.copaste.e2e")
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains("-e2e") }
    /// Keeps the preferences of the previous run, e.g. to check the window position is remembered.
    static var startsFresh: Bool { !arguments.contains("-e2eKeepDefaults") }
    /// Leaves the centering guides on screen after a drag, so a screenshot can show them.
    static var keepsGuides: Bool { arguments.contains("-e2eGuides") }
    /// What to open at launch: "panel", "panel:image", "settings" or "annotate".
    static var openCommand: String? {
        arguments.firstIndex(of: "-e2eOpen").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
}
#endif
