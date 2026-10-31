import AppKit
import SwiftUI

extension HistorySettingsPage {
    /// Settings › History › Storage: how much disk the history takes, worked out each time the page opens or entries change.
    struct StorageSection: View {
        let session: ClipboardSession
        @State private var bytes: Int64?

        var body: some View {
            SettingsGroup(L(.storageTitle)) {
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
}
