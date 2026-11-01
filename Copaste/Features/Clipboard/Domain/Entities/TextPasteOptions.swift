import Foundation

/// A guess at what language copied code is in. Names a Markdown code fence, and Paste Special shows it.
nonisolated enum CodeLanguage: String, CaseIterable, Sendable {
    case json, html, xml, dart, swift, kotlin, java, python, javascript, go, rust, c, sql, css, shell
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
    /// The language named after a code block's opening backticks (`FenceLanguage.tag`); empty for none.
    var fenceTag = ""

    /// Valid JSON is shown indented; other code goes in a code block; prose is tidied. The code block is tagged
    /// with the detected language.
    static func defaults(for language: CodeLanguage?) -> TextPasteOptions {
        let tag = language?.fenceTag ?? ""
        return switch language {
        case .json: TextPasteOptions(reformat: .prettyJSON, style: .plain, fenceTag: tag)
        case .some: TextPasteOptions(reformat: .tidy, style: .codeBlock, fenceTag: tag)
        case nil: TextPasteOptions(reformat: .tidy, style: .plain, fenceTag: tag)
        }
    }
}

/// A language a Markdown code block can be tagged with, as GitHub and most Markdown editors name them.
nonisolated struct FenceLanguage: Hashable, Identifiable, Sendable {
    /// What goes after the backticks, e.g. `swift`.
    let tag: String
    /// Language names stay the same in every language.
    let name: String
    /// Other names people search for, e.g. `js` for JavaScript.
    var aliases: [String] = []

    var id: String { tag }

    static let all: [FenceLanguage] = [
        .init(tag: "bash", name: "Bash", aliases: ["sh", "zsh"]), .init(tag: "c", name: "C"),
        .init(tag: "cpp", name: "C++", aliases: ["c++"]), .init(tag: "csharp", name: "C#", aliases: ["cs", "c#"]),
        .init(tag: "css", name: "CSS"), .init(tag: "dart", name: "Dart", aliases: ["flutter"]),
        .init(tag: "diff", name: "Diff", aliases: ["patch"]), .init(tag: "dockerfile", name: "Dockerfile", aliases: ["docker"]),
        .init(tag: "elixir", name: "Elixir"), .init(tag: "go", name: "Go", aliases: ["golang"]),
        .init(tag: "graphql", name: "GraphQL"), .init(tag: "groovy", name: "Groovy", aliases: ["gradle"]),
        .init(tag: "haskell", name: "Haskell"), .init(tag: "html", name: "HTML"), .init(tag: "ini", name: "INI"),
        .init(tag: "java", name: "Java"), .init(tag: "javascript", name: "JavaScript", aliases: ["js", "node"]),
        .init(tag: "json", name: "JSON"), .init(tag: "jsx", name: "JSX"), .init(tag: "kotlin", name: "Kotlin", aliases: ["kt"]),
        .init(tag: "lua", name: "Lua"), .init(tag: "makefile", name: "Makefile", aliases: ["make"]),
        .init(tag: "markdown", name: "Markdown", aliases: ["md"]),
        .init(tag: "objectivec", name: "Objective-C", aliases: ["objc"]), .init(tag: "perl", name: "Perl"),
        .init(tag: "php", name: "PHP"), .init(tag: "powershell", name: "PowerShell", aliases: ["ps1"]),
        .init(tag: "python", name: "Python", aliases: ["py"]), .init(tag: "r", name: "R"),
        .init(tag: "ruby", name: "Ruby", aliases: ["rb", "rails"]), .init(tag: "rust", name: "Rust", aliases: ["rs"]),
        .init(tag: "scala", name: "Scala"), .init(tag: "scss", name: "SCSS", aliases: ["sass"]),
        .init(tag: "shell", name: "Shell", aliases: ["terminal", "console"]), .init(tag: "sql", name: "SQL"),
        .init(tag: "swift", name: "Swift"), .init(tag: "toml", name: "TOML"), .init(tag: "tsx", name: "TSX"),
        .init(tag: "typescript", name: "TypeScript", aliases: ["ts"]), .init(tag: "xml", name: "XML"),
        .init(tag: "yaml", name: "YAML", aliases: ["yml"]),
    ]

    static func named(_ tag: String) -> FenceLanguage? { all.first { $0.tag == tag } }

    /// The languages whose name, tag or alias contains the query: exact matches first, then those starting with it.
    /// All of them for an empty query.
    static func matching(_ query: String) -> [FenceLanguage] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        let words = { (language: FenceLanguage) in [language.name.lowercased(), language.tag] + language.aliases }
        let found = all.filter { words($0).contains { $0.contains(query) } }
        let exact = found.filter { words($0).contains(query) }
        let starts = found.filter { !exact.contains($0) && words($0).contains { $0.hasPrefix(query) } }
        return exact + starts + found.filter { !exact.contains($0) && !starts.contains($0) }
    }
}
