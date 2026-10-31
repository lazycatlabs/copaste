import Foundation
import Observation

/// The Paste Special sheet: the entry being converted, the chosen options, and the latest conversion for the size preview.
@Observable
final class PasteSpecialModel {
    /// The last options used, so the next Paste Special starts from them (kept until Copaste quits).
    private static var lastOptions = PasteSpecialOptions()

    let item: ClipItem
    let source: URL
    let originalBytes: Int64?
    var options: PasteSpecialOptions {
        didSet { Self.lastOptions = options }
    }
    /// The conversion for `options`, once it's done.
    private(set) var result: ConvertedImage?
    private var resultOptions: PasteSpecialOptions?

    init(item: ClipItem, source: URL) {
        self.item = item
        self.source = source
        options = Self.lastOptions
        originalBytes = (try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
    }

    /// Whether the preview shows the current options.
    var isUpToDate: Bool { resultOptions == options && result != nil }

    /// Converts in the background for the size preview, once the options stop changing.
    func update() async {
        try? await Task.sleep(for: Metrics.PasteSpecial.debounce)
        guard !Task.isCancelled else { return }
        let source = source, options = options
        let converted = await Task.detached { ImageConverter.convert(source, options: options) }.value
        guard !Task.isCancelled else { return }
        result = converted
        resultOptions = options
    }

    /// The image to paste: the preview if it matches the options, otherwise converted now.
    func converted() -> ConvertedImage? {
        isUpToDate ? result : ImageConverter.convert(source, options: options)
    }
}
