import AppKit
import ImageIO

extension NSImage {
    nonisolated var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Size in pixels (not points), as shown in the clip's details.
    nonisolated var pixelSize: CGSize {
        guard let rep = representations.first else { return size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}

enum DeviceInfo {
    static var name: String {
        Host.current().localizedName ?? "Mac"
    }
}

/// Decoded images from the vault, kept in memory so scrolling the list doesn't decode the same file twice.
/// The cache is capped, and thumbnails are decoded at the size they're shown, not as full screenshots.
enum ImageCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = Metrics.Clipboard.imageCacheBytes
        return cache
    }()

    /// The image at full size, e.g. to annotate it.
    static func image(at url: URL) -> NSImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return nil }
        let size = image.pixelSize
        cache.setObject(image, forKey: key, cost: Int(size.width * size.height) * 4)
        return image
    }

    /// The image no larger than `maxPixelSize` on its longest side; falls back to full size for formats ImageIO can't scale.
    static func image(at url: URL, maxPixelSize: CGFloat) -> NSImage? {
        let key = "\(url.path)#\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return image(at: url) }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
