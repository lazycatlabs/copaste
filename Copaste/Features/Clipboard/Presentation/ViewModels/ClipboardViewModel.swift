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
        showsActions = false
        showsQuickPasteKeys = false
        toast = nil
    }
}
