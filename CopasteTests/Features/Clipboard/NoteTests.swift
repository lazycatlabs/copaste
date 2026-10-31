import AppKit
import Foundation
import Testing
@testable import Copaste

@MainActor
struct NoteTests {
    private func makeSession() -> (ClipboardSession, NSPasteboard, URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let board = NSPasteboard(name: .init(UUID().uuidString))
        return (ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: board)), board, root)
    }

    @Test func notesAreSavedSearchableAndRemovedWhenEmpty() throws {
        let (session, _, root) = makeSession()
        defer { try? FileManager.default.removeItem(at: root) }
        session.handle(Capture(content: .text("hello")))
        let item = try #require(session.items.first)

        session.setNote("for the invoice", for: item)
        #expect(session.items.first?.note == "for the invoice")
        #expect(ClipUseCases.filter(session.items, type: nil, query: "invoice").count == 1)
        #expect(FileClipRepository(root: root).loadAll().first?.note == "for the invoice")

        session.setNote("  ", for: item)
        #expect(session.items.first?.note == nil)
    }
}
