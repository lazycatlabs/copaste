import SwiftUI

@main
struct CopasteApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra(L(.appName), systemImage: "list.clipboard") {
            MacMenu(delegate: delegate)
        }
    }
    #else
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            IOSRootView().environment(container)
        }
    }
    #endif
}
