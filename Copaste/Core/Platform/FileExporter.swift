import AppKit
import UniformTypeIdentifiers

/// Saves data to a file the user picks.
enum FileExporter {
    static func save(_ data: Data, name: String, type: UTType) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSApp.presentError(error)
        }
    }
}
