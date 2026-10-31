import Foundation
import Observation

/// Paste Special for text: the entry, what the text looks like, the chosen options and the text they give.
@Observable
final class TextPasteSpecialModel {
    let items: [ClipItem]
    let text: String
    /// The guessed language, or nil for prose.
    let language: CodeLanguage?
    var options: TextPasteOptions {
        didSet { if options != oldValue { result = TextFormatter.apply(options, to: text, language: language) } }
    }
    /// The code block's language field is searching: its keys go to the field, not to the window's shortcuts.
    var searchesLanguage = false
    /// The text with `options` applied, worked out once per change instead of on every redraw.
    private(set) var result: String

    init(items: [ClipItem], text: String) {
        self.items = items
        self.text = text
        let language = TextFormatter.language(of: text)
        self.language = language
        let options = TextPasteOptions.defaults(for: language)
        self.options = options
        result = TextFormatter.apply(options, to: text, language: language)
    }

    /// The reformats that fit: the JSON ones only for JSON.
    var reformats: [TextReformat] {
        TextReformat.allCases.filter { !$0.isJSON || language == .json }
    }
}
