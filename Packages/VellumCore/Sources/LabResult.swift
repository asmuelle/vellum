import Foundation

/// Proof that a human reviewed one extracted value.
///
/// PRODUCT INVARIANT #3: `LabResult` is constructible only with a
/// `ReviewReceipt`, and receipts can only be minted inside this package
/// (`package` access) — by `VellumReview`'s confirmation flow. A source-scan
/// invariant test (VellumReviewTests/SoleMinterInvariantTests) enforces that
/// no other module in the package calls this initializer.
public struct ReviewReceipt: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let extractedValueID: UUID
    public let confirmedAt: Date
    public let resolution: ReviewState

    package init(id: UUID = UUID(), extractedValueID: UUID, confirmedAt: Date, resolution: ReviewState) {
        self.id = id
        self.extractedValueID = extractedValueID
        self.confirmedAt = confirmedAt
        self.resolution = resolution
    }
}

/// Where a confirmed value came from — document, page, box on the page,
/// and how it was extracted. Provenance is first-class product surface.
public struct Provenance: Sendable, Codable, Hashable {
    public let documentID: UUID
    public let pageID: UUID
    public let boundingBox: NormalizedRect
    public let extractionMethod: ExtractionMethod

    public init(documentID: UUID, pageID: UUID, boundingBox: NormalizedRect, extractionMethod: ExtractionMethod) {
        self.documentID = documentID
        self.pageID = pageID
        self.boundingBox = boundingBox
        self.extractionMethod = extractionMethod
    }
}

/// A confirmed observation — the ONLY thing trends, RAG and explanations
/// may read. Value and reference range are in the analyte's canonical
/// unit, converted in code (invariant #4).
public struct LabResult: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let profileID: UUID
    public let analyteID: AnalyteID
    public let value: Decimal
    public let unit: LabUnit
    public let referenceRange: ReferenceRange
    public let collectedAt: Date
    public let provenance: Provenance
    public let reviewReceiptID: UUID

    /// The sole public constructor: requires a receipt (invariant #3).
    public init(
        receipt: ReviewReceipt,
        profileID: UUID,
        analyteID: AnalyteID,
        value: Decimal,
        unit: LabUnit,
        referenceRange: ReferenceRange,
        collectedAt: Date,
        provenance: Provenance
    ) {
        id = UUID()
        self.profileID = profileID
        self.analyteID = analyteID
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.collectedAt = collectedAt
        self.provenance = provenance
        reviewReceiptID = receipt.id
    }

    /// Rehydration path for the vault ONLY (already-minted rows read back
    /// from the encrypted store). Package access + source-scan test keep
    /// this out of reach of other modules and the app target.
    package init(
        rehydratingID id: UUID,
        profileID: UUID,
        analyteID: AnalyteID,
        value: Decimal,
        unit: LabUnit,
        referenceRange: ReferenceRange,
        collectedAt: Date,
        provenance: Provenance,
        reviewReceiptID: UUID
    ) {
        self.id = id
        self.profileID = profileID
        self.analyteID = analyteID
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.collectedAt = collectedAt
        self.provenance = provenance
        self.reviewReceiptID = reviewReceiptID
    }
}
