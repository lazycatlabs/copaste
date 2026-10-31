import SwiftUI

/// Shown in its own window at the pointer. Converts an image entry to another file type, optionally smaller, then pastes or copies it as a file.
struct PasteSpecialView: View {
    @Bindable var model: PasteSpecialModel
    let finish: (_ pasting: Bool) -> Void
    let cancel: () -> Void
    let pastes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Label(L(.pasteSpecialTitle), systemImage: ClipAction.pasteSpecial.symbolName)
                .font(.scaled(.title3, weight: .semibold))
            row(L(.pasteSpecialFormat)) {
                Picker(L(.pasteSpecialFormat), selection: $model.options.format) {
                    ForEach(ImageFormat.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.format")
            }
            row(L(.pasteSpecialSize)) {
                Picker(L(.pasteSpecialSize), selection: $model.options.scale) {
                    ForEach(PasteSpecialOptions.scales, id: \.self) { Text($0.formatted(.percent)).tag($0) }
                }
                .accessibilityIdentifier("pasteSpecial.size")
            }
            // Always shown, so the window keeps its size; PNG and TIFF have no quality setting.
            row(L(.pasteSpecialQuality)) {
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
            HStack(spacing: Spacing.md) {
                Spacer()
                Button(L(.actionCancel), action: cancel)
                button(L(.actionCopy), keys: HotKeyStore.shared[.copy].keys) { finish(false) }
                    .accessibilityIdentifier("pasteSpecial.copy")
                if pastes {
                    button(L(.actionPaste), keys: HotKeyStore.shared[.paste].keys) { finish(true) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("pasteSpecial.paste")
                }
            }
        }
        .pickerStyle(.segmented)
        .padding(Spacing.page)
        .frame(width: Metrics.PasteSpecial.width)
        .background(.thickMaterial, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.fill)))
        .task(id: model.options) { await model.update() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pasteSpecial")
    }

    private var summary: String {
        guard model.isUpToDate, let result = model.result else { return L(.pasteSpecialConverting) }
        let before = model.originalBytes?.formatted(.byteCount(style: .file)) ?? "—"
        let after = Int64(result.data.count).formatted(.byteCount(style: .file))
        return L(.pasteSpecialResult(before, after, result.width, result.height))
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        LabeledContent(title) { content().labelsHidden() }.font(.scaled(.body))
    }

    private func button(_ title: String, keys: [String], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                KeyCaps(keys: keys)
            }
        }
    }
}
