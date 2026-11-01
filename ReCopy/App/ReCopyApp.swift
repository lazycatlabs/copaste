import SwiftUI

@main
struct ReCopyApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra(L(.appName), image: "MenuBarIcon") {
            MacMenu(delegate: delegate)
        }
    }
}
