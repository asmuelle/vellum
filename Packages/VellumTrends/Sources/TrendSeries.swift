import Foundation
import VellumCore
import VellumVault

/// One confirmed observation positioned on a trend. Out-of-range status
/// comes from the reference range printed on the document that point
/// came from — never a hardcoded range (DESIGN.md flow 1).
public struct TrendPoint: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let collectedAt: Date
    public let value: Decimal
    public let unit: LabUnit
    public let status: RangeStatus
    public let printedRange: ReferenceRange
    public let provenance: Provenance

    public init(result: LabResult) {
        id = result.id
        collectedAt = result.collectedAt
        value = result.value
        unit = result.unit
        status = result.referenceRange.classify(result.value)
        printedRange = result.referenceRange
        provenance = result.provenance
    }
}

/// A longitudinal series for one analyte, built from confirmed
/// `LabResult`s ONLY (PRODUCT INVARIANT #3 — this module never sees an
/// unconfirmed proposal; the initializer's parameter type is the enforcement).
public struct TrendSeries: Sendable, Hashable {
    public let analyteID: AnalyteID
    /// Sorted by collection date, oldest first.
    public let points: [TrendPoint]

    public init(analyteID: AnalyteID, results: [LabResult]) {
        self.analyteID = analyteID
        points = results
            .filter { $0.analyteID == analyteID }
            .sorted { $0.collectedAt < $1.collectedAt }
            .map(TrendPoint.init(result:))
    }

    public var latest: TrendPoint? {
        points.last
    }

    /// Distinct source documents feeding this series.
    public var documentCount: Int {
        Set(points.map(\.provenance.documentID)).count
    }
}

/// Bridges the vault to a series. Reads confirmed results only — the
/// vault stores nothing else.
public enum TrendLoader {
    public static func series(for analyteID: AnalyteID, profileID: UUID, from store: VaultStore) async throws -> TrendSeries {
        let results = try await store.results(profileID: profileID, analyteID: analyteID)
        return TrendSeries(analyteID: analyteID, results: results)
    }
}
