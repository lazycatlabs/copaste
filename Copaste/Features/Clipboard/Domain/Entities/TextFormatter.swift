import Foundation

/// Tells code from prose, and rewrites text for Paste Special: tidied, JSON indented or on one line, or in a code
/// fence. Pure functions, so they can be unit-tested.
nonisolated enum TextFormatter {
    /// Only this many lines are looked at to guess the language, so a huge paste stays quick.
    private static let detectionLines = 300
    /// The share of lines that must look like code for text with no clear language to count as code.
    private static let codeLineShare = 0.5
    private static let indent = "  "

    // MARK: Detection

    /// The language the text is written in, `.other` for code in no known language, or nil for prose.
    static func language(of text: String) -> CodeLanguage? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if isJSON(value) { return .json }
        // A Markdown code block (e.g. one made by Paste Special): its tag names the language, or else its code does.
        if let block = unfenced(value) {
            return CodeLanguage(rawValue: block.tag) ?? (block.tag.isEmpty ? language(of: block.code) : nil) ?? .other
        }
        if value.hasPrefix("<"), value.hasSuffix(">") {
            return value.lowercased().contains(/<(?:!doctype html|html|head|body|div|span|p|a|ul|li|table|script|style)[\s>]/)
                ? .html : .xml
        }
        let lines = value.split(whereSeparator: \.isNewline).prefix(detectionLines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let signatures = signatures
        var scores = Array(repeating: 0, count: signatures.count)
        var codeLines = 0
        for line in lines {
            var matched = false
            for (index, signature) in signatures.enumerated() where signature.patterns.contains(where: line.contains) {
                scores[index] += 1
                matched = true
            }
            if matched || looksLikeCode(line) { codeLines += 1 }
        }
        guard Double(codeLines) >= Double(lines.count) * codeLineShare else { return nil }
        // The language with the most matching lines; on a tie, the one listed first.
        if let top = scores.max(), top > 0, let index = scores.firstIndex(of: top) { return signatures[index].language }
        // A single line ending in `;` or `}` could be anything, so it takes a known language to call it code.
        return lines.count > 1 ? .other : nil
    }

    /// A JSON object or array.
    static func isJSON(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.first == "{" || value.first == "[" else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(value.utf8))) != nil
    }

    /// Ends or starts like a line of code in most languages: also the `foo(` and `bar: 1,` lines of nested calls
    /// (Flutter widgets, React props), but not a sentence ending in a comma.
    private static func looksLikeCode(_ line: String) -> Bool {
        guard let last = line.last else { return false }
        if ";{}[](".contains(last) { return true }
        if last == ",", line.contains(where: { "(){}[]=:'\"".contains($0) }) { return true }
        return ["}", ")", "]", "//", "/*", "#!"].contains { line.hasPrefix($0) }
    }

    /// Lines that are typical of each language, matched against a trimmed line. Listed so that on a tie the more
    /// specific language wins (Swift before JavaScript for `let x = 1`).
    private static var signatures: [(language: CodeLanguage, patterns: [Regex<Substring>])] {
        [
            (.dart, [#/^import '(?:package|dart):/#,
                     #/^(?:abstract )?class \w+ extends (?:StatelessWidget|StatefulWidget|State<\w+>)/#,
                     #/^(?:Widget build\(|void main\(\)|@override$|late (?:final )?\w+|setState\(\(\))/#]),
            (.swift, [#/^import (?:SwiftUI|Foundation|UIKit|AppKit|Combine)$/#,
                      #/^(?:@\w+ |private |public |static |override )*func \w+.*\(/#,
                      #/^guard .+ else \{|^if let \w+/#,
                      #/^(?:struct|enum|protocol|extension|actor) \w+.*\{$/#,
                      #/^(?:private |public |static |@\w+ )*var \w+: [\w<>\[\]?. ]+ \{$/#,
                      #/^@(?:State|Binding|Observable|MainActor|Published)\b/#]),
            (.kotlin, [#/^(?:fun \w+\(|val \w+(?:: \w+)? = |data class |when \(|companion object)/#]),
            (.java, [#/^(?:public|private|protected) (?:static |final |abstract )*(?:class|interface|void) /#,
                     #/^(?:import|package) [\w.]+;$|^System\.out\.print/#]),
            (.python, [#/^def \w+\(.*\):|^class \w+(?:\(.*\))?:$|^elif .+:$/#,
                       #/^from [\w.]+ import |^import [\w.]+(?: as \w+)?$/#,
                       #/^if __name__ == |^print\(|^self\.\w+ = /#]),
            (.javascript, [#/^(?:const \w+ = |let \w+ = .*;$|function \w*\(|console\.\w+\(|module\.exports)/#,
                           #/^export (?:default |const |function |class )|^import .+ from ['"]/#,
                           #/=> \{|require\(['"]/#]),
            (.go, [#/^(?:package \w+$|func (?:\(\w+ \*?\w+\) )?\w+\(|import \($)|\w+ := |fmt\.\w+\(/#]),
            (.rust, [#/^(?:fn \w+|pub fn |let mut |impl\b|use \w+::|#\[derive)|println!\(/#]),
            (.c, [#/^(?:#include [<"]|#define |int main\(|using namespace )|std::|printf\(/#]),
            (.sql, [#/^(?:SELECT .+|INSERT INTO |UPDATE \w+ SET |DELETE FROM |FROM \w+|WHERE .+|(?:LEFT |INNER )?JOIN )/#,
                    #/^(?:CREATE|ALTER|DROP) (?:TABLE|INDEX|VIEW) /#]),
            // A selector's colons never have a space after them, unlike `var body: some View {`.
            (.css, [#/^[.#@]?[\w-]+(?:[\w .#>,\[\]="-]|:(?! ))* \{$|^[\w-]+: [^;]+;$/#]),
            (.shell, [#/^(?:#!\/|\$ |sudo |cd |ls |echo |export [A-Z_]+=|curl |chmod |mkdir |rm |cp |mv )/#,
                      #/^(?:brew|git|npm|npx|yarn|pnpm|pip3?|python3?|docker|kubectl|xcodebuild) /#,
                      #/^swift (?:build|test|run)/#]),
        ]
    }

    // MARK: Rewriting

    /// The text as Paste Special pastes it with these options. JSON options leave text that isn't JSON as it is.
    static func apply(_ options: TextPasteOptions, to text: String, language: CodeLanguage?) -> String {
        let body = switch options.reformat {
        case .original: text
        case .tidy: tidy(text)
        case .prettyJSON: json(text, pretty: true) ?? text
        case .minifyJSON: json(text, pretty: false) ?? text
        }
        return options.style == .codeBlock ? codeBlock(body, tag: options.fenceTag) : body
    }

    /// Removes trailing spaces, the indentation all lines share, blank lines at either end, and runs of blank
    /// lines (one is kept). Line endings become `\n`.
    static func tidy(_ text: String) -> String {
        var lines: [Substring] = []
        for var line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            while line.last?.isWhitespace == true { line.removeLast() }
            if line.isEmpty, lines.last?.isEmpty ?? true { continue }
            lines.append(line)
        }
        if lines.last?.isEmpty == true { lines.removeLast() }
        let margins = lines.filter { !$0.isEmpty }.map { $0.prefix { $0 == " " || $0 == "\t" } }
        guard let first = margins.first else { return "" }
        let shared = margins.dropFirst().reduce(first) { common, margin in common.commonPrefix(with: margin)[...] }
        return lines.map { $0.dropFirst(shared.count) }.joined(separator: "\n")
    }

    /// JSON indented two spaces per level, or on one line. Keys keep their order and numbers their spelling,
    /// which re-encoding through `JSONSerialization` would lose. Nil if it isn't JSON.
    static func json(_ text: String, pretty: Bool) -> String? {
        guard isJSON(text) else { return nil }
        var out = ""
        var level = 0
        var inString = false, escaped = false, opened = false
        func newline() {
            guard pretty else { return }
            out += "\n" + String(repeating: indent, count: level)
        }
        for char in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            if inString {
                out.append(char)
                inString = stillInString(after: char, escaped: &escaped)
                continue
            }
            if char.isWhitespace { continue }
            let closes = char == "}" || char == "]"
            if opened {
                opened = false
                // An empty object or array stays on one line.
                if closes { level -= 1; out.append(char); continue }
                newline()
            } else if closes {
                level -= 1
                newline()
            }
            out.append(char)
            switch char {
            case "{", "[": level += 1; opened = true
            case ",": newline()
            case ":": if pretty { out += " " }
            case "\"": inString = true
            default: break
            }
        }
        return out
    }

    /// Whether a JSON string goes on after this character, which follows an escaping `\` when `escaped` is set.
    private static func stillInString(after char: Character, escaped: inout Bool) -> Bool {
        if escaped {
            escaped = false
            return true
        }
        escaped = char == "\\"
        return char != "\""
    }

    /// The code inside a Markdown code block and the block's language tag (empty for none), or nil if the text isn't
    /// one block. Blocks inside blocks are opened too, so wrapping an existing block again can be undone; the outer
    /// tag, picked last, wins.
    static func unfenced(_ text: String) -> (code: String, tag: String)? {
        var code = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tag: String?
        while true {
            var lines = code.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            guard lines.count >= 2, let first = lines.first, let last = lines.last else { break }
            let fence = first.prefix { $0 == "`" }
            let info = first.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
            guard fence.count >= 3, !info.contains("`"), last.trimmingCharacters(in: .whitespaces) == fence else { break }
            lines.removeFirst()
            lines.removeLast()
            code = lines.joined(separator: "\n")
            tag = tag ?? info.lowercased()
        }
        return tag.map { (code, $0) }
    }

    /// The text in a Markdown code fence, one backtick longer than any run of backticks inside it.
    static func codeBlock(_ text: String, tag: String) -> String {
        let longest = text.split { $0 != "`" }.map(\.count).max() ?? 0
        let fence = String(repeating: "`", count: max(3, longest + 1))
        let body = text.hasSuffix("\n") ? String(text.dropLast()) : text
        return "\(fence)\(tag)\n\(body)\n\(fence)"
    }
}
