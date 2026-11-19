import AppKit
import Vision

/// Распознавание текста на изображении (OCR) и QR-кодов через Vision
public enum TextRecognizer {

    /// Распознавание QR-кодов на изображении с возвратом закодированных строк
    @MainActor
    public static func detectQRCodes(in image: NSImage) async -> [String] {
        guard let cg = ImageExporter.cgImage(from: image) else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
            } catch {
                AppLogger.capture.error("QR detection failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
            let results = request.results ?? []
            return results.compactMap { $0.payloadStringValue }.filter { !$0.isEmpty }
        }.value
    }

    // Паттерны без учёта регистра (email, телефон, банковские карты)
    nonisolated private static let caseInsensitiveRegexes: [NSRegularExpression] = {
        let patterns = [
            "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,64}",
            "(?<!\\w)(?:\\+?\\d{1,3}[-\\s]?)?(?:\\(\\d{3}\\)|\\d{3})[-\\s]\\d{3}[-\\s]?\\d{2}[-\\s]?\\d{2}\\b",
            "\\b(?:4\\d{3}(?:[- ]?\\d{4}){3}|5[1-5]\\d{2}(?:[- ]?\\d{4}){3}|6(?:011|5\\d{2})(?:[- ]?\\d{4}){3}|3[47]\\d{2}[- ]?\\d{6}[- ]?\\d{5})\\b"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    // Чувствительные к регистру префиксы API-токенов и секретов
    nonisolated private static let caseSensitiveRegexes: [NSRegularExpression] = {
        let patterns = [
            "\\b(?:ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]+|sk-[A-Za-z0-9_-]{20,64}|AIza[0-9A-Za-z_-]{35})\\b"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    nonisolated private static func performTextRecognition(on cgImage: CGImage, usesLanguageCorrection: Bool) -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            AppLogger.capture.error("Text recognition failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
        return request.results ?? []
    }

    @MainActor
    public static func recognize(in image: NSImage) async -> String {
        guard let cg = ImageExporter.cgImage(from: image) else { return "" }
        return await Task.detached(priority: .userInitiated) {
            let observations = performTextRecognition(on: cg, usesLanguageCorrection: true)
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    /// Поиск чувствительных данных (email, телефоны, токены, номера карт) с возвратом их рамок в координатах поинтов (NSImage.size)
    @MainActor
    public static func findSensitiveRegions(in image: NSImage) async -> [CGRect] {
        guard let cg = ImageExporter.cgImage(from: image) else { return [] }
        let pointSize = image.size.width > 0 && image.size.height > 0
            ? image.size
            : CGSize(width: cg.width, height: cg.height)
        return await findSensitiveRegions(in: cg, pointSize: pointSize)
    }

    nonisolated static func findSensitiveRegions(in cg: CGImage, pointSize: CGSize) async -> [CGRect] {
        guard pointSize.width > 0, pointSize.height > 0 else { return [] }
        let imageWidth = pointSize.width
        let imageHeight = pointSize.height
        let canvasBounds = CGRect(origin: .zero, size: pointSize)

        return await Task.detached(priority: .userInitiated) {
            let observations = performTextRecognition(on: cg, usesLanguageCorrection: false)
            guard !observations.isEmpty else {
                return []
            }

            let allRegexes = caseInsensitiveRegexes + caseSensitiveRegexes
            var matchedRects: [CGRect] = []

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let string = topCandidate.string
                let fullRange = NSRange(location: 0, length: string.utf16.count)

                var normalizedBoxes: [CGRect] = []
                for rx in allRegexes {
                    let matches = rx.matches(in: string, options: [], range: fullRange)
                    for match in matches {
                        if let swiftRange = Range(match.range, in: string),
                           let wordBox = try? topCandidate.boundingBox(for: swiftRange) {
                            normalizedBoxes.append(wordBox.boundingBox)
                        } else {
                            normalizedBoxes.append(observation.boundingBox)
                        }
                    }
                }

                for box in normalizedBoxes {
                    // Vision возвращает нормализованные координаты (0..1, origin внизу слева)
                    let x = box.origin.x * imageWidth
                    let y = (1.0 - box.origin.y - box.size.height) * imageHeight
                    let width = box.size.width * imageWidth
                    let height = box.size.height * imageHeight

                    let paddedRect = CGRect(x: x - 4, y: y - 2, width: width + 8, height: height + 4)
                        .intersection(canvasBounds)
                    if !paddedRect.isNull && paddedRect.width > 1 && paddedRect.height > 1 {
                        matchedRects.append(paddedRect)
                    }
                }
            }

            return matchedRects
        }.value
    }
}
