import Foundation
import Observation

/// Search, type filter, selection and toasts for the clipboard window.
@Observable
final class ClipboardViewModel {
    var query = ""
    var kind: ClipKind?
    var dateFilter = DateFilter.anyTime
    /// Only entries in this group; nil for all.
    var group: UUID?
    /// Shown while ⌘ is held: which entry ⌘1…⌘9 pastes.
    var showsQuickPasteKeys = false
    var selectedID: UUID?
    /// Entries picked with ⌘-click, ⇧-click or ⇧↑↓, to paste together. Empty: only the selected entry.
    var markedIDs: Set<UUID> = []
    var showsActions = false
    /// A short confirmation shown at the bottom of the window, e.g. after copying an entry.
    private(set) var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func sections(of session: ClipboardSession, now: Date = .now) -> [(TimeSection, [ClipItem])] {
        let group = session.settings.groups.contains { $0.id == group } ? group : nil
        let items = ClipUseCases.filter(session.items, kind: kind, query: query, created: dateFilter, group: group, now: now)
        return ClipUseCases.sections(items, now: now)
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

    /// What ↩ pastes: the marked entries in list order, or the selected one.
    func chosen(in session: ClipboardSession) -> [ClipItem] {
        let marked = visibleItems(of: session).filter { markedIDs.contains($0.id) }
        return marked.isEmpty ? selected(in: session).map { [$0] } ?? [] : marked
    }

    /// A click on a row: ⌘ adds or removes it, ⇧ marks everything from the selected entry to it, a plain click selects it alone.
    func click(_ id: UUID, command: Bool = false, shift: Bool = false, in session: ClipboardSession) {
        let current = selected(in: session)?.id
        if command {
            if markedIDs.isEmpty, let current { markedIDs.insert(current) }
            if markedIDs.contains(id), markedIDs.count > 1 { markedIDs.remove(id) } else { markedIDs.insert(id) }
        } else if shift, let current {
            let ids = visibleItems(of: session).map(\.id)
            if let from = ids.firstIndex(of: current), let to = ids.firstIndex(of: id) {
                markedIDs.formUnion(ids[min(from, to)...max(from, to)])
            }
        } else {
            markedIDs = []
        }
        selectedID = id
    }

    /// ⇧↑↓: moves the selection and marks the entries passed.
    func extendSelection(by offset: Int, in session: ClipboardSession) {
        if let current = selected(in: session)?.id { markedIDs.insert(current) }
        moveSelection(by: offset, in: session)
        if let selectedID { markedIDs.insert(selectedID) }
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(Metrics.Panel.toastDuration))
            if !Task.isCancelled { toast = nil }
        }
    }

    func reset() {
        query = ""
        selectedID = nil
        markedIDs = []
        showsActions = false
        showsQuickPasteKeys = false
        toast = nil
    }
}
