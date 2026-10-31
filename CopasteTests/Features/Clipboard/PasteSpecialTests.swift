import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Copaste

struct PasteSpecialTests {
    /// A half-transparent red PNG on disk.
    private func makePNG(width: Int, height: Int) throws -> URL {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    private func type(of data: Data) -> String? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap(CGImageSourceGetType) as String?
    }

    @Test(arguments: ImageFormat.allCases)
    func convertsToEachFormatAndScales(format: ImageFormat) throws {
        let url = try makePNG(width: 400, height: 200)
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try #require(ImageConverter.convert(url, options: PasteSpecialOptions(format: format, scale: 0.5)))
        #expect(result.width == 200 && result.height == 100)
        switch format {
        case .svg:
            let svg = try #require(String(data: result.data, encoding: .utf8))
            #expect(svg.hasPrefix("<svg") && svg.contains(#"width="200" height="100""#) && svg.contains("data:image/png;base64,"))
        case .pdf:
            let page = try #require(CGDataProvider(data: result.data as CFData).flatMap(CGPDFDocument.init)?.page(at: 1))
            #expect(page.getBoxRect(.mediaBox).size == CGSize(width: 200, height: 100))
        default:
            #expect(type(of: result.data) == format.type.identifier)
        }
    }

    @Test func lowerQualityMakesSmallerJPEG() throws {
        let url = try makePNG(width: 600, height: 600)
        defer { try? FileManager.default.removeItem(at: url) }
        let high = try #require(ImageConverter.convert(url, options: PasteSpecialOptions(format: .jpeg, quality: 1)))
        let low = try #require(ImageConverter.convert(url, options: PasteSpecialOptions(format: .jpeg, quality: 0.1)))
        #expect(low.data.count < high.data.count)
    }

    @Test func offeredForImagesAndImageFilesOnly() {
        func item(_ kind: ClipKind, files: [String]? = nil) -> ClipItem {
            ClipItem(kind: kind, files: files?.map { ClipFile(path: "/tmp/\($0)", name: $0) }, hash: "",
                     firstCopied: .now, lastCopied: .now)
        }
        #expect(ClipAction.available(for: item(.image)).contains(.pasteSpecial))
        #expect(ClipAction.available(for: item(.file, files: ["a.jpg"])).contains(.pasteSpecial))
        #expect(!ClipAction.available(for: item(.file, files: ["a.pdf"])).contains(.pasteSpecial))
        #expect(!ClipAction.available(for: item(.file, files: ["a.jpg", "b.jpg"])).contains(.pasteSpecial))
        #expect(!ClipAction.available(for: item(.text)).contains(.pasteSpecial))
    }
}
