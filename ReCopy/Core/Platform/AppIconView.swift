import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// An installed app's icon, looked up by bundle identifier. A generic app icon when it isn't installed.
struct AppIconView: View {
    let bundleID: String?
    var size: CGFloat = Metrics.appIcon

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        guard let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
