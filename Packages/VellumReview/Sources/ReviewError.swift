import Foundation
import VellumCore

public enum ReviewError: Error, Equatable, Sendable {
    case unknownValueID(UUID)
    case valueAlreadyResolved(UUID)
    /// PRODUCT INVARIANT (DESIGN.md flow 1): bulk-confirm is allowed only
    /// for deterministic, high-confidence rows — never for LLM rows.
    case bulkConfirmForbiddenForLLMRows(offendingIDs: [UUID])
    case bulkConfirmBelowConfidenceFloor(offendingIDs: [UUID])
    case sessionIncomplete(pendingCount: Int)
    case unknownAnalyte(rawName: String)
    case unparseableValue(raw: String)
    case unparseableRange(raw: String)
    case missingCollectionDate(valueID: UUID)
    case unparseableCollectionDate(raw: String)
    case unitNormalizationFailed(analyte: AnalyteID, from: LabUnit, to: LabUnit)
    case correctionNotANumber(raw: String)
}
