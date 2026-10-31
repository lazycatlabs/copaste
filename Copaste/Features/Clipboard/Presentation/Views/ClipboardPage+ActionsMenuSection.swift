import SwiftUI

extension ClipboardPage {
    /// The ⌘K menu over the bottom-right corner: the selected entry's actions with their shortcuts, and its group.
    struct ActionsMenuSection: View {
        @Environment(ClipboardSession.self) private var session
        @Bindable var model: ClipboardViewModel
        let perform: (ClipAction, ClipItem) -> Void
        let manageGroups: () -> Void

        var body: some View {
            if model.showsActions, let item = model.selected(in: session) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ClipAction.available(for: item)) { action in
                        actionButton(action, for: item)
                    }
                    Divider().padding(.vertical, Spacing.xs)
                    Menu {
                        GroupPicker(item: item, manageGroups: manageGroups)
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

        private func actionButton(_ action: ClipAction, for item: ClipItem) -> some View {
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
    }

    /// "Move to Group" choices for an entry, then Manage Groups. Shared by the context menu and the actions menu.
    struct GroupPicker: View {
        @Environment(ClipboardSession.self) private var session
        let item: ClipItem
        let manageGroups: () -> Void

        var body: some View {
            Picker(L(.groupMoveTo), selection: Binding { item.groupID } set: { session.setGroup($0, for: item) }) {
                Text(.groupNone).tag(UUID?.none)
                ForEach(session.settings.groups) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            .pickerStyle(.inline)
            Divider()
            Button(L(.groupManage), action: manageGroups)
        }
    }
}
