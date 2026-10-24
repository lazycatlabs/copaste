import Foundation

/// Decides what copied text is: a colour, an e-mail address, a link or plain text.
nonisolated enum ClipClassifier {
    static func kind(of text: String) -> ClipKind {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: \.isNewline) else { return .text }
        if ColorValue(parsing: value) != nil { return .color }
        if mailURL(value) != nil { return .email }
        if linkURL(value) != nil { return .link }
        return .text
    }

    /// `https://…`, `http://…`, `ftp://…`, or a bare `www.` address.
    static func linkURL(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains(where: \.isWhitespace) else { return nil }
        if value.lowercased().hasPrefix("www."), value.count > 4 { return URL(string: "https://" + value) }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              ["http", "https", "ftp"].contains(scheme), url.host() != nil else { return nil }
        return url
    }

    /// A single address, with or without `mailto:`.
    static func mailURL(_ text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("mailto:") { value = String(value.dropFirst("mailto:".count)) }
        guard value.wholeMatch(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) != nil else { return nil }
        return URL(string: "mailto:" + value)
    }
}
