import AppKit
import Vision

/// Распознавание текста на изображении (OCR) через Vision с использованием современного Swift Concurrency
public enum TextRecognizer {
    
    // Предкомпилированные регулярные выражения для поиска чувствительной информации
    private static let sensitiveRegexes: [NSRegularExpression] = {
        let patterns = [
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", // Email
            "\\b(?:\\+?\\d{1,3}[- ]?)?\\(?\\d{3}\\)?[- ]?\\d{3}[- ]?\\d{2,4}[- ]?\\d{2,4}\\b", // Телефон
            "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13})\\b", // Номера карт
            "\\b(?:ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]+|sk-[A-Za-z0-9]{20,48}|AIza[0-9A-Za-z-_]{35})\\b" // API токены / секреты
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    public static func recognize(in image: NSImage) async -> String {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ru-RU", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }
    
    /// Модель найденного фрагмента текста с его bounding box в координатах изображения (y сверху вниз для SwiftUI)
    public struct RecognizedMatch: Sendable {
        public let text: String
        public let rect: CGRect
    }
    
    /// Поиск чувствительных данных (email, телефоны, токены, номера карт) с возвратом их рамок
    public static func findSensitiveRegions(in image: NSImage) async -> [CGRect] {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let imageWidth = CGFloat(cg.width)
        let imageHeight = CGFloat(cg.height)
        
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
            
            guard let observations = request.results else {
                return []
            }
            
            var matchedRects: [CGRect] = []
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let string = topCandidate.string
                let range = NSRange(location: 0, length: string.utf16.count)
                
                var isSensitive = false
                for rx in sensitiveRegexes {
                    if rx.firstMatch(in: string, options: [], range: range) != nil {
                        isSensitive = true
                        break
                    }
                }
                
                if isSensitive {
                    // Vision возвращает нормализованные координаты (0..1, origin внизу слева)
                    let box = observation.boundingBox
                    let x = box.origin.x * imageWidth
                    let y = (1.0 - box.origin.y - box.size.height) * imageHeight
                    let width = box.size.width * imageWidth
                    let height = box.size.height * imageHeight
                    
                    // Добавляем небольшой запас (padding 4px)
                    let paddedRect = CGRect(x: x - 4, y: y - 2, width: width + 8, height: height + 4)
                    matchedRects.append(paddedRect)
                }
            }
            
            return matchedRects
        }.value
    }
}
