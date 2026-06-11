import Foundation
import Testing
import VellumCapture
@testable import VellumCore
import VellumParsing
@testable import VellumReview
import VellumTestSupport

@Suite("Minting LabResults from a completed review")
struct ReviewMintingTests {
    let profileID = UUID()

    func claimedValues(fixture: String) throws -> [ExtractedValue] {
        let page = try OCRPageFactory.page(fromPlainText: FixtureLoader.text(named: fixture))
        let outcome = ParserRegistry().extract(from: page, documentID: UUID())
        guard case let .claimed(_, values, _) = outcome else {
            throw FixtureError.missingFixture(fixture)
        }
        return values
    }

    @Test("Minting requires a COMPLETE session — 100% of values pass through review")
    func mintingRequiresCompleteSession() throws {
        let values = try claimedValues(fixture: "quest_cmp_2026-04-12.txt")
        let session = ReviewSession(documentID: values[0].documentID, proposals: values)
        #expect(throws: ReviewError.sessionIncomplete(pendingCount: values.count)) {
            _ = try session.mintConfirmedResults(profileID: profileID)
        }
    }

    @Test("A fully confirmed Quest CMP mints canonical-unit results with provenance")
    func mintsQuestPanel() throws {
        let values = try claimedValues(fixture: "quest_cmp_2026-04-12.txt")
        var session = ReviewSession(documentID: values[0].documentID, proposals: values)
        for value in session.values {
            session = try session.confirming(value.id)
        }

        let outcome = try session.mintConfirmedResults(profileID: profileID)

        #expect(outcome.results.count == 15)
        #expect(outcome.receipts.count == 15)
        #expect(outcome.rejectedValueIDs.isEmpty)

        let potassium = try #require(outcome.results.first { $0.analyteID == .potassium })
        #expect(potassium.value == Decimal(string: "4.2")!)
        #expect(potassium.unit == .mmolPerL)
        #expect(potassium.collectedAt == Date(timeIntervalSince1970: 1_775_981_700)) // 04/12/2026 08:15 UTC
        #expect(potassium.referenceRange.classify(potassium.value) == .inRange)
        #expect(potassium.provenance.extractionMethod == .deterministic)
        #expect(potassium.provenance.boundingBox.height > 0)
        #expect(potassium.profileID == profileID)

        let glucose = try #require(outcome.results.first { $0.analyteID == .glucose })
        #expect(glucose.referenceRange.classify(glucose.value) == .aboveRange, "110 vs printed 65-99")
    }

    @Test("Labcorp mEq/L values are normalized to mmol/L in code (invariant #4)")
    func normalizesLabcorpUnitsInCode() throws {
        let values = try claimedValues(fixture: "labcorp_cbc_2026-03-02.txt")
        let session = try ReviewSession(documentID: values[0].documentID, proposals: values)
            .bulkConfirmingEligibleDeterministicRows()

        let outcome = try session.mintConfirmedResults(profileID: profileID)

        let potassium = try #require(outcome.results.first { $0.analyteID == .potassium })
        #expect(potassium.unit == .mmolPerL, "canonical unit, converted from the printed mEq/L")
        #expect(potassium.value == Decimal(string: "4.4")!)
        #expect(potassium.referenceRange.low == Decimal(string: "3.5")!)
        #expect(potassium.referenceRange.high == Decimal(string: "5.2")!)
        #expect(potassium.referenceRange.rawText == "3.5-5.2", "printed text preserved for provenance")
    }

    @Test("Corrected values mint with the corrected number")
    func correctedValuesMint() throws {
        let values = try claimedValues(fixture: "quest_bmp_2026-05-20.txt")
        var session = ReviewSession(documentID: values[0].documentID, proposals: values)
        let potassiumRow = try #require(session.values.first { $0.analyteRaw == "POTASSIUM" })
        session = try session.correcting(potassiumRow.id, valueRaw: "4.6")
        for value in session.pendingValues {
            session = try session.confirming(value.id)
        }

        let outcome = try session.mintConfirmedResults(profileID: profileID)

        let potassium = try #require(outcome.results.first { $0.analyteID == .potassium })
        #expect(potassium.value == Decimal(string: "4.6")!)
        let receipt = try #require(outcome.receipts.first { $0.extractedValueID == potassiumRow.id })
        #expect(receipt.resolution == .corrected)
    }

    @Test("Rejected values never mint — they are listed, not stored")
    func rejectedValuesDoNotMint() throws {
        let values = try claimedValues(fixture: "quest_bmp_2026-05-20.txt")
        var session = ReviewSession(documentID: values[0].documentID, proposals: values)
        let rejectedID = session.values[0].id
        session = try session.rejecting(rejectedID)
        for value in session.pendingValues {
            session = try session.confirming(value.id)
        }

        let outcome = try session.mintConfirmedResults(profileID: profileID)

        #expect(outcome.rejectedValueIDs == [rejectedID])
        #expect(outcome.results.count == values.count - 1)
        #expect(outcome.receipts.count == values.count - 1, "no receipt is ever minted for a rejected value")
    }

    @Test("Unknown analytes fail minting as typed errors")
    func unknownAnalyteFails() throws {
        let stranger = proposal(analyte: "KRYPTONITE")
        let session = try ReviewSession(documentID: UUID(), proposals: [stranger]).confirming(stranger.id)
        #expect(throws: ReviewError.unknownAnalyte(rawName: "KRYPTONITE")) {
            _ = try session.mintConfirmedResults(profileID: profileID)
        }
    }

    @Test("Missing collection dates fail minting — results must be plottable")
    func missingCollectionDateFails() throws {
        let undated = proposal(collectedAtRaw: nil)
        let session = try ReviewSession(documentID: UUID(), proposals: [undated]).confirming(undated.id)
        #expect(throws: ReviewError.missingCollectionDate(valueID: undated.id)) {
            _ = try session.mintConfirmedResults(profileID: profileID)
        }
    }
}

@Suite("Collected date parsing")
struct CollectedDateParserTests {
    @Test("Parses Quest date-time and Labcorp date-only formats in UTC")
    func parsesBothFormats() {
        #expect(CollectedDateParser.parse("04/12/2026 08:15") == Date(timeIntervalSince1970: 1_775_981_700))
        #expect(CollectedDateParser.parse("03/02/2026") == Date(timeIntervalSince1970: 1_772_409_600))
    }

    @Test("Unparseable dates are nil values, not crashes", arguments: ["", "yesterday", "2026-04-12"])
    func unparseableDates(raw: String) {
        #expect(CollectedDateParser.parse(raw) == nil)
    }
}
