import SwiftUI

/// The floating clipboard window: search and type filter on top, the history on the left, the selected entry on the right.
struct ClipboardPage: View {
    @Environment(ClipboardSession.self) private var session
    @Bindable var model: ClipboardViewModel
    let perform: (ClipAction, ClipItem) -> Void
    /// Pastes (or copies) the marked entries together.
    let performMany: ([ClipItem]) -> Void
    /// Dragging the top or bottom bar moves the window; called while dragging, then with `true` at the end.
    let onDrag: (_ ended: Bool) -> Void
    /// Opens Settings › Groups.
    let manageGroups: () -> Void
    @FocusState private var searchFocused: Bool
    @FocusState private var noteFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HeaderSection(model: model, searchFocused: $searchFocused, onDrag: onDrag, manageGroups: manageGroups)
            Divider()
            HStack(spacing: 0) {
                list.frame(width: Metrics.Panel.listWidth)
                Divider()
                DetailSection(model: model, noteFocused: $noteFocused) { searchFocused = true }
            }
            Divider()
            FooterSection(model: model, perform: perform, performMany: performMany, onDrag: onDrag)
        }
        .overlay(alignment: .bottom) { toast }
        .overlay(alignment: .bottomTrailing) {
            ActionsMenuSection(model: model, perform: perform, manageGroups: manageGroups)
        }
        .frame(width: Metrics.Panel.size.width, height: Metrics.Panel.size.height)
        .background {
            // In dark mode the material lets the wallpaper show through behind the text; a dark layer keeps it readable.
            ZStack {
                Rectangle().fill(.regularMaterial)
                if colorScheme == .dark { Color.black.opacity(Opacity.panelDim) }
            }
        }
        .clipShape(.rect(cornerRadius: Metrics.Panel.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Panel.cornerRadius).strokeBorder(.primary.opacity(Opacity.fill)))
        .ignoresSafeArea()
        .animation(.snappy, value: model.toast)
        .onAppear { searchFocused = true }
        .onChange(of: noteFocused) { model.editsNote = noteFocused }
        .onChange(of: model.editsNote) { if !model.editsNote { searchFocused = true } }
    }

    // MARK: List

    private var list: some View {
        let sections = model.sections(of: session)
        let visible = sections.flatMap(\.1)
        let selectedID = (visible.first { $0.id == model.selectedID } ?? visible.first)?.id
        // While ⌘ is held, the first nine entries show the number ⌘1…⌘9 pastes.
        let firstNine = model.showsQuickPasteKeys ? Array(visible.prefix(Metrics.Panel.quickPasteCount)) : []
        let quickKeys = Dictionary(uniqueKeysWithValues: firstNine.enumerated().map { ($1.id, $0 + 1) })
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.0) { section, items in
                        Text(section.title)
                            .font(.scaled(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xs)
                        ForEach(items) { item in
                            row(item, isSelected: item.id == selectedID || model.markedIDs.contains(item.id),
                                quickKey: quickKeys[item.id]).id(item.id)
                        }
                    }
                }
                .padding(Spacing.sm)
            }
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView(L(.emptyTitle), systemImage: "list.clipboard", description: Text(.emptyMessage))
                }
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
                // Picking another entry ends editing the note, so ↩ pastes again.
                if noteFocused { searchFocused = true }
            }
        }
    }

    private func row(_ item: ClipItem, isSelected: Bool, quickKey: Int?) -> some View {
        EntryItem(item: item, query: model.query, quickKey: quickKey)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Metrics.Panel.rowHeight * TextScale.shared.factor)
            .background(isSelected ? Color.primary.opacity(Opacity.fill) : .clear, in: .rect(cornerRadius: Radius.md))
            .contentShape(.rect)
            // Double-click copies and closes the window; a single click only selects.
            .onTapGesture(count: 2) { perform(.copy, item) }
            .onTapGesture { model.click(item.id, in: session) }
            // ⌘-click and ⇧-click pick several entries to paste together.
            .highPriorityGesture(TapGesture().modifiers(.command).onEnded { model.click(item.id, command: true, in: session) })
            .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { model.click(item.id, shift: true, in: session) })
            .contextMenu {
                ForEach(ClipAction.available(for: item)) { action in
                    Button(action.title(for: item), systemImage: action.symbolName) { perform(action, item) }
                }
                Divider()
                Menu(L(.groupMoveTo)) { GroupPicker(item: item, manageGroups: manageGroups) }
            }
    }

    // MARK: Toast

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            ToastLabel(message: message)
                .padding(.bottom, Spacing.hero + Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("panel.toast")
        }
    }
}
