import Foundation
import Vision

/// Finds text in images (on device), so copied screenshots can be searched.
enum TextRecognitionDataSource {
    @concurrent
    nonisolated static func recognize(_ imageData: Data, accurate: Bool) async -> String? {
        var request = RecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = accurate
        guard let observations = try? await request.perform(on: imageData) else { return nil }
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }
}
