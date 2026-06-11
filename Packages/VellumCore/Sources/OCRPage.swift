import Foundation

/// A rectangle in normalized page coordinates (0...1, origin top-left).
/// Plain value type so VellumCore stays free of CoreGraphics.
public struct NormalizedRect: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
}

/// One recognized line of text with its position on the page.
public struct OCRLine: Sendable, Codable, Hashable {
    public let text: String
    public let boundingBox: NormalizedRect
    public let confidence: Double

    public init(text: String, boundingBox: NormalizedRect, confidence: Double) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// The OCR output for a single captured page — the only input the
/// deterministic parsers (and, later, the LLM fallback) ever see.
public struct OCRPage: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let lines: [OCRLine]

    public init(id: UUID, lines: [OCRLine]) {
        self.id = id
        self.lines = lines
    }

    public var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}
