import AppKit
import Foundation
import Testing
@testable import ReCopy

@MainActor
struct RaycastImportTests {
    @Test func importsImagesAndRichTextOnce() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let vault = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.removeItem(at: vault)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("<p>Hello <b>ReCopy</b></p>".utf8).write(to: folder.appending(path: "file-a.html"))
        try Data("https://lazycatlabs.com".utf8).write(to: folder.appending(path: "file-b.txt"))
        try Data("ignored".utf8).write(to: folder.appending(path: "file-c.pdf"))
        let image = NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }
        try #require(image.pngRepresentation).write(to: folder.appending(path: "file-d.png"))

        let files = RaycastClipboardDataSource.importableFiles(in: folder)
        #expect(files.count == 3)

        let session = ClipboardSession(root: vault, pasteboard: SystemPasteboard(pasteboard: NSPasteboard(name: .init(UUID().uuidString))))
        for _ in 0..<2 {
            for file in files {
                let content = try #require(await RaycastClipboardDataSource.capture(of: file))
                session.importClip(content, source: "Raycast", copiedAt: RaycastClipboardDataSource.copiedAt(file))
            }
        }
        #expect(session.items.count == 3)
        #expect(Set(session.items.map(\.kind)) == [.text, .link, .image])
        #expect(session.items.contains { $0.text?.contains("Hello ReCopy") == true })
        #expect(session.items.allSatisfy { $0.sourceName == "Raycast" && $0.copyCount == 1 })
    }
}
