import SwiftUI

/// The floating clipboard window: search and type filter on top, the history on the left, the selected entry on the right.
struct ClipboardPanelView: View {
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                list.frame(width: Metrics.Panel.listWidth)
                Divider()
                detail
            }
            Divider()
            footer
        }
        .overlay(alignment: .bottom) { toast }
        .overlay(alignment: .bottomTrailing) { actionsMenu }
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
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.xl) {
            Image(systemName: "magnifyingglass")
                .font(.scaled(.title2))
                .foregroundStyle(.secondary)
            TextField(L(.searchPlaceholder), text: $model.query)
                .textFieldStyle(.plain)
                .font(.scaled(.title2))
                .focused($searchFocused)
                .onChange(of: model.query) { model.selectedID = nil }
                .accessibilityIdentifier("panel.search")
            Menu {
                Picker(L(.dateFilterTitle), selection: $model.dateFilter) {
                    ForEach(DateFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Label(model.dateFilter.title, systemImage: "calendar").font(.scaled(.body)).foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .onChange(of: model.dateFilter) { model.selectedID = nil }
            .accessibilityIdentifier("panel.dateFilter")
            Menu {
                Picker(L(.filterAllTypes), selection: $model.kind) {
                    Label(L(.filterAllTypes), systemImage: "square.grid.2x2").tag(ClipKind?.none)
                    Divider()
                    ForEach(ClipKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbolName).tag(ClipKind?.some(kind))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(model.kind?.title ?? L(.filterAllTypes), systemImage: "line.3.horizontal.decrease")
                    .font(.scaled(.body)).foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .accessibilityIdentifier("panel.filter")
            groupFilter
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xl + Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .background { dragArea }
    }

    private var groupFilter: some View {
        let groups = session.settings.groups
        return Menu {
            Picker(L(.groupMoveTo), selection: $model.group) {
                Label(L(.groupAll), systemImage: "tray.full").tag(UUID?.none)
                if !groups.isEmpty { Divider() }
                ForEach(groups) { group in
                    Label(group.name, systemImage: "folder").tag(UUID?.some(group.id))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button(L(.groupManage), action: manageGroups)
        } label: {
            Label(groups.first { $0.id == model.group }?.name ?? L(.groupAll), systemImage: "folder")
                .font(.scaled(.body)).foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
        .onChange(of: model.group) { model.selectedID = nil }
        .accessibilityIdentifier("panel.groupFilter")
    }

    /// Behind the bars' controls, so clicks on them still work.
    private var dragArea: some View {
        WindowDragHandle(onDrag: onDrag)
    }

    // MARK: List

    private var list: some View {
        let sections = model.sections(of: session)
        let selectedID = model.selected(in: session)?.id
        // While ⌘ is held, the first nine entries show the number ⌘1…⌘9 pastes.
        let firstNine = model.showsQuickPasteKeys ? Array(sections.flatMap(\.1).prefix(Metrics.Panel.quickPasteCount)) : []
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
            }
        }
    }

    private func row(_ item: ClipItem, isSelected: Bool, quickKey: Int?) -> some View {
        ClipRowView(item: item, query: model.query, quickKey: quickKey)
            .padding(.horizontal, Spacing.md)
            .frame(height: Metrics.Panel.rowHeight * TextScale.shared.factor)
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
                Menu(L(.groupMoveTo)) {
                    Picker(L(.groupMoveTo), selection: groupBinding(for: item)) {
                        Text(.groupNone).tag(UUID?.none)
                        ForEach(session.settings.groups) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button(L(.groupManage), action: manageGroups)
                }
            }
    }

    private func groupBinding(for item: ClipItem) -> Binding<UUID?> {
        Binding { item.groupID } set: { session.setGroup($0, for: item) }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let item = model.selected(in: session) {
            ClipDetailView(item: item)
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            AppIconImage(size: Metrics.appIcon * TextScale.shared.factor)
            Text(session.isPaused ? L(.statusPaused) : L(.appName)).font(.scaled(.body)).foregroundStyle(.secondary)
            Spacer()
            let chosen = model.chosen(in: session)
            if let item = chosen.first {
                let primary: ClipAction = session.settings.pasteDirectly ? .paste : .copy
                let shortcuts = HotKeyStore.shared
                if chosen.count > 1 {
                    let title = primary == .paste ? L(.actionPasteMany(chosen.count)) : L(.actionCopyMany(chosen.count))
                    footerButton(title, keys: shortcuts[.paste].keys) { performMany(chosen) }
                        .accessibilityIdentifier("panel.primary")
                } else {
                    footerButton(primary.title(for: item), keys: shortcuts[.paste].keys) { perform(primary, item) }
                        .accessibilityIdentifier("panel.primary")
                }
                footerButton(L(.actionsTitle), keys: shortcuts[.actions].keys) { model.showsActions.toggle() }
                    .accessibilityIdentifier("panel.actions")
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.md)
        .background { dragArea }
    }

    private func footerButton(_ title: String, keys: [String], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title).font(.scaled(.body, weight: .medium))
                KeyCaps(keys: keys)
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
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

    // MARK: Actions (⌘K)

    @ViewBuilder
    private var actionsMenu: some View {
        if model.showsActions, let item = model.selected(in: session) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ClipAction.available(for: item)) { action in
                    Button {
                        model.showsActions = false
                        perform(action, item)
                    } label: {
                        HStack {
                            Label(action.title(for: item), systemImage: action.symbolName).font(.scaled(.body))
                            Spacer()
                            if let shortcut = action.shortcut { KeyCaps(keys: HotKeyStore.shared[shortcut].keys) }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(action == .delete ? Color.red : .primary)
                }
                Divider().padding(.vertical, Spacing.xs)
                Menu {
                    Picker(L(.groupMoveTo), selection: groupBinding(for: item)) {
                        Text(.groupNone).tag(UUID?.none)
                        ForEach(session.settings.groups) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button(L(.groupManage), action: manageGroups)
                } label: {
                    Label("\(L(.groupMoveTo)): \(session.group(of: item)?.name ?? L(.groupNone))", systemImage: "folder")
                        .font(.scaled(.body))
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .fixedSize()
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .accessibilityIdentifier("panel.actionsGroup")
            }
            .padding(Spacing.sm)
            .frame(width: Metrics.Panel.actionsWidth)
            .background(.thickMaterial, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.fill)))
            .shadow(radius: Spacing.xl)
            .padding(.trailing, Spacing.xxl)
            .padding(.bottom, Spacing.hero + Spacing.xl)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("panel.actionsMenu")
        }
    }
}
