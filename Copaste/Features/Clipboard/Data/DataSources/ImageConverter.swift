import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Re-encodes an image file in another format, optionally smaller (Paste Special).
nonisolated enum ImageConverter {
    /// Decodes straight at the target size, so shrinking a large screenshot never holds it at full size.
    static func convert(_ url: URL, options: PasteSpecialOptions) -> ConvertedImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let decode: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: options.maxPixelSize(width: width, height: height),
        ]
        guard var image = CGImageSourceCreateThumbnailAtIndex(source, 0, decode as CFDictionary) else { return nil }
        if !options.format.keepsTransparency, hasAlpha(image), let flat = flattened(image) { image = flat }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, options.format.type.identifier as CFString, 1, nil)
        else { return nil }
        var encode: [CFString: Any] = [:]
        if options.format.isLossy { encode[kCGImageDestinationLossyCompressionQuality] = options.quality }
        CGImageDestinationAddImage(destination, image, encode as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return ConvertedImage(data: data as Data, width: image.width, height: image.height)
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        [.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo)
    }

    /// The image on white, without an alpha channel.
    private static func flattened(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(.white)
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
