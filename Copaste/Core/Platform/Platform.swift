import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    var pngRepresentation: Data? {
        #if os(macOS)
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return pngData()
        #endif
    }

    /// Size in pixels (not points), as shown in the clip's details.
    var pixelSize: CGSize {
        #if os(macOS)
        guard let rep = representations.first else { return size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        #else
        guard let cgImage else { return size }
        return CGSize(width: cgImage.width, height: cgImage.height)
        #endif
    }
}

enum DeviceInfo {
    static var name: String {
        #if os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        UIDevice.current.name
        #endif
    }
}

/// Decoded images from the vault, kept in memory so scrolling the list doesn't decode the same file twice.
enum ImageCache {
    private static let cache = NSCache<NSURL, PlatformImage>()

    static func image(at url: URL) -> PlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let data = try? Data(contentsOf: url), let image = PlatformImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
