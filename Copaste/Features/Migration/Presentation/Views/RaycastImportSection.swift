import SwiftUI

/// Settings › Import: brings Raycast's clipboard images and rich-text copies into the vault.
struct RaycastImportSection: View {
    let session: ClipboardSession
    @State private var files: [URL] = []
    @State private var confirms = false
    @State private var progress: (done: Int, total: Int)?
    @State private var result: String?

    var body: some View {
        SettingsSection(L(.importTitle), footer: L(.importFooter)) {
            SettingsRow("Raycast", symbol: "square.and.arrow.down.on.square", subtitle: result) {
                if let progress {
                    ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1))) {
                        Text(.importProgress(progress.done, progress.total)).font(.scaled(.caption))
                    }
                    .frame(width: Metrics.Settings.groupNameWidth)
                } else {
                    Button(L(.importFromRaycast), action: prepare)
                        .disabled(!FileManager.default.fileExists(atPath: RaycastClipboardDataSource.folder.path))
                        .accessibilityIdentifier("settings.importRaycast")
                }
            }
        }
        .confirmationDialog(L(.importConfirm(files.count)), isPresented: $confirms) {
            Button(L(.importAction), action: start)
        } message: {
            Text(.importConfirmMessage)
        }
    }

    /// Lists the files first, so the confirmation can say how many there are. Files older than the
    /// "Keep history for" setting are left out: they would be deleted again straight away.
    private func prepare() {
        let cutoff = session.settings.retention.cutoff(from: .now) ?? .distantPast
        files = RaycastClipboardDataSource.importableFiles().filter { RaycastClipboardDataSource.copiedAt($0) >= cutoff }
        result = nil
        if files.isEmpty { result = L(.importNothing) } else { confirms = true }
    }

    private func start() {
        let files = files
        Task {
            var added = 0
            progress = (0, files.count)
            for (index, file) in files.enumerated() {
                if let content = await RaycastClipboardDataSource.capture(of: file),
                   session.importClip(content, source: "Raycast", copiedAt: RaycastClipboardDataSource.copiedAt(file)) {
                    added += 1
                }
                progress = (index + 1, files.count)
            }
            progress = nil
            result = L(.importDone(added, files.count - added))
            await session.recognizeTextInImages()
        }
    }
}
