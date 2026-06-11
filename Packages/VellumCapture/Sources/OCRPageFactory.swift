import Foundation
import VellumCore

/// Builds `OCRPage` values from plain text, assigning each line a
/// synthetic top-to-bottom bounding box. Used by the fixture provider;
/// keeps box math in one tested place.
public enum OCRPageFactory {
    public static func page(fromPlainText text: String, id: UUID = UUID(), confidence: Double = 1.0) -> OCRPage {
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let count = max(rawLines.count, 1)
        let lineHeight = 1.0 / Double(count)
        let lines = rawLines.enumerated().map { index, lineText in
            OCRLine(
                text: lineText,
                boundingBox: NormalizedRect(
                    x: 0,
                    y: Double(index) * lineHeight,
                    width: 1,
                    height: lineHeight
                ),
                confidence: confidence
            )
        }
        return OCRPage(id: id, lines: lines)
    }
}

/// Deterministic OCR double: treats the input bytes as a UTF-8 plain-text
/// transcript of a page (exactly what lives in `Fixtures/`).
public struct FixtureOCRProvider: DocumentOCRProviding {
    public init() {}

    public func recognizePage(from data: Data) async throws -> OCRPage {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw OCRError.unreadableInput
        }
        return OCRPageFactory.page(fromPlainText: text)
    }
}
