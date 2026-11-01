import AppKit
import SwiftUI

/// ReCopy's own icon, from the bundle's asset catalog (`NSApp.applicationIconImage` can be a blank placeholder in Xcode builds).
struct AppIconImage: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
