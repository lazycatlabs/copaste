import Foundation
import Observation

/// Search, type filter, selection and toasts for the clipboard window.
@Observable
final class ClipboardViewModel {
    var query = ""
    var kind: ClipKind?
    var selectedID: UUID?
    var showsActions = false
    /// A short confirmation shown at the bottom of the window, e.g. after copying an entry.
    private(set) var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    /// Entries copied while the window is open keep their place until it closes, so the list doesn't jump under the pointer.
    private var frozenDates: [UUID: Date] = [:]

    func sections(of session: ClipboardSession, now: Date = .now) -> [(TimeSection, [ClipItem])] {
        let items = session.items.map { item in
            guard let date = frozenDates[item.id] else { return item }
            var frozen = item
            frozen.lastCopied = date
            return frozen
        }
        return ClipUseCases.sections(ClipUseCases.filter(items, kind: kind, query: query), now: now)
    }

    /// The entries in the order they are shown, for keyboard navigation and ⌘1…⌘9.
    func visibleItems(of session: ClipboardSession) -> [ClipItem] {
        sections(of: session).flatMap(\.1)
    }

    /// The selected entry, with its current details (not the frozen copy used for ordering).
    func selected(in session: ClipboardSession) -> ClipItem? {
        let id = visibleItems(of: session).first { $0.id == selectedID }?.id ?? visibleItems(of: session).first?.id
        return session.items.first { $0.id == id }
    }

    func moveSelection(by offset: Int, in session: ClipboardSession) {
        let visible = visibleItems(of: session)
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.id == selected(in: session)?.id } ?? 0
        selectedID = visible[min(max(current + offset, 0), visible.count - 1)].id
    }

    func keepInPlace(_ item: ClipItem) {
        frozenDates[item.id] = frozenDates[item.id] ?? item.lastCopied
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
        toast = nil
        frozenDates = [:]
    }
}
