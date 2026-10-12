import AppKit
import Vision

/// Распознавание текста на изображении (OCR) через Vision
public enum TextRecognizer {
    public static func recognize(in image: NSImage) async -> String {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["ru-RU", "en-US"]
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                try? handler.perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}
