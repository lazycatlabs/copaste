import AppKit
import SwiftUI

/// Settings › History › Storage: how much disk the history takes, worked out each time the page opens or entries change.
struct StorageSection: View {
    let session: ClipboardSession
    @State private var bytes: Int64?

    var body: some View {
        SettingsSection(L(.storageTitle)) {
            SettingsRow(L(.storageUsed), symbol: "internaldrive", subtitle: L(.storageEntries(session.items.count))) {
                Text(bytes.map(Self.format) ?? L(.storageCalculating))
                    .font(.scaled(.body, weight: .semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("settings.storageUsed")
                Button(L(.vaultReveal)) { NSWorkspace.shared.activateFileViewerSelecting([session.root]) }
            }
        }
        .task(id: session.items.count) { bytes = await session.totalStorageSize() }
    }

    static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}

/// Settings › History › Delete Entries: removes entries by when they were last copied, type and group, with a live
/// count and size of what would go, and a confirmation.
struct DeleteEntriesSection: View {
    let session: ClipboardSession
    @State private var criteria = CleanupCriteria()
    @State private var bytes: Int64?
    @State private var confirms = false

    private var matches: [ClipItem] { ClipUseCases.matching(session.items, criteria) }

    var body: some View {
        let matches = matches
        SettingsSection(L(.cleanupTitle), footer: L(.cleanupFooter)) {
            SettingsRow(L(.cleanupPeriod), symbol: "calendar") {
                Picker(L(.cleanupPeriod), selection: $criteria.period) {
                    ForEach(CleanupPeriod.allCases) { period in
                        if period.startsOlderSection { Divider() }
                        Text(period.title).tag(period)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("settings.cleanupPeriod")
            }
            SettingsRow(L(.cleanupType), symbol: "line.3.horizontal.decrease") {
                Picker(L(.cleanupType), selection: $criteria.kind) {
                    Label(L(.filterAllTypes), systemImage: "square.grid.2x2").tag(ClipKind?.none)
                    Divider()
                    ForEach(ClipKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbolName).tag(ClipKind?.some($0)) }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("settings.cleanupType")
            }
            if !session.settings.groups.isEmpty {
                SettingsRow(L(.cleanupGroup), symbol: "folder") {
                    Picker(L(.cleanupGroup), selection: $criteria.group) {
                        Text(.groupAll).tag(UUID?.none)
                        Divider()
                        ForEach(session.settings.groups) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            SettingsRow(L(.cleanupIncludePinned), symbol: "pin") {
                Toggle(L(.cleanupIncludePinned), isOn: $criteria.includePinned).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(L(.cleanupMatches(matches.count)), symbol: "trash", subtitle: bytes.map(StorageSection.format)) {
                Button(L(.cleanupDelete), role: .destructive) { confirms = true }
                    .disabled(matches.isEmpty)
                    .accessibilityIdentifier("settings.cleanupDelete")
                    .confirmationDialog(L(.cleanupConfirm(matches.count)), isPresented: $confirms) {
                        Button(L(.cleanupDeleteNow), role: .destructive) { session.delete(matching: criteria) }
                    } message: {
                        Text(.cleanupConfirmMessage)
                    }
            }
            .accessibilityIdentifier("settings.cleanupMatches")
        }
        .task(id: TaskKey(criteria: criteria, count: session.items.count)) {
            bytes = await session.storageSize(of: matches)
        }
    }

    /// Re-measures when the filters or the history change.
    private struct TaskKey: Equatable {
        var criteria: CleanupCriteria
        var count: Int
    }
}
