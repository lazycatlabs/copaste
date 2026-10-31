import UniformTypeIdentifiers

/// The file types Paste Special can turn an image into.
nonisolated enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png, jpeg, heic, tiff

    var id: String { rawValue }

    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .tiff: .tiff
        }
    }

    var title: String { rawValue.uppercased() }

    /// Lossy formats take a quality; the others ignore it.
    var isLossy: Bool { self == .jpeg || self == .heic }

    /// JPEG has no transparency, so transparent pixels become white instead of black.
    var keepsTransparency: Bool { self != .jpeg }
}

/// How Paste Special converts an image: the file type, the quality for lossy types, and how much to shrink it.
nonisolated struct PasteSpecialOptions: Hashable, Sendable {
    var format = ImageFormat.jpeg
    /// 0…1, for JPEG and HEIC.
    var quality = 0.8
    /// 1 keeps the size; 0.5 halves the width and height.
    var scale = 1.0

    static let scales = [1.0, 0.75, 0.5, 0.25]
    static let qualityRange = 0.1...1.0

    /// The longest side after scaling, at least one pixel.
    func maxPixelSize(width: Int, height: Int) -> Int {
        max(1, Int((Double(max(width, height)) * scale).rounded()))
    }
}

/// An image converted by Paste Special.
nonisolated struct ConvertedImage: Sendable, Equatable {
    var data: Data
    var width: Int
    var height: Int
}
