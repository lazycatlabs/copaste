import AppKit
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

    @Test func repeatedFileNamesGetANumber() {
        #expect(ClipUseCases.uniqueNames(["Image", "Image", "Photo", "Image"]) == ["Image", "Image 2", "Photo", "Image 3"])
    }

    @MainActor @Test func severalImagesGoOnTheClipboardAsFiles() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let board = NSPasteboard(name: .init(UUID().uuidString))
        let session = ClipboardSession(root: root, pasteboard: SystemPasteboard(pasteboard: board))
        let url = try makePNG(width: 40, height: 20)
        defer { try? FileManager.default.removeItem(at: url) }
        let png = try Data(contentsOf: url)
        session.handle(Capture(content: .image(png: png, width: 40, height: 20)))
        session.handle(Capture(content: .files([ClipFile(path: url.path, name: "Chart.png")])))
        let items = session.items.sorted { $0.kind.rawValue > $1.kind.rawValue }
        let images = try items.map { try #require(session.imageURL(of: $0)) }
            .map { try #require(ImageConverter.convert($0, options: PasteSpecialOptions(format: .jpeg))) }

        #expect(session.writeConverted(images, format: .jpeg, for: items, pasting: false))
        let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        #expect(files.map(\.lastPathComponent).sorted() == ["Chart.jpeg", "Image.jpeg"])
        #expect(session.items.allSatisfy { $0.copyCount == 2 }, "Each entry counts a copy")
    }

    @Test func latestIsTheLastCopied() {
        let old = ClipItem(kind: .image, hash: "a", firstCopied: .distantPast, lastCopied: .distantPast)
        let new = ClipItem(kind: .text, hash: "b", firstCopied: .now, lastCopied: .now)
        #expect(ClipUseCases.latest([old, new])?.id == new.id)
        #expect(ClipUseCases.latest([ClipUseCases.markCopied(old), new])?.id == old.id, "Copying again makes it the latest")
        #expect(ClipUseCases.latest([]) == nil)
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
