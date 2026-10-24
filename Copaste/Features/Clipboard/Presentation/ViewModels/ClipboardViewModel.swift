import Foundation
import Observation

/// Search, type filter and selection over the session's entries. Shared by the macOS window and the iOS list.
@Observable
final class ClipboardViewModel {
    var query = ""
    var kind: ClipKind?
    var selectedID: UUID?
    var showsActions = false

    func sections(of session: ClipboardSession, now: Date = .now) -> [(TimeSection, [ClipItem])] {
        ClipUseCases.sections(ClipUseCases.filter(session.items, kind: kind, query: query), now: now)
    }

    /// The entries in the order they are shown, for keyboard navigation and ⌘1…⌘9.
    func visibleItems(of session: ClipboardSession) -> [ClipItem] {
        sections(of: session).flatMap(\.1)
    }

    func selected(in session: ClipboardSession) -> ClipItem? {
        let visible = visibleItems(of: session)
        return visible.first { $0.id == selectedID } ?? visible.first
    }

    func moveSelection(by offset: Int, in session: ClipboardSession) {
        let visible = visibleItems(of: session)
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.id == selected(in: session)?.id } ?? 0
        selectedID = visible[min(max(current + offset, 0), visible.count - 1)].id
    }

    func reset() {
        query = ""
        selectedID = nil
        showsActions = false
    }
}
