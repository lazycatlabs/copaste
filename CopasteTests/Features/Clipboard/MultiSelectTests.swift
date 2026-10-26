import AppKit
import Foundation
import Testing
@testable import Copaste

@MainActor
struct MultiSelectTests {
    private func makeSession() -> (ClipboardSession, NSPasteboard, URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let board = NSPasteboard(name: .init(UUID().uuidString))
        return (ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: board)), board, root)
    }

    @Test func joinsTextButNotImages() {
        let date = Date.now
        let text = ClipItem(kind: .text, text: "a", hash: "1", firstCopied: date, lastCopied: date)
        let link = ClipItem(kind: .link, text: "https://apple.com", hash: "2", firstCopied: date, lastCopied: date)
        let image = ClipItem(kind: .image, blob: "x.png", hash: "3", firstCopied: date, lastCopied: date)
        #expect(ClipUseCases.joinedText([text, link]) == "a\nhttps://apple.com")
        #expect(ClipUseCases.joinedText([text, image]) == nil)
    }

    @Test func clicksMarkEntriesInListOrder() throws {
        let (session, board, root) = makeSession()
        defer { try? FileManager.default.removeItem(at: root) }
        for text in ["one", "two", "three"] { session.handle(Capture(content: .text(text))) }
        let model = ClipboardViewModel()
        let visible = model.visibleItems(of: session)
        #expect(visible.count == 3)

        model.click(visible[0].id, in: session)
        model.click(visible[2].id, shift: true, in: session)
        #expect(model.chosen(in: session).map(\.id) == visible.map(\.id))

        model.click(visible[1].id, command: true, in: session)
        #expect(model.chosen(in: session).map(\.id) == [visible[0].id, visible[2].id])

        session.copy(model.chosen(in: session))
        #expect(board.string(forType: .string) == "\(visible[0].text ?? "")\n\(visible[2].text ?? "")")

        model.click(visible[1].id, in: session)
        #expect(model.chosen(in: session).map(\.id) == [visible[1].id])
    }

    @Test func shiftArrowRangeShrinksWhenReversed() {
        let (session, _, root) = makeSession()
        defer { try? FileManager.default.removeItem(at: root) }
        for text in ["one", "two", "three"] { session.handle(Capture(content: .text(text))) }
        let model = ClipboardViewModel()
        let visible = model.visibleItems(of: session)
        model.click(visible[0].id, in: session)
        model.moveSelection(by: 1, extending: true, in: session)
        model.moveSelection(by: 1, extending: true, in: session)
        #expect(model.chosen(in: session).count == 3)
        model.moveSelection(by: -1, extending: true, in: session)
        #expect(model.chosen(in: session).map(\.id) == [visible[0].id, visible[1].id])
        model.moveSelection(by: 1, extending: false, in: session)
        #expect(model.markedIDs.isEmpty, "A plain arrow ends the range")
    }

    @Test func unpickingWithCommandKeepsSelectionOnAPickedEntry() {
        let (session, _, root) = makeSession()
        defer { try? FileManager.default.removeItem(at: root) }
        for text in ["one", "two"] { session.handle(Capture(content: .text(text))) }
        let model = ClipboardViewModel()
        let visible = model.visibleItems(of: session)
        model.click(visible[0].id, in: session)
        model.click(visible[1].id, command: true, in: session)
        model.click(visible[1].id, command: true, in: session)
        #expect(model.chosen(in: session).map(\.id) == [visible[0].id])
        #expect(model.selected(in: session)?.id == visible[0].id)
    }

    @Test func copyingSeveralSkipsImagesWhoseFileIsGone() throws {
        let (session, board, root) = makeSession()
        defer { try? FileManager.default.removeItem(at: root) }
        var messages: [String] = []
        session.onToast = { messages.append($0) }
        session.handle(Capture(content: .text("kept")))
        let text = try #require(session.items.first)
        let date = Date.now
        let missing = ClipItem(kind: .image, blob: "blobs/gone.png", hash: "gone", firstCopied: date, lastCopied: date)
        session.copy([text, missing])
        #expect(board.string(forType: .string) == "kept")
        #expect(messages.last == L(.toastCopiedMany(1)))
    }
}
