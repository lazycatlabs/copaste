import SwiftUI

extension ClipboardPage {
    /// The top bar: the search field, then the date, type and group filters. Dragging its background moves the window.
    struct HeaderSection: View {
        @Environment(ClipboardSession.self) private var session
        @Bindable var model: ClipboardViewModel
        var searchFocused: FocusState<Bool>.Binding
        let onDrag: (_ ended: Bool) -> Void
        let manageGroups: () -> Void

        var body: some View {
            HStack(spacing: Spacing.xl) {
                Image(systemName: "magnifyingglass")
                    .font(.scaled(.title2))
                    .foregroundStyle(.secondary)
                TextField(L(.searchPlaceholder), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.scaled(.title2))
                    .focused(searchFocused)
                    .onChange(of: model.query) { model.selectedID = nil }
                    .accessibilityIdentifier("panel.search")
                dateFilter
                kindFilter
                groupFilter
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xl + Spacing.sm)
            .padding(.bottom, Spacing.xl)
            // Behind the bar's controls, so clicks on them still work.
            .background { WindowDragHandle(onDrag: onDrag) }
        }

        private var dateFilter: some View {
            Menu {
                Picker(L(.dateFilterTitle), selection: $model.dateFilter) {
                    ForEach(DateFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                filterLabel(model.dateFilter.title, systemImage: "calendar")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .onChange(of: model.dateFilter) { model.selectedID = nil }
            .accessibilityIdentifier("panel.dateFilter")
        }

        private var kindFilter: some View {
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
                filterLabel(model.kind?.title ?? L(.filterAllTypes), systemImage: "line.3.horizontal.decrease")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .accessibilityIdentifier("panel.filter")
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
                filterLabel(groups.first { $0.id == model.group }?.name ?? L(.groupAll), systemImage: "folder")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .onChange(of: model.group) { model.selectedID = nil }
            .accessibilityIdentifier("panel.groupFilter")
        }

        private func filterLabel(_ title: String, systemImage: String) -> some View {
            Label(title, systemImage: systemImage).font(.scaled(.body)).foregroundStyle(.secondary)
        }
    }
}
