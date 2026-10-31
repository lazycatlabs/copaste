import Foundation

/// A guess at what language copied code is in. Names a Markdown code fence, and Paste Special shows it.
nonisolated enum CodeLanguage: String, CaseIterable, Sendable {
    case json, html, xml, swift, kotlin, java, python, javascript, go, rust, c, sql, css, shell
    /// Code, but no language stood out.
    case other

    /// The tag after a Markdown code fence's backticks; none for `.other`.
    var fenceTag: String { self == .other ? "" : rawValue }

    /// Language names stay the same in every language; `.other` has none.
    var name: String? {
        switch self {
        case .json, .html, .xml, .sql, .css: rawValue.uppercased()
        case .javascript: "JavaScript"
        case .c: "C/C++"
        case .other: nil
        default: rawValue.capitalized
        }
    }
}

/// How Paste Special rewrites the text itself.
nonisolated enum TextReformat: String, CaseIterable, Identifiable, Sendable {
    /// Unchanged.
    case original
    /// Common indentation, trailing spaces and runs of blank lines removed.
    case tidy
    /// JSON indented two spaces, keys kept in their order.
    case prettyJSON
    /// JSON on one line, without spaces.
    case minifyJSON

    var id: String { rawValue }

    var isJSON: Bool { self == .prettyJSON || self == .minifyJSON }
}

/// How the text reaches the other app.
nonisolated enum TextPasteStyle: String, CaseIterable, Identifiable, Sendable {
    /// Plain text.
    case plain
    /// Wrapped in a Markdown code fence, for chats, issues and Markdown editors.
    case codeBlock
    /// Rich text in a monospaced font (plain text too), for Notes, Mail, Pages and web editors.
    case monospaced

    var id: String { rawValue }
}

/// What Paste Special does with text.
nonisolated struct TextPasteOptions: Hashable, Sendable {
    var reformat = TextReformat.tidy
    var style = TextPasteStyle.plain

    /// Valid JSON is shown indented; other code goes in a code block; prose is tidied.
    static func defaults(for language: CodeLanguage?) -> TextPasteOptions {
        switch language {
        case .json: TextPasteOptions(reformat: .prettyJSON, style: .plain)
        case .some: TextPasteOptions(reformat: .tidy, style: .codeBlock)
        case nil: TextPasteOptions(reformat: .tidy, style: .plain)
        }
    }
}
