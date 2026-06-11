import Foundation
import Testing
@testable import VellumAsk
@testable import VellumCore

func confirmedResult(profileID: UUID, analyteID: AnalyteID, value: String, collectedAt: TimeInterval, documentID: UUID) -> LabResult {
    LabResult(
        rehydratingID: UUID(),
        profileID: profileID,
        analyteID: analyteID,
        value: Decimal(string: value)!,
        unit: .mmolPerL,
        referenceRange: ReferenceRange(low: Decimal(string: "3.5"), high: Decimal(string: "5.3"), rawText: "3.5-5.3"),
        collectedAt: Date(timeIntervalSince1970: collectedAt),
        provenance: Provenance(
            documentID: documentID,
            pageID: UUID(),
            boundingBox: .zero,
            extractionMethod: .deterministic
        ),
        reviewReceiptID: UUID()
    )
}

@Suite("Local record search (answers cite sources; misses never guess)")
struct LocalRecordSearchTests {
    let profileID = UUID()
    let search = LocalRecordSearch()

    @Test("Finds the latest matching observation and cites its source document")
    func findsLatestAndCites() {
        let olderDoc = UUID()
        let latestDoc = UUID()
        let results = [
            confirmedResult(profileID: profileID, analyteID: .potassium, value: "4.2", collectedAt: 1_775_981_700, documentID: olderDoc),
            confirmedResult(profileID: profileID, analyteID: .potassium, value: "5.6", collectedAt: 1_779_262_800, documentID: latestDoc),
        ]

        let answer = search.answer(question: "What was Dad's last potassium reading?", over: results)

        #expect(!answer.isNotFound)
        #expect(answer.citedDocumentIDs == [latestDoc], "every answer must cite its source document")
        #expect(answer.text.contains("5.6"))
        #expect(answer.text.contains("Potassium"))
        #expect(answer.text.contains("May 20, 2026"))
    }

    @Test("Multi-word aliases match with punctuation in the question")
    func multiWordAliasMatches() {
        let doc = UUID()
        let results = [confirmedResult(
            profileID: profileID,
            analyteID: .plateletCount,
            value: "251",
            collectedAt: 1_772_409_600,
            documentID: doc
        )]

        let answer = search.answer(question: "what's the platelet count?", over: results)

        #expect(answer.citedDocumentIDs == [doc])
    }

    @Test("No analyte in the question → explicit not-found, zero citations, never a guess")
    func unknownTopicIsNotFound() {
        let results = [confirmedResult(
            profileID: profileID,
            analyteID: .potassium,
            value: "4.2",
            collectedAt: 1_775_981_700,
            documentID: UUID()
        )]

        let answer = search.answer(question: "When was the last tetanus shot?", over: results)

        #expect(answer == AskAnswer(text: LocalRecordSearch.notFoundText, citedDocumentIDs: []))
    }

    @Test("Analyte mentioned but no confirmed records → not-found, not a fabrication")
    func noRecordsIsNotFound() {
        let answer = search.answer(question: "potassium?", over: [])
        #expect(answer.isNotFound)
        #expect(answer.text == LocalRecordSearch.notFoundText)
    }
}
