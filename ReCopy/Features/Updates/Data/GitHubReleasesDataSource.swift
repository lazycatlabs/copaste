import Foundation

/// ReCopy's releases, from the public GitHub repository's API (no account needed).
nonisolated enum GitHubReleasesDataSource {
    static let releasesPage = URL(string: "https://github.com/lazycatlabs/recopy/releases")!
    private static let api = URL(string: "https://api.github.com/repos/lazycatlabs/recopy/releases?per_page=20")!

    private struct Release: Decodable {
        var tagName: String
        var body: String?
        var publishedAt: Date?
        var htmlUrl: URL
        var draft: Bool
        var prerelease: Bool
    }

    /// Published releases, newest first. Drafts and pre-releases are left out.
    static func fetch() async throws -> [AppRelease] {
        #if DEBUG
        if E2EMode.isActive { return sample }
        #endif
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Release].self, from: data)
            .filter { !$0.draft && !$0.prerelease }
            .map { AppRelease(version: $0.tagName.hasPrefix("v") ? String($0.tagName.dropFirst()) : $0.tagName,
                              notes: $0.body ?? "", date: $0.publishedAt, url: $0.htmlUrl) }
    }

    #if DEBUG
    /// What the E2E tests see instead of the network: a newer version and the installed one.
    private static let sample = [
        AppRelease(version: "9.9.0", notes: "### New\n\n- **Groups**: put entries in groups and filter by them.\n- Hold ⌘ to see ⌘1…⌘9.",
                   date: .now, url: releasesPage),
        AppRelease(version: "0.1.1", notes: "### Fixed\n\n- Settings opened behind other apps.", date: .now, url: releasesPage),
    ]
    #endif
}
