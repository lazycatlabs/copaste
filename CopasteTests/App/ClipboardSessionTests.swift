import AppKit
import Foundation
import Testing
@testable import Copaste

@MainActor
struct ClipboardSessionTests {
    @Test func annotatedImageBecomesANewEntry() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: NSPasteboard(name: .init(UUID().uuidString))))
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let png = try #require(image.pngRepresentation)
        session.addImage(png, width: 4, height: 4)
        let item = try #require(session.items.first)
        #expect(item.kind == .image)
        #expect(item.sourceName == "Copaste")
        #expect(session.blobURL(item.blob).map { FileManager.default.fileExists(atPath: $0.path) } == true)
    }
}

@MainActor
struct ClipboardToastTests {
    @Test func copyAndPasteAnnounceUnlessToastsAreOff() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: NSPasteboard(name: .init(UUID().uuidString))))
        var messages: [String] = []
        session.onToast = { messages.append($0) }

        session.handle(Capture(content: .text("hello")))
        let item = try #require(session.items.first)
        session.preparePaste(item)
        #expect(messages == [L(.toastCopied("hello")), L(.toastPasted("hello"))])

        session.settings.showToasts = false
        session.copy(item)
        #expect(messages.count == 2)
    }
}
