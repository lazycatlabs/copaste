import SwiftUI

extension ClipboardPage {
    /// The selected entry: its note, its content, and its information (type, source, counts, dates).
    struct DetailSection: View {
        @Environment(ClipboardSession.self) private var session
        let model: ClipboardViewModel
        var noteFocused: FocusState<Bool>.Binding
        /// ↩ in the note: back to the search field.
        let onSubmitNote: () -> Void

        var body: some View {
            if let item = model.selected(in: session) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    TextField(L(.notePlaceholder), text: noteBinding(for: item), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.scaled(.body))
                        .lineLimit(1...Metrics.Detail.noteLines)
                        .focused(noteFocused)
                        .onSubmit(onSubmitNote)
                        .accessibilityLabel(L(.infoNote))
                        .accessibilityIdentifier("panel.note")
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        PreviewSection(item: item)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .frame(height: Metrics.Detail.previewHeight, alignment: .topLeading)
                        ScrollView {
                            InfoSection(item: item)
                        }
                        .scrollIndicators(.automatic)
                    }
                }
                .padding(Spacing.xxl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        private func noteBinding(for item: ClipItem) -> Binding<String> {
            Binding { item.note ?? "" } set: { session.setNote($0, for: item) }
        }
    }
}
