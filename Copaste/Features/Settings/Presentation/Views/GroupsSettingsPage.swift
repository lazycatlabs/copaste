import SwiftUI

struct GroupsSettingsPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsGroup(L(.settingsGroups), footer: L(.settingsGroupsFooter)) {
            Button(L(.groupAdd), systemImage: "plus") { session.addGroup() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.addGroup")
        } content: {
            if session.settings.groups.isEmpty {
                SettingsRow(L(.groupsEmpty), symbol: "folder.badge.questionmark") { EmptyView() }
            }
            ForEach($session.settings.groups) { $group in
                let count = session.items.count { $0.groupID == group.id }
                SettingsRow(L(.groupEntries(count)), symbol: "folder") {
                    TextField(L(.groupNewName), text: $group.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: Metrics.Settings.groupNameWidth)
                        .accessibilityIdentifier("settings.groupName")
                    Button(L(.actionDelete), systemImage: "trash") { session.deleteGroup(group) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}
