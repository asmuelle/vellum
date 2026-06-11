import Foundation

/// Why the deterministic layer declined a page.
public enum DeterministicMissReason: Sendable, Equatable {
    case unknownFormat
    case coverageBelowThreshold(coverage: Double, threshold: Double)
}

public enum DeterministicOutcome: Sendable, Equatable {
    case claimed(format: LabFormat, values: [ExtractedValue], coverage: Double)
    case miss(DeterministicMissReason)
}

/// PRODUCT INVARIANT #2 seam: the extraction pipeline depends on this
/// protocol (defined in Core), `VellumParsing`'s registry implements it,
/// and the LLM fallback may only run on `.miss`.
public protocol DeterministicExtracting: Sendable {
    func extract(from page: OCRPage, documentID: UUID) -> DeterministicOutcome
}
