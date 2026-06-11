import Foundation
import VellumCore

/// The encrypted, backup-excluded store (PRODUCT INVARIANT #5).
///
/// An actor: the SQLite handle is confined here. On creation the store
/// applies `NSFileProtectionComplete` to the vault directory and the
/// database file and excludes the directory from backup; a test asserts
/// both on the live store URL.
///
/// Only already-minted `LabResult`s enter (`save`), and rows read back
/// rehydrate through `LabResult`'s package-access initializer — the
/// review flow remains the sole public mint path (invariant #3).
public actor VaultStore {
    public let vaultDirectoryURL: URL
    public let databaseURL: URL
    private let database: SQLiteDatabase

    public init(directory: URL, protection: any FileProtectionApplying = DefaultFileProtectionApplier()) throws {
        vaultDirectoryURL = directory
        databaseURL = directory.appendingPathComponent("vellum.sqlite", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw VaultError.directoryCreationFailed(path: directory.path, description: String(describing: error))
        }
        database = try SQLiteDatabase(path: databaseURL.path)
        try database.execute(Self.schema)
        try protection.applyCompleteFileProtection(to: directory)
        try protection.applyCompleteFileProtection(to: databaseURL)
        try protection.excludeFromBackup(directory)
    }

    private static let schema = """
    CREATE TABLE IF NOT EXISTS lab_result (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        analyte_id TEXT NOT NULL,
        value TEXT NOT NULL,
        unit TEXT NOT NULL,
        ref_low TEXT,
        ref_high TEXT,
        ref_raw TEXT NOT NULL,
        collected_at INTEGER NOT NULL,
        document_id TEXT NOT NULL,
        page_id TEXT NOT NULL,
        bbox_x TEXT NOT NULL,
        bbox_y TEXT NOT NULL,
        bbox_w TEXT NOT NULL,
        bbox_h TEXT NOT NULL,
        extraction_method TEXT NOT NULL,
        review_receipt_id TEXT NOT NULL
    );
    """

    public func save(_ result: LabResult) throws {
        try database.run(
            """
            INSERT OR REPLACE INTO lab_result
            (id, profile_id, analyte_id, value, unit, ref_low, ref_high, ref_raw, collected_at,
             document_id, page_id, bbox_x, bbox_y, bbox_w, bbox_h, extraction_method, review_receipt_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(result.id.uuidString),
                .text(result.profileID.uuidString),
                .text(result.analyteID.rawValue),
                .text(String(describing: result.value)),
                .text(result.unit.symbol),
                result.referenceRange.low.map { .text(String(describing: $0)) } ?? .null,
                result.referenceRange.high.map { .text(String(describing: $0)) } ?? .null,
                .text(result.referenceRange.rawText),
                .int(Int64(result.collectedAt.timeIntervalSince1970.rounded())),
                .text(result.provenance.documentID.uuidString),
                .text(result.provenance.pageID.uuidString),
                .text(String(result.provenance.boundingBox.x)),
                .text(String(result.provenance.boundingBox.y)),
                .text(String(result.provenance.boundingBox.width)),
                .text(String(result.provenance.boundingBox.height)),
                .text(result.provenance.extractionMethod.rawValue),
                .text(result.reviewReceiptID.uuidString),
            ]
        )
    }

    public func save(_ results: [LabResult]) throws {
        for result in results {
            try save(result)
        }
    }

    /// All confirmed results for a profile, oldest collection first.
    public func results(profileID: UUID) throws -> [LabResult] {
        let rows = try database.query(
            "SELECT * FROM lab_result WHERE profile_id = ? ORDER BY collected_at ASC, id ASC",
            bindings: [.text(profileID.uuidString)]
        )
        return try rows.map { try Self.rehydrate(row: $0) }
    }

    public func results(profileID: UUID, analyteID: AnalyteID) throws -> [LabResult] {
        let rows = try database.query(
            "SELECT * FROM lab_result WHERE profile_id = ? AND analyte_id = ? ORDER BY collected_at ASC, id ASC",
            bindings: [.text(profileID.uuidString), .text(analyteID.rawValue)]
        )
        return try rows.map { try Self.rehydrate(row: $0) }
    }

    // MARK: Rehydration

    private static func rehydrate(row: [String?]) throws -> LabResult {
        guard
            row.count == 17,
            let id = row[0].flatMap(UUID.init(uuidString:)),
            let profileID = row[1].flatMap(UUID.init(uuidString:)),
            let analyteID = row[2].flatMap(AnalyteID.init(rawValue:)),
            let value = row[3].flatMap({ Decimal(string: $0) }),
            let unitSymbol = row[4],
            let refRaw = row[7],
            let collectedAtSeconds = row[8].flatMap(Int64.init),
            let documentID = row[9].flatMap(UUID.init(uuidString:)),
            let pageID = row[10].flatMap(UUID.init(uuidString:)),
            let bboxX = row[11].flatMap(Double.init),
            let bboxY = row[12].flatMap(Double.init),
            let bboxW = row[13].flatMap(Double.init),
            let bboxH = row[14].flatMap(Double.init),
            let method = row[15].flatMap(ExtractionMethod.init(rawValue:)),
            let receiptID = row[16].flatMap(UUID.init(uuidString:))
        else {
            throw VaultError.corruptRow(table: "lab_result", description: "unparseable row: \(row)")
        }
        let low = row[5].flatMap { Decimal(string: $0) }
        let high = row[6].flatMap { Decimal(string: $0) }
        return LabResult(
            rehydratingID: id,
            profileID: profileID,
            analyteID: analyteID,
            value: value,
            unit: LabUnit(unitSymbol),
            referenceRange: ReferenceRange(low: low, high: high, rawText: refRaw),
            collectedAt: Date(timeIntervalSince1970: TimeInterval(collectedAtSeconds)),
            provenance: Provenance(
                documentID: documentID,
                pageID: pageID,
                boundingBox: NormalizedRect(x: bboxX, y: bboxY, width: bboxW, height: bboxH),
                extractionMethod: method
            ),
            reviewReceiptID: receiptID
        )
    }
}
