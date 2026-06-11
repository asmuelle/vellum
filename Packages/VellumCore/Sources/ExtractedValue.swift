import Foundation

/// How a proposed value was produced. PRODUCT INVARIANT #2: every
/// extracted value records its method; the LLM path may only run after
/// a deterministic miss.
public enum ExtractionMethod: String, Sendable, Codable, Hashable {
    case deterministic
    case llm
}

public enum ReviewState: String, Sendable, Codable, Hashable {
    case pending
    case confirmed
    case corrected
    case rejected
}

/// A *proposal* extracted from a page — pre-confirmation. Raw strings are
/// kept verbatim from the page (invariant #4: no model-side normalization;
/// units convert in code at minting time). Nothing downstream of review
/// may consume this type (invariant #3) — trends/ask/explain take
/// `LabResult` only.
public struct ExtractedValue: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let documentID: UUID
    public let pageID: UUID
    public let boundingBox: NormalizedRect
    public let analyteRaw: String
    public let valueRaw: String
    public let unitRaw: String
    public let refRangeRaw: String
    public let flagRaw: String?
    public let collectedAtRaw: String?
    public let extractionMethod: ExtractionMethod
    public let confidence: Double
    public let reviewState: ReviewState
    /// User-corrected value text, set only when `reviewState == .corrected`.
    public let correctedValueRaw: String?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageID: UUID,
        boundingBox: NormalizedRect,
        analyteRaw: String,
        valueRaw: String,
        unitRaw: String,
        refRangeRaw: String,
        flagRaw: String? = nil,
        collectedAtRaw: String? = nil,
        extractionMethod: ExtractionMethod,
        confidence: Double,
        reviewState: ReviewState = .pending,
        correctedValueRaw: String? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageID = pageID
        self.boundingBox = boundingBox
        self.analyteRaw = analyteRaw
        self.valueRaw = valueRaw
        self.unitRaw = unitRaw
        self.refRangeRaw = refRangeRaw
        self.flagRaw = flagRaw
        self.collectedAtRaw = collectedAtRaw
        self.extractionMethod = extractionMethod
        self.confidence = confidence
        self.reviewState = reviewState
        self.correctedValueRaw = correctedValueRaw
    }

    /// Immutable update helpers (coding standard: never mutate in place).
    public func reviewed(as state: ReviewState, correctedValueRaw: String? = nil) -> ExtractedValue {
        ExtractedValue(
            id: id, documentID: documentID, pageID: pageID, boundingBox: boundingBox,
            analyteRaw: analyteRaw, valueRaw: valueRaw, unitRaw: unitRaw, refRangeRaw: refRangeRaw,
            flagRaw: flagRaw, collectedAtRaw: collectedAtRaw, extractionMethod: extractionMethod,
            confidence: confidence, reviewState: state, correctedValueRaw: correctedValueRaw
        )
    }

    /// Re-tag the extraction method. The pipeline uses this to force
    /// `.llm` on anything returned by a model provider, so a misbehaving
    /// provider can never smuggle values in as "deterministic".
    public func retagged(as method: ExtractionMethod) -> ExtractedValue {
        ExtractedValue(
            id: id, documentID: documentID, pageID: pageID, boundingBox: boundingBox,
            analyteRaw: analyteRaw, valueRaw: valueRaw, unitRaw: unitRaw, refRangeRaw: refRangeRaw,
            flagRaw: flagRaw, collectedAtRaw: collectedAtRaw, extractionMethod: method,
            confidence: confidence, reviewState: reviewState, correctedValueRaw: correctedValueRaw
        )
    }
}
