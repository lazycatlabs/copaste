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

@MainActor
struct UniversalClipboardTests {
    @Test func savesItemsFromOtherDevicesUnlessTurnedOff() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        let session = ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: pasteboard))
        func copyFromPhone(_ text: String) {
            pasteboard.declareTypes([.string, SystemPasteboard.universalClipboardType], owner: nil)
            pasteboard.setString(text, forType: .string)
            pasteboard.setData(Data(), forType: SystemPasteboard.universalClipboardType)
        }

        copyFromPhone("from iPhone")
        // The clipboard is polled; a busy CI machine can take a few polls to record it.
        for _ in 0..<50 where session.items.first?.text != "from iPhone" {
            try await Task.sleep(for: .seconds(0.2))
        }
        #expect(session.items.first?.text == "from iPhone")
        #expect(session.items.first?.sourceName == L(.universalClipboardSource))

        session.settings.saveUniversalClipboard = false
        copyFromPhone("not saved")
        try await Task.sleep(for: .seconds(1.5))
        #expect(!session.items.contains { $0.text == "not saved" })
    }
}

@MainActor
struct ClipGroupTests {
    @Test func groupsAreSavedAndDeletingOneKeepsItsEntries() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let pasteboard = SystemPasteboard(pasteboard: NSPasteboard(name: .init(UUID().uuidString)))
        let session = ClipboardSession(root: root, pasteboard: pasteboard)
        session.importClip(.text("hello"), source: "Test", copiedAt: .now)
        let item = try #require(session.items.first)

        let work = session.addGroup(named: "Work")
        #expect(session.addGroup(named: "Work").name == "Work 2")
        session.setGroup(work.id, for: item)

        let reopened = ClipboardSession(root: root, pasteboard: pasteboard)
        #expect(reopened.settings.groups.map(\.name) == ["Work", "Work 2"])
        #expect(reopened.items.first?.groupID == work.id)

        session.deleteGroup(work)
        #expect(session.settings.groups.map(\.name) == ["Work 2"])
        #expect(session.items.count == 1)
        #expect(session.items.first?.groupID == nil)
    }
}
