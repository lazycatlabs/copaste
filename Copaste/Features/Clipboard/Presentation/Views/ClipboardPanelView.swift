import SwiftUI

/// The floating clipboard window: search and type filter on top, the history on the left, the selected entry on the right.
struct ClipboardPanelView: View {
    @Environment(ClipboardSession.self) private var session
    @Bindable var model: ClipboardViewModel
    let perform: (ClipAction, ClipItem) -> Void
    /// A single click copies the entry and keeps the window open.
    let copy: (ClipItem) -> Void
    @FocusState private var searchFocused: Bool

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
        .frame(width: Metrics.Panel.size.width, height: Metrics.Panel.size.height)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { toast }
        .overlay(alignment: .bottomTrailing) { actionsMenu }
        // The panel has a (hidden) title bar; without this its height would push the search field down.
        .ignoresSafeArea()
        .animation(.snappy, value: model.toast)
        .onAppear { searchFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.xl) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L(.searchPlaceholder), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.Panel.searchFont * TextScale.shared.factor))
                .focused($searchFocused)
                .onChange(of: model.query) { model.selectedID = nil }
                .accessibilityIdentifier("panel.search")
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
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .accessibilityIdentifier("panel.filter")
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xl + Spacing.sm)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: List

    private var list: some View {
        let sections = model.sections(of: session)
        let selectedID = model.selected(in: session)?.id
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.0) { section, items in
                        Text(section.title)
                            .font(.scaled(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xs)
                        ForEach(items) { item in
                            row(item, isSelected: item.id == selectedID).id(item.id)
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

    private func row(_ item: ClipItem, isSelected: Bool) -> some View {
        ClipRowView(item: item, query: model.query)
            .padding(.horizontal, Spacing.md)
            .frame(height: Metrics.Panel.rowHeight * TextScale.shared.factor)
            .background(isSelected ? Color.primary.opacity(Opacity.fill) : .clear, in: .rect(cornerRadius: Radius.md))
            .contentShape(.rect)
            .onTapGesture(count: 2) { perform(.paste, item) }
            .onTapGesture {
                model.selectedID = item.id
                copy(item)
            }
            .contextMenu {
                ForEach(ClipAction.available(for: item)) { action in
                    Button(action.title(for: item), systemImage: action.symbolName) { perform(action, item) }
                }
            }
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
            Text(session.isPaused ? L(.statusPaused) : L(.appName)).font(.scaled(.callout)).foregroundStyle(.secondary)
            Spacer()
            if let item = model.selected(in: session) {
                let primary: ClipAction = session.settings.pasteDirectly ? .paste : .copy
                footerButton(primary.title(for: item), keys: ["↩"]) { perform(primary, item) }
                    .accessibilityIdentifier("panel.primary")
                footerButton(L(.actionsTitle), keys: ["⌘", "K"]) { model.showsActions.toggle() }
                    .accessibilityIdentifier("panel.actions")
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.md)
    }

    private func footerButton(_ title: String, keys: [String], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                ForEach(keys, id: \.self) { KeyCap(text: $0) }
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
    }

    // MARK: Toast

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.scaled(.callout))
                .lineLimit(1)
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.md)
                .background(.thickMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(.primary.opacity(Opacity.fill)))
                .shadow(radius: Spacing.md)
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
                            Label(action.title(for: item), systemImage: action.symbolName)
                            Spacer()
                            if let shortcut = action.shortcut { KeyCap(text: shortcut) }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(action == .delete ? Color.red : .primary)
                }
            }
            .padding(Spacing.sm)
            .frame(width: Metrics.Panel.actionsWidth)
            .background(.thickMaterial, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.fill)))
            .shadow(radius: Spacing.xl)
            .padding(.trailing, Spacing.xxl)
            .padding(.bottom, Spacing.hero + Spacing.xl)
            .accessibilityIdentifier("panel.actionsMenu")
        }
    }
}
