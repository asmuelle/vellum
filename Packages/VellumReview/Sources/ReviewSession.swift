import Foundation
import VellumCore

/// The per-value human-confirmation state machine (PRODUCT INVARIANT #3).
///
/// Value semantics: every action returns a NEW session. 100% of extracted
/// values pass through here — minting requires every value to be resolved
/// (confirmed / corrected / rejected), and `VellumReview` is the sole
/// minter of `ReviewReceipt`s and therefore of `LabResult`s.
public struct ReviewSession: Sendable, Equatable {
    public static let bulkConfirmConfidenceFloor = 0.95

    public let documentID: UUID
    public let values: [ExtractedValue]

    public init(documentID: UUID, proposals: [ExtractedValue]) {
        self.documentID = documentID
        // Everything enters review as pending, whatever the caller claims.
        values = proposals.map { $0.reviewed(as: .pending) }
    }

    private init(documentID: UUID, reviewedValues: [ExtractedValue]) {
        self.documentID = documentID
        values = reviewedValues
    }

    public var pendingValues: [ExtractedValue] {
        values.filter { $0.reviewState == .pending }
    }

    public var isComplete: Bool {
        pendingValues.isEmpty
    }

    // MARK: Actions (immutable updates)

    public func confirming(_ id: UUID) throws -> ReviewSession {
        try resolving(id, to: .confirmed, correctedValueRaw: nil)
    }

    public func correcting(_ id: UUID, valueRaw: String) throws -> ReviewSession {
        guard case .success = LabValueParser.parseDecimal(valueRaw) else {
            throw ReviewError.correctionNotANumber(raw: valueRaw)
        }
        return try resolving(id, to: .corrected, correctedValueRaw: valueRaw)
    }

    public func rejecting(_ id: UUID) throws -> ReviewSession {
        try resolving(id, to: .rejected, correctedValueRaw: nil)
    }

    /// Bulk-confirm a set of rows. Throws if ANY row is LLM-extracted or
    /// below the confidence floor — LLM rows must be confirmed one by one.
    public func bulkConfirming(_ ids: [UUID]) throws -> ReviewSession {
        let selected = values.filter { ids.contains($0.id) }
        let llmRows = selected.filter { $0.extractionMethod == .llm }
        guard llmRows.isEmpty else {
            throw ReviewError.bulkConfirmForbiddenForLLMRows(offendingIDs: llmRows.map(\.id))
        }
        let lowConfidence = selected.filter { $0.confidence < Self.bulkConfirmConfidenceFloor }
        guard lowConfidence.isEmpty else {
            throw ReviewError.bulkConfirmBelowConfidenceFloor(offendingIDs: lowConfidence.map(\.id))
        }
        return try ids.reduce(self) { session, id in try session.confirming(id) }
    }

    /// Convenience: bulk-confirm every pending deterministic row at or
    /// above the confidence floor. Structurally cannot touch LLM rows.
    public func bulkConfirmingEligibleDeterministicRows() throws -> ReviewSession {
        let eligible = pendingValues
            .filter { $0.extractionMethod == .deterministic && $0.confidence >= Self.bulkConfirmConfidenceFloor }
            .map(\.id)
        return try bulkConfirming(eligible)
    }

    private func resolving(_ id: UUID, to state: ReviewState, correctedValueRaw: String?) throws -> ReviewSession {
        guard let index = values.firstIndex(where: { $0.id == id }) else {
            throw ReviewError.unknownValueID(id)
        }
        guard values[index].reviewState == .pending else {
            throw ReviewError.valueAlreadyResolved(id)
        }
        let updated = values.enumerated().map { offset, value in
            offset == index ? value.reviewed(as: state, correctedValueRaw: correctedValueRaw) : value
        }
        return ReviewSession(documentID: documentID, reviewedValues: updated)
    }
}
