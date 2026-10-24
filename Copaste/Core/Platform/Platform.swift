import AppKit

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
enum ImageCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
