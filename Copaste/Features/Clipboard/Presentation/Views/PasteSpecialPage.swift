import SwiftUI

/// Shown in its own window at the pointer. Converts an image entry to another file type, optionally smaller, then pastes or copies it as a file.
struct PasteSpecialPage: View {
    @Bindable var model: PasteSpecialModel
    let finish: (_ pasting: Bool) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Label(L(.pasteSpecialTitle), systemImage: ClipAction.pasteSpecial.symbolName)
                .font(.scaled(.title3, weight: .semibold))
            PasteSpecialRow(title: L(.pasteSpecialFormat)) {
                Picker(L(.pasteSpecialFormat), selection: $model.options.format) {
                    ForEach(ImageFormat.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.format")
            }
            PasteSpecialRow(title: L(.pasteSpecialSize)) {
                Picker(L(.pasteSpecialSize), selection: $model.options.scale) {
                    ForEach(PasteSpecialOptions.scales, id: \.self) { Text($0.formatted(.percent)).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.size")
            }
            // Always shown, so the window keeps its size; PNG and TIFF have no quality setting.
            PasteSpecialRow(title: L(.pasteSpecialQuality)) {
                HStack {
                    Slider(value: $model.options.quality, in: PasteSpecialOptions.qualityRange)
                        .accessibilityIdentifier("pasteSpecial.quality")
                    Text(model.options.quality.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!model.options.format.isLossy)
            Text(summary)
                .font(.scaled(.callout))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("pasteSpecial.summary")
            PasteSpecialButtons(finish: finish, cancel: cancel)
        }
        .pasteSpecialCard()
        .task(id: model.options) { await model.update() }
    }

    private var summary: String {
        if model.hasFailed { return L(.pasteSpecialFailed) }
        guard model.isUpToDate, let results = model.results, let result = results.first else { return L(.pasteSpecialConverting) }
        let before = model.originalBytes?.formatted(.byteCount(style: .file)) ?? "—"
        let after = Int64(results.map(\.data.count).reduce(0, +)).formatted(.byteCount(style: .file))
        // Several images: their total sizes, as their pixel sizes differ.
        guard results.count == 1 else { return L(.pasteSpecialResultMany(results.count, before, after)) }
        return L(.pasteSpecialResult(before, after, String(result.width), String(result.height)))
    }
}
