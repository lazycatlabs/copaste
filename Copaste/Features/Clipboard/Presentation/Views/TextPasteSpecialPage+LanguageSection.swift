import SwiftUI

extension TextPasteSpecialPage {
    /// The language a code block is tagged with: a field showing it, which searches the languages once clicked or
    /// typed into, its matches dropping down over the preview. It stays inside the window, as Paste Special closes
    /// when another window takes the keyboard. ↑↓ move through the matches, ↩ picks one (or, with no match, uses what
    /// was typed as the tag), esc stops searching.
    struct LanguageSection: View {
        @Bindable var model: TextPasteSpecialModel
        @State private var query = ""
        @State private var highlighted = 0
        @FocusState private var isFocused: Bool

        var body: some View {
            PasteSpecialRow(title: L(.pasteSpecialLanguage)) { field }
                .disabled(model.options.style != .codeBlock)
                .onChange(of: model.options.style) { model.searchesLanguage = false }
                .zIndex(1)
        }

        private var none: FenceLanguage { FenceLanguage(tag: "", name: L(.pasteSpecialLanguageNone)) }

        private var matches: [FenceLanguage] {
            query.trimmingCharacters(in: .whitespaces).isEmpty ? [none] + FenceLanguage.all : FenceLanguage.matching(query)
        }

        private var selectedName: String {
            let tag = model.options.fenceTag
            return tag.isEmpty ? none.name : FenceLanguage.named(tag)?.name ?? tag
        }

        private var field: some View {
            // Read here, on the main actor: the alignment guide's closure below is Sendable.
            let gap = Spacing.xs
            return TextField(L(.pasteSpecialSearchLanguage), text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onAppear { query = selectedName }
                // Clicking the field starts a search from the whole list; leaving it shows the language again.
                .onChange(of: isFocused) {
                    if isFocused { startSearch() } else { model.searchesLanguage = false }
                }
                .onChange(of: query) {
                    highlighted = 0
                    // Typing again after picking a language.
                    if isFocused, !model.searchesLanguage, query != selectedName { model.searchesLanguage = true }
                }
                .onChange(of: model.searchesLanguage) { if !model.searchesLanguage { query = selectedName } }
                .onSubmit(pickHighlighted)
                .onKeyPress(.downArrow) { move(by: 1) }
                .onKeyPress(.upArrow) { move(by: -1) }
                // Below the field: the overlay's top sits a little under the field's bottom. In a ZStack, as the guide
                // set inside an `if` is lost.
                .overlay(alignment: .bottomLeading) {
                    ZStack { if model.searchesLanguage { dropdown } }
                        .alignmentGuide(.bottom) { $0[.top] - gap }
                }
                .accessibilityIdentifier("pasteSpecial.language")
        }

        private func startSearch() {
            query = ""
            highlighted = 0
            model.searchesLanguage = true
        }

        private var dropdown: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    // About forty rows at most, so a plain stack. Each is known by its tag, so a new search redraws them.
                    VStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.tag) { index, language in
                            row(language, isHighlighted: index == highlighted)
                        }
                        if matches.isEmpty {
                            Text(L(.pasteSpecialLanguageCustom(customTag)))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.md)
                        }
                    }
                    .padding(Spacing.xs)
                }
                .onChange(of: highlighted) {
                    if matches.indices.contains(highlighted) { proxy.scrollTo(matches[highlighted].tag) }
                }
            }
            .frame(height: Metrics.PasteSpecial.languageListHeight)
            .background(.regularMaterial, in: .rect(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(.primary.opacity(Opacity.fill)))
            .shadow(radius: Spacing.md)
        }

        private func row(_ language: FenceLanguage, isHighlighted: Bool) -> some View {
            Button { pick(language.tag) } label: {
                HStack {
                    Text(language.name)
                    Spacer()
                    Text(language.tag).font(.scaled(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(isHighlighted ? Color.accentColor.opacity(Opacity.border) : .clear, in: .rect(cornerRadius: Radius.sm))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pasteSpecial.languageOption")
        }

        /// What was typed, as a tag, for a language that isn't listed.
        private var customTag: String {
            query.lowercased().filter { !$0.isWhitespace }
        }

        private func move(by step: Int) -> KeyPress.Result {
            guard !matches.isEmpty else { return .handled }
            highlighted = min(max(highlighted + step, 0), matches.count - 1)
            return .handled
        }

        private func pickHighlighted() {
            if matches.indices.contains(highlighted) {
                pick(matches[highlighted].tag)
            } else if !customTag.isEmpty {
                pick(customTag)
            }
        }

        private func pick(_ tag: String) {
            model.options.fenceTag = tag
            model.searchesLanguage = false
        }
    }
}
