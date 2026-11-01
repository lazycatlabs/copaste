import Foundation

/// A published version of ReCopy (a GitHub release). Its notes are that version's CHANGELOG.md section.
nonisolated struct AppRelease: Equatable, Identifiable, Sendable {
    /// "0.1.1", without the tag's "v".
    var version: String
    var notes: String
    var date: Date?
    var url: URL

    var id: String { version }
}

nonisolated enum UpdateUseCases {
    /// Whether `version` comes after `current`, comparing the numbers part by part: 0.1.10 is newer than 0.1.9,
    /// and 1.0 equals 1.0.0. A leading "v" is ignored.
    static func isNewer(_ version: String, than current: String) -> Bool {
        let new = parts(version)
        let old = parts(current)
        for index in 0..<max(new.count, old.count) {
            let lhs = index < new.count ? new[index] : 0
            let rhs = index < old.count ? old[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    /// The newest release after `current`, if there is one.
    static func update(in releases: [AppRelease], current: String) -> AppRelease? {
        releases.filter { isNewer($0.version, than: current) }
            .max { isNewer($1.version, than: $0.version) }
    }

    private static func parts(_ version: String) -> [Int] {
        let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
