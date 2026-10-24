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
struct ClipboardViewModelTests {
    @Test func copiedEntryKeepsItsPlaceWhileTheWindowIsOpen() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: NSPasteboard(name: .init(UUID().uuidString))))
        session.handle(Capture(content: .text("older")))
        session.handle(Capture(content: .text("newer")))
        let model = ClipboardViewModel()
        let older = try #require(session.items.first { $0.text == "older" })
        model.keepInPlace(older)
        session.copy(older)
        #expect(model.visibleItems(of: session).map(\.text) == ["newer", "older"])
        model.selectedID = older.id
        #expect(model.selected(in: session)?.copyCount == 2)
        model.reset()
        #expect(model.visibleItems(of: session).first?.text == "older")
    }
}
