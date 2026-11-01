import Foundation
import Observation

/// The Paste Special sheet: the entries being converted (one, or several picked in the list), the chosen options, and
/// the latest conversion for the size preview.
@Observable
final class PasteSpecialModel {
    /// An entry and the image file it's converted from.
    struct Source {
        let item: ClipItem
        let url: URL
    }

    /// The last options used, so the next Paste Special starts from them (kept until ReCopy quits).
    private static var lastOptions = PasteSpecialOptions()

    let sources: [Source]
    /// All the images' files together.
    let originalBytes: Int64?
    var options: PasteSpecialOptions {
        didSet { Self.lastOptions = options }
    }
    /// The conversions for `options`, once they're done; nil if one failed.
    private(set) var results: [ConvertedImage]?
    private var resultOptions: PasteSpecialOptions?

    init(sources: [Source]) {
        self.sources = sources
        options = Self.lastOptions
        let sizes = sources.map { (try? $0.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) }
        originalBytes = sizes.contains(nil) ? nil : sizes.compactMap { $0 }.reduce(0, +)
    }

    var items: [ClipItem] { sources.map(\.item) }

    /// Whether the preview shows the current options.
    var isUpToDate: Bool { resultOptions == options && results != nil }

    /// An image couldn't be read or converted with the current options (e.g. its file is gone).
    var hasFailed: Bool { resultOptions == options && results == nil }

    /// Converts in the background for the size preview, once the options stop changing.
    func update() async {
        try? await Task.sleep(for: Metrics.PasteSpecial.debounce)
        guard !Task.isCancelled else { return }
        let urls = sources.map(\.url), options = options
        let converted = await Task.detached { Self.convert(urls, options: options) }.value
        guard !Task.isCancelled else { return }
        results = converted
        resultOptions = options
    }

    /// The images to paste, in list order: the preview if it matches the options, otherwise converted now.
    func converted() -> [ConvertedImage]? {
        isUpToDate ? results : Self.convert(sources.map(\.url), options: options)
    }

    /// One at a time, so several large images are never decoded together.
    nonisolated private static func convert(_ urls: [URL], options: PasteSpecialOptions) -> [ConvertedImage]? {
        var images: [ConvertedImage] = []
        for url in urls {
            guard let image = ImageConverter.convert(url, options: options) else { return nil }
            images.append(image)
        }
        return images
    }
}
