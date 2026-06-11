import Foundation
import VellumCore

public enum OCRError: Error, Equatable, Sendable {
    case unreadableInput
    case recognitionFailed(String)
}

/// Boundary protocol for OCR. The real implementation uses Vision on
/// device; the deterministic `FixtureOCRProvider` powers tests and the
/// M1 sample-import flow so the whole pipeline runs without a camera,
/// without a network, and without any platform AI.
public protocol DocumentOCRProviding: Sendable {
    /// Recognize one page. `data` is an encoded image for the Vision
    /// implementation; the fixture implementation accepts UTF-8 plain
    /// text (the checked-in synthetic OCR transcript).
    func recognizePage(from data: Data) async throws -> OCRPage
}
