import Foundation
import Testing
@testable import VellumCore
@testable import VellumReview

func proposal(
    analyte: String = "POTASSIUM",
    value: String = "4.2",
    unit: String = "mmol/L",
    range: String = "3.5-5.3",
    method: ExtractionMethod = .deterministic,
    confidence: Double = 0.99,
    state: ReviewState = .pending,
    collectedAtRaw: String? = "04/12/2026 08:15"
) -> ExtractedValue {
    ExtractedValue(
        documentID: UUID(),
        pageID: UUID(),
        boundingBox: NormalizedRect(x: 0, y: 0.5, width: 1, height: 0.05),
        analyteRaw: analyte,
        valueRaw: value,
        unitRaw: unit,
        refRangeRaw: range,
        collectedAtRaw: collectedAtRaw,
        extractionMethod: method,
        confidence: confidence,
        reviewState: state
    )
}

@Suite("Review session state machine (PRODUCT INVARIANT #3)")
struct ReviewSessionTests {
    @Test("Every proposal enters review as pending — whatever the caller claims")
    func everythingEntersPending() {
        let sneaky = proposal(state: .confirmed)
        let session = ReviewSession(documentID: UUID(), proposals: [sneaky])
        #expect(session.values.allSatisfy { $0.reviewState == .pending })
        #expect(!session.isComplete)
    }

    @Test("Confirm, correct and reject resolve values immutably")
    func resolveActions() throws {
        let a = proposal(analyte: "POTASSIUM")
        let b = proposal(analyte: "GLUCOSE", value: "110", unit: "mg/dL", range: "65-99")
        let c = proposal(analyte: "SODIUM", value: "139", range: "135-146")
        let start = ReviewSession(documentID: UUID(), proposals: [a, b, c])

        let done = try start.confirming(a.id).correcting(b.id, valueRaw: "101").rejecting(c.id)

        #expect(start.values.allSatisfy { $0.reviewState == .pending }, "sessions are immutable values")
        #expect(done.isComplete)
        #expect(done.values[0].reviewState == .confirmed)
        #expect(done.values[1].reviewState == .corrected)
        #expect(done.values[1].correctedValueRaw == "101")
        #expect(done.values[2].reviewState == .rejected)
    }

    @Test("Unknown IDs and double-resolution are typed errors")
    func resolutionErrors() throws {
        let a = proposal()
        let session = try ReviewSession(documentID: UUID(), proposals: [a]).confirming(a.id)
        #expect(throws: ReviewError.unknownValueID(UUID(0))) {
            _ = try session.confirming(UUID(0))
        }
        #expect(throws: ReviewError.valueAlreadyResolved(a.id)) {
            _ = try session.rejecting(a.id)
        }
    }

    @Test("Corrections must be numeric")
    func correctionMustBeNumeric() {
        let a = proposal()
        let session = ReviewSession(documentID: UUID(), proposals: [a])
        #expect(throws: ReviewError.correctionNotANumber(raw: "high")) {
            _ = try session.correcting(a.id, valueRaw: "high")
        }
    }
}

@Suite("Bulk-confirm rules (no bulk-confirm on LLM rows — DESIGN.md flow 1)")
struct BulkConfirmTests {
    @Test("Bulk-confirm REFUSES any selection containing an LLM row")
    func llmRowsForbidden() {
        let det = proposal()
        let llm = proposal(analyte: "GLUCOSE", method: .llm)
        let session = ReviewSession(documentID: UUID(), proposals: [det, llm])
        #expect(throws: ReviewError.bulkConfirmForbiddenForLLMRows(offendingIDs: [llm.id])) {
            _ = try session.bulkConfirming([det.id, llm.id])
        }
    }

    @Test("Bulk-confirm refuses deterministic rows below the confidence floor")
    func lowConfidenceForbidden() {
        let low = proposal(confidence: 0.8)
        let session = ReviewSession(documentID: UUID(), proposals: [low])
        #expect(throws: ReviewError.bulkConfirmBelowConfidenceFloor(offendingIDs: [low.id])) {
            _ = try session.bulkConfirming([low.id])
        }
    }

    @Test("Eligible-rows convenience structurally skips LLM and low-confidence rows")
    func eligibleConvenienceSkipsIneligible() throws {
        let det = proposal()
        let llm = proposal(analyte: "GLUCOSE", method: .llm)
        let low = proposal(analyte: "SODIUM", confidence: 0.5)
        let session = try ReviewSession(documentID: UUID(), proposals: [det, llm, low])
            .bulkConfirmingEligibleDeterministicRows()

        #expect(session.values.first { $0.id == det.id }?.reviewState == .confirmed)
        #expect(session.values.first { $0.id == llm.id }?.reviewState == .pending, "LLM rows stay individually confirmed")
        #expect(session.values.first { $0.id == low.id }?.reviewState == .pending)
    }
}

private extension UUID {
    init(_ value: UInt8) {
        self.init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
