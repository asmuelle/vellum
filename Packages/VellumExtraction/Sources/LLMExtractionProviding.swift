import Foundation
import VellumCore

public enum LLMAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)
}

public enum LLMExtractionError: Error, Equatable, Sendable {
    case unavailable(reason: String)
    case extractionFailed(String)
}

/// Boundary protocol for the on-device LLM fallback (Apple Foundation
/// Models in M2+). The provider receives OCR TEXT only — never pixels —
/// and must return raw strings verbatim from the page; any model-side
/// normalization is discarded by design (invariant #4).
///
/// M1 ships no model integration: the production default is
/// `UnavailableLLMExtractionProvider`, and the deterministic mock below
/// keeps the seam fully testable without any AI API.
public protocol LLMExtractionProviding: Sendable {
    var availability: LLMAvailability { get }
    func extractValues(fromOCRText text: String, documentID: UUID, pageID: UUID) async throws -> [ExtractedValue]
}

/// Production default for M1 and for every device below the Apple
/// Intelligence floor (invariant #7): never crashes, never blocks —
/// the document simply stays a searchable scan.
public struct UnavailableLLMExtractionProvider: LLMExtractionProviding {
    public static let defaultReason =
        "On-device model fallback ships after M1; the document is stored as a searchable scan."

    public let reason: String

    public init(reason: String = UnavailableLLMExtractionProvider.defaultReason) {
        self.reason = reason
    }

    public var availability: LLMAvailability {
        .unavailable(reason: reason)
    }

    public func extractValues(fromOCRText _: String, documentID _: UUID, pageID _: UUID) async throws -> [ExtractedValue] {
        throw LLMExtractionError.unavailable(reason: reason)
    }
}

/// A single canned proposal for `MockLLMExtractionProvider`, mirroring the
/// raw fields an on-device model would surface verbatim from the page.
public struct MockExtractionRow: Sendable, Equatable {
    public let analyteRaw: String
    public let valueRaw: String
    public let unitRaw: String
    public let refRangeRaw: String

    public init(analyteRaw: String, valueRaw: String, unitRaw: String, refRangeRaw: String) {
        self.analyteRaw = analyteRaw
        self.valueRaw = valueRaw
        self.unitRaw = unitRaw
        self.refRangeRaw = refRangeRaw
    }
}

/// Deterministic mock provider: returns canned proposals. Used by tests
/// (and previews) so the full pipeline runs without any model.
public struct MockLLMExtractionProvider: LLMExtractionProviding {
    public let cannedRows: [MockExtractionRow]

    public init(cannedRows: [MockExtractionRow]) {
        self.cannedRows = cannedRows
    }

    public var availability: LLMAvailability {
        .available
    }

    public func extractValues(fromOCRText _: String, documentID: UUID, pageID: UUID) async throws -> [ExtractedValue] {
        cannedRows.map { row in
            ExtractedValue(
                documentID: documentID,
                pageID: pageID,
                boundingBox: .zero,
                analyteRaw: row.analyteRaw,
                valueRaw: row.valueRaw,
                unitRaw: row.unitRaw,
                refRangeRaw: row.refRangeRaw,
                extractionMethod: .llm,
                confidence: 0.5
            )
        }
    }
}
