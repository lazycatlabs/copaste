import SwiftUI

/// Shown in its own window at the pointer. Rewrites a text entry (tidied, JSON indented or on one line) and pastes or
/// copies it as plain text, a Markdown code block or monospaced rich text.
struct TextPasteSpecialPage: View {
    @Bindable var model: TextPasteSpecialModel
    let finish: (_ pasting: Bool) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack {
                Label(L(.pasteSpecialTitle), systemImage: ClipAction.pasteSpecial.symbolName)
                    .font(.scaled(.title3, weight: .semibold))
                Spacer()
                Text(detected)
                    .font(.scaled(.callout))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("pasteSpecial.detected")
            }
            PasteSpecialRow(title: L(.pasteSpecialReformat)) {
                Picker(L(.pasteSpecialReformat), selection: $model.options.reformat) {
                    ForEach(model.reformats) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.reformat")
            }
            PasteSpecialRow(title: L(.pasteSpecialPasteAs)) {
                Picker(L(.pasteSpecialPasteAs), selection: $model.options.style) {
                    ForEach(TextPasteStyle.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.style")
            }
            Text(model.options.style.hint)
                .font(.scaled(.callout))
                .foregroundStyle(.secondary)
            LanguageSection(model: model)
            preview
            PasteSpecialButtons(finish: finish, cancel: cancel)
        }
        .pasteSpecialCard()
    }

    /// What the text was taken for: a language, code, or plain text.
    private var detected: String {
        guard let language = model.language else { return L(.pasteSpecialPlainText) }
        return L(.pasteSpecialDetected(language.name ?? L(.kindCode)))
    }

    /// The start of the text as it will be pasted.
    private var preview: some View {
        ScrollView {
            Text(model.result.prefix(Metrics.PasteSpecial.previewLength))
                .font(.scaled(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(Spacing.md)
        }
        .frame(height: Metrics.PasteSpecial.previewHeight)
        .background(.primary.opacity(Opacity.tint), in: .rect(cornerRadius: Radius.md))
        .accessibilityIdentifier("pasteSpecial.preview")
    }
}

private extension TextReformat {
    var title: String {
        switch self {
        case .original: L(.textReformatOriginal)
        case .tidy: L(.textReformatTidy)
        case .prettyJSON: L(.textReformatPrettyJSON)
        case .minifyJSON: L(.textReformatMinifyJSON)
        }
    }
}

private extension TextPasteStyle {
    var title: String {
        switch self {
        case .plain: L(.textStylePlain)
        case .codeBlock: L(.textStyleCodeBlock)
        case .monospaced: L(.textStyleMonospaced)
        }
    }

    var hint: String {
        switch self {
        case .plain: L(.textStylePlainHint)
        case .codeBlock: L(.textStyleCodeBlockHint)
        case .monospaced: L(.textStyleMonospacedHint)
        }
    }
}
