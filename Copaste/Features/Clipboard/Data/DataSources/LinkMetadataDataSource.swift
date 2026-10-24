import OSLog
import Foundation
import LinkPresentation
import UniformTypeIdentifiers

/// A web page's title, favicon and preview image (Open Graph), via LinkPresentation.
enum LinkMetadataDataSource {
    struct Metadata {
        var title: String?
        var favicon: Data?
        var image: Data?
    }

    static func fetch(_ url: URL) async -> Metadata? {
        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = true
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            let favicon = await data(of: metadata.iconProvider)
            let image = await data(of: metadata.imageProvider)
            return Metadata(title: metadata.title, favicon: favicon, image: image)
        } catch {
            Log.metadata.info("No preview for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func data(of provider: NSItemProvider?) async -> Data? {
        guard let provider else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, _ in continuation.resume(returning: data) }
        }
    }
}
