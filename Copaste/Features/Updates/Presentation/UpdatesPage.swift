import AppKit
import OSLog
import SwiftUI

/// Settings › Updates: whether a newer Copaste is out, and what changed in each version.
/// Checks when the page opens and on "Check for Updates"; nothing runs in the background.
struct UpdatesPage: View {
    private enum Status: Equatable {
        case checking, upToDate, failed
        case available(AppRelease)
    }

    @State private var status = Status.checking
    @State private var releases: [AppRelease] = []
    private let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    var body: some View {
        SettingsSection(L(.settingsUpdates), footer: L(.updateBrewHint)) {
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
        SettingsSection(L(.changelogTitle)) {
            Link(L(.changelogOnGitHub), destination: GitHubReleasesDataSource.releasesPage).font(.scaled(.callout))
        } content: {
            ForEach(releases) { release in
                ReleaseNotesView(release: release, isInstalled: release.version == current)
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

/// One version's notes: "### Heading" lines in bold, "- " lines as bullets, inline Markdown (bold, code) kept.
private struct ReleaseNotesView: View {
    let release: AppRelease
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Text(release.version).font(.scaled(.title3, weight: .semibold))
                if isInstalled {
                    Text(.changelogInstalled)
                        .font(.scaled(.caption, weight: .medium))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.accentColor.opacity(Opacity.strong), in: .capsule)
                }
                Spacer()
                if let date = release.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.scaled(.callout)).foregroundStyle(.secondary)
                }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in line }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.release.\(release.version)")
    }

    private var lines: [AnyView] {
        release.notes.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                return AnyView(Text(Self.markdown(title)).font(.scaled(.body, weight: .semibold)).padding(.top, Spacing.xs))
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                return AnyView(HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("•").foregroundStyle(.secondary)
                    Text(Self.markdown(String(line.dropFirst(2)))).fixedSize(horizontal: false, vertical: true)
                }
                .font(.scaled(.body)))
            }
            return AnyView(Text(Self.markdown(line)).font(.scaled(.body)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true))
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
