// UNTESTED: written without Xcode.
// Pulls text out of a dropped PDF, image or text file and finds the
// references in it. Runs entirely on the Mac.
import Foundation
import PDFKit
import Vision
import AppKit
import UniformTypeIdentifiers
import WordCueKit

enum FileImporter {
    static let supportedTypes: [UTType] = [.pdf, .image, .plainText, .rtf]

    static func text(from url: URL) async throws -> String {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        if type.conforms(to: .pdf) {
            return PDFDocument(url: url)?.string ?? ""
        }
        if type.conforms(to: .image) {
            return try await recognizeText(in: url)
        }
        if type.conforms(to: .rtf) {
            let data = try Data(contentsOf: url)
            return (try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                            documentAttributes: nil).string) ?? ""
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Reads printed text in a photo or screenshot (Apple's Vision framework).
    private static func recognizeText(in url: URL) async throws -> String {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cg).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func detections(in url: URL, engine: Engine) async throws -> [Detection] {
        engine.detect(try await text(from: url), mode: .document)
    }
}
