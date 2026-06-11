import Foundation
import Testing
@testable import VellumCore
@testable import VellumTrends
@testable import VellumVault

func trendResult(
    profileID: UUID,
    analyteID: AnalyteID = .potassium,
    value: String,
    low: String = "3.5",
    high: String = "5.3",
    collectedAt: TimeInterval,
    documentID: UUID = UUID()
) -> LabResult {
    LabResult(
        rehydratingID: UUID(),
        profileID: profileID,
        analyteID: analyteID,
        value: Decimal(string: value)!,
        unit: .mmolPerL,
        referenceRange: ReferenceRange(low: Decimal(string: low), high: Decimal(string: high), rawText: "\(low)-\(high)"),
        collectedAt: Date(timeIntervalSince1970: collectedAt),
        provenance: Provenance(
            documentID: documentID,
            pageID: UUID(),
            boundingBox: NormalizedRect(x: 0, y: 0.4, width: 1, height: 0.05),
            extractionMethod: .deterministic
        ),
        reviewReceiptID: UUID()
    )
}

@Suite("Trend series (confirmed LabResults only — PRODUCT INVARIANT #3)")
struct TrendSeriesTests {
    let profileID = UUID()

    @Test("Builds a sorted series for one analyte across two documents")
    func sortedSeriesAcrossDocuments() throws {
        let docA = UUID()
        let docB = UUID()
        let newer = trendResult(profileID: profileID, value: "5.6", collectedAt: 1_779_262_800, documentID: docB)
        let older = trendResult(profileID: profileID, value: "4.2", collectedAt: 1_775_981_700, documentID: docA)
        let unrelated = trendResult(
            profileID: profileID,
            analyteID: .sodium,
            value: "139",
            low: "135",
            high: "146",
            collectedAt: 1_775_981_700
        )

        let series = TrendSeries(analyteID: .potassium, results: [newer, older, unrelated])

        #expect(series.points.count == 2)
        #expect(try series.points.map(\.value) == [#require(Decimal(string: "4.2")), #require(Decimal(string: "5.6"))])
        #expect(series.documentCount == 2)
        #expect(series.latest?.value == Decimal(string: "5.6")!)
    }

    @Test("Each point classifies against the range printed on ITS OWN document")
    func perDocumentPrintedRanges() {
        // Same value, two documents with different printed ranges.
        let strictDoc = trendResult(profileID: profileID, value: "5.0", low: "3.5", high: "4.8", collectedAt: 1_775_981_700)
        let lenientDoc = trendResult(profileID: profileID, value: "5.0", low: "3.5", high: "5.3", collectedAt: 1_779_262_800)

        let series = TrendSeries(analyteID: .potassium, results: [strictDoc, lenientDoc])

        #expect(series.points[0].status == .aboveRange, "5.0 vs that document's printed 3.5-4.8")
        #expect(series.points[1].status == .inRange, "5.0 vs that document's printed 3.5-5.3")
    }

    @Test("Empty input is an empty series, not a crash")
    func emptySeries() {
        let series = TrendSeries(analyteID: .potassium, results: [])
        #expect(series.points.isEmpty)
        #expect(series.latest == nil)
        #expect(series.documentCount == 0)
    }

    @Test("Loads a series for one analyte from the vault across documents")
    func loadsFromVault() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vellum-trends-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try VaultStore(directory: directory)
        try await store.save([
            trendResult(profileID: profileID, value: "4.2", collectedAt: 1_775_981_700),
            trendResult(profileID: profileID, value: "5.6", collectedAt: 1_779_262_800),
            trendResult(profileID: profileID, analyteID: .glucose, value: "94", low: "65", high: "99", collectedAt: 1_779_262_800),
        ])

        let series = try await TrendLoader.series(for: .potassium, profileID: profileID, from: store)

        #expect(try series.points.map(\.value) == [#require(Decimal(string: "4.2")), #require(Decimal(string: "5.6"))])
        #expect(series.documentCount == 2)
    }
}
