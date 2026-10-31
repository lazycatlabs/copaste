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

        let data: Data? = switch options.format {
        case .svg: svg(image)
        case .pdf: pdf(image)
        default: encode(image, as: options.format.type, quality: options.format.isLossy ? options.quality : nil)
        }
        return data.map { ConvertedImage(data: $0, width: image.width, height: image.height) }
    }

    private static func encode(_ image: CGImage, as type: UTType, quality: Double? = nil) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        let properties = quality.map { [kCGImageDestinationLossyCompressionQuality: $0] } ?? [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// A one-page PDF the size of the image (one point per pixel).
    private static func pdf(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        context.beginPDFPage(nil)
        context.draw(image, in: box)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// An SVG the size of the image, with the image inside as a PNG (which keeps transparency).
    private static func svg(_ image: CGImage) -> Data? {
        guard let png = encode(image, as: .png) else { return nil }
        let (width, height) = (image.width, image.height)
        return Data("""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" \
        width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        <image width="\(width)" height="\(height)" xlink:href="data:image/png;base64,\(png.base64EncodedString())"/>
        </svg>

        """.utf8)
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
