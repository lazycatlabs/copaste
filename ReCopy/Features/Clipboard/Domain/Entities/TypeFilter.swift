import Foundation

/// The clipboard window's type filter: one kind of entry, or text entries that are code.
nonisolated enum TypeFilter: Hashable, Sendable {
    case kind(ClipKind)
    case code

    /// The menu's order: Code right after Text.
    static let all: [TypeFilter] = ClipKind.allCases.flatMap { $0 == .text ? [.kind($0), .code] : [.kind($0)] }

    var title: String {
        switch self {
        case let .kind(kind): kind.title
        case .code: L(.kindCode)
        }
    }

    var symbolName: String {
        switch self {
        case let .kind(kind): kind.symbolName
        case .code: TypeFilter.codeSymbol
        }
    }

    static let codeSymbol = "chevron.left.forwardslash.chevron.right"

    /// Whether the entry passes. `isCode` says whether a text entry is code (worked out by the session, which caches it).
    func matches(_ item: ClipItem, isCode: (ClipItem) -> Bool) -> Bool {
        switch self {
        case let .kind(kind): item.kind == kind
        case .code: item.kind == .text && isCode(item)
        }
    }
}
