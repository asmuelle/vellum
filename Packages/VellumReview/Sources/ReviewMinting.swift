import Foundation
import VellumCore

/// The output of a completed review: confirmed results plus their receipts.
public struct ReviewOutcome: Sendable {
    public let results: [LabResult]
    public let receipts: [ReviewReceipt]
    public let rejectedValueIDs: [UUID]
}

public extension ReviewSession {
    /// Mint `LabResult`s from a COMPLETE session. This is the only place
    /// in the codebase that creates `ReviewReceipt`s (sole-minter
    /// invariant, enforced by a source-scan test). Values are normalized
    /// to the analyte's canonical unit here, in code — never by a model
    /// (invariant #4) — and the printed reference range is converted with
    /// the same table.
    func mintConfirmedResults(
        profileID: UUID,
        catalog: AnalyteCatalog = .standard,
        conversions: UnitConversionTable = .standard,
        now: Date = Date()
    ) throws -> ReviewOutcome {
        guard isComplete else {
            throw ReviewError.sessionIncomplete(pendingCount: pendingValues.count)
        }
        var results: [LabResult] = []
        var receipts: [ReviewReceipt] = []
        var rejected: [UUID] = []
        for value in values {
            switch value.reviewState {
            case .rejected:
                rejected.append(value.id)
            case .confirmed, .corrected:
                let receipt = ReviewReceipt(extractedValueID: value.id, confirmedAt: now, resolution: value.reviewState)
                let result = try mintResult(from: value, receipt: receipt, profileID: profileID, catalog: catalog, conversions: conversions)
                receipts.append(receipt)
                results.append(result)
            case .pending:
                throw ReviewError.sessionIncomplete(pendingCount: pendingValues.count)
            }
        }
        return ReviewOutcome(results: results, receipts: receipts, rejectedValueIDs: rejected)
    }

    private func mintResult(
        from value: ExtractedValue,
        receipt: ReviewReceipt,
        profileID: UUID,
        catalog: AnalyteCatalog,
        conversions: UnitConversionTable
    ) throws -> LabResult {
        guard let analyte = catalog.analyte(matchingRawName: value.analyteRaw) else {
            throw ReviewError.unknownAnalyte(rawName: value.analyteRaw)
        }
        let rawText = value.correctedValueRaw ?? value.valueRaw
        guard case let .success(rawDecimal) = LabValueParser.parseDecimal(rawText) else {
            throw ReviewError.unparseableValue(raw: rawText)
        }
        guard case let .success(printedRange) = ReferenceRange.parse(value.refRangeRaw) else {
            throw ReviewError.unparseableRange(raw: value.refRangeRaw)
        }
        guard let collectedRaw = value.collectedAtRaw else {
            throw ReviewError.missingCollectionDate(valueID: value.id)
        }
        guard let collectedAt = CollectedDateParser.parse(collectedRaw) else {
            throw ReviewError.unparseableCollectionDate(raw: collectedRaw)
        }
        let sourceUnit = LabUnit(value.unitRaw)
        guard case let .success(canonicalValue) = conversions.convert(
            rawDecimal,
            of: analyte.id,
            from: sourceUnit,
            to: analyte.canonicalUnit
        ),
            case let .success(canonicalRange) = printedRange.converted(
                of: analyte.id, from: sourceUnit, to: analyte.canonicalUnit, using: conversions
            )
        else {
            throw ReviewError.unitNormalizationFailed(analyte: analyte.id, from: sourceUnit, to: analyte.canonicalUnit)
        }
        return LabResult(
            receipt: receipt,
            profileID: profileID,
            analyteID: analyte.id,
            value: canonicalValue,
            unit: analyte.canonicalUnit,
            referenceRange: canonicalRange,
            collectedAt: collectedAt,
            provenance: Provenance(
                documentID: value.documentID,
                pageID: value.pageID,
                boundingBox: value.boundingBox,
                extractionMethod: value.extractionMethod
            )
        )
    }
}
