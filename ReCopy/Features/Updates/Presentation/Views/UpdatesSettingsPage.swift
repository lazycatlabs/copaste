import AppKit
import OSLog
import SwiftUI

/// Settings › Updates: whether a newer ReCopy is out, and what changed in each version.
/// Checks when the page opens and on "Check for Updates"; nothing runs in the background.
struct UpdatesSettingsPage: View {
    private enum Status: Equatable {
        case checking, upToDate, failed
        case available(AppRelease)
    }

    @State private var status = Status.checking
    @State private var releases: [AppRelease] = []
    private let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    var body: some View {
        SettingsGroup(L(.settingsUpdates), footer: L(.updateBrewHint)) {
            SettingsRow(title, symbol: symbol, subtitle: L(.updateCurrent(current))) {
                HStack {
                    if case let .available(release) = status {
                        Button(L(.updateDownload)) { NSWorkspace.shared.open(release.url) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("settings.updateDownload")
                    }
                    if status == .checking {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(L(.updateCheck)) { Task { await check() } }.accessibilityIdentifier("settings.updateCheck")
                    }
                }
            }
            .accessibilityIdentifier("settings.updateStatus")
        }
        SettingsGroup(L(.changelogTitle)) {
            Link(L(.changelogOnGitHub), destination: GitHubReleasesDataSource.releasesPage).font(.scaled(.callout))
        } content: {
            ForEach(releases) { release in
                ReleaseNotesItem(release: release, isInstalled: release.version == current)
            }
            if releases.isEmpty {
                SettingsRow(L(.changelogUnavailable), symbol: "doc.text") { EmptyView() }
            }
        }
        .task { await check() }
    }

    private var title: String {
        switch status {
        case .checking: L(.updateChecking)
        case .upToDate: L(.updateUpToDate)
        case .failed: L(.updateFailed)
        case let .available(release): L(.updateAvailable(release.version))
        }
    }

    private var symbol: String {
        switch status {
        case .checking: "arrow.triangle.2.circlepath"
        case .upToDate: "checkmark.seal"
        case .failed: "exclamationmark.triangle"
        case .available: "arrow.down.circle"
        }
    }

    private func check() async {
        status = .checking
        do {
            releases = try await GitHubReleasesDataSource.fetch()
            status = UpdateUseCases.update(in: releases, current: current).map(Status.available) ?? .upToDate
        } catch {
            Log.metadata.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            status = .failed
        }
    }
}
