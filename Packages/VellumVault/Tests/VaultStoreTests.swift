import Foundation
import Testing
@testable import VellumCore
@testable import VellumVault

/// Records every protection call so tests can assert the vault applies
/// NSFileProtectionComplete + backup exclusion to its live URLs.
final class RecordingProtectionApplier: FileProtectionApplying, @unchecked Sendable {
    // @unchecked: mutated only before the store is shared, inside the
    // synchronous VaultStore initializer on the test's task.
    private(set) var protectedPaths: [String] = []
    private(set) var backupExcludedPaths: [String] = []

    func applyCompleteFileProtection(to url: URL) throws {
        protectedPaths.append(url.path)
    }

    func excludeFromBackup(_ url: URL) throws {
        backupExcludedPaths.append(url.path)
    }
}

func temporaryVaultDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("vellum-vault-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

func makeResult(
    profileID: UUID,
    analyteID: AnalyteID = .potassium,
    value: String = "4.2",
    unit: LabUnit = .mmolPerL,
    low: String? = "3.5",
    high: String? = "5.3",
    collectedAt: Date = Date(timeIntervalSince1970: 1_775_981_700),
    documentID: UUID = UUID(),
    method: ExtractionMethod = .deterministic
) -> LabResult {
    LabResult(
        rehydratingID: UUID(),
        profileID: profileID,
        analyteID: analyteID,
        value: Decimal(string: value)!,
        unit: unit,
        referenceRange: ReferenceRange(
            low: low.flatMap { Decimal(string: $0) },
            high: high.flatMap { Decimal(string: $0) },
            rawText: "\(low ?? "")-\(high ?? "")"
        ),
        collectedAt: collectedAt,
        provenance: Provenance(
            documentID: documentID,
            pageID: UUID(),
            boundingBox: NormalizedRect(x: 0, y: 0.25, width: 1, height: 0.05),
            extractionMethod: method
        ),
        reviewReceiptID: UUID()
    )
}

@Suite("Vault store (PRODUCT INVARIANT #5)")
struct VaultStoreTests {
    @Test("Applies complete file protection and backup exclusion to the live store URLs")
    func appliesProtectionOnCreation() throws {
        let directory = temporaryVaultDirectory()
        let applier = RecordingProtectionApplier()

        let store = try VaultStore(directory: directory, protection: applier)

        #expect(applier.protectedPaths.contains(directory.path))
        #expect(applier.backupExcludedPaths.contains(directory.path))
        let dbPath = applier.protectedPaths.first { $0.hasSuffix("vellum.sqlite") }
        #expect(dbPath != nil, "the database file itself must be protected")
        _ = store
    }

    @Test("The live vault directory is excluded from backup (default applier)")
    func liveDirectoryIsBackupExcluded() throws {
        let directory = temporaryVaultDirectory()
        _ = try VaultStore(directory: directory)

        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("Round-trips every LabResult field exactly")
    func roundTripsAllFields() async throws {
        let profileID = UUID()
        let store = try VaultStore(directory: temporaryVaultDirectory())
        let original = makeResult(profileID: profileID)

        try await store.save(original)
        let loaded = try await store.results(profileID: profileID)

        #expect(loaded == [original])
    }

    @Test("Open-ended reference ranges (nil bounds) survive the round-trip")
    func roundTripsOpenEndedRanges() async throws {
        let profileID = UUID()
        let store = try VaultStore(directory: temporaryVaultDirectory())
        let original = makeResult(profileID: profileID, analyteID: .egfr, value: "92", unit: .mlPerMinPer173, low: "59", high: nil)

        try await store.save(original)
        let loaded = try await store.results(profileID: profileID, analyteID: .egfr)

        #expect(loaded == [original])
        #expect(loaded[0].referenceRange.high == nil)
    }

    @Test("Filters by profile and analyte, sorted oldest collection first")
    func filtersAndSorts() async throws {
        let profileID = UUID()
        let otherProfile = UUID()
        let store = try VaultStore(directory: temporaryVaultDirectory())
        let newer = makeResult(profileID: profileID, value: "4.6", collectedAt: Date(timeIntervalSince1970: 1_779_262_800))
        let older = makeResult(profileID: profileID, value: "4.2", collectedAt: Date(timeIntervalSince1970: 1_775_981_700))
        try await store.save([newer, older])
        try await store.save(makeResult(profileID: profileID, analyteID: .glucose, value: "94", unit: .mgPerDL))
        try await store.save(makeResult(profileID: otherProfile))

        let potassium = try await store.results(profileID: profileID, analyteID: .potassium)

        #expect(try potassium.map(\.value) == [#require(Decimal(string: "4.2")), #require(Decimal(string: "4.6"))])
        #expect(try await store.results(profileID: profileID).count == 3)
        #expect(try await store.results(profileID: otherProfile).count == 1)
    }

    @Test("Data persists across store reopen")
    func persistsAcrossReopen() async throws {
        let directory = temporaryVaultDirectory()
        let profileID = UUID()
        let original = makeResult(profileID: profileID)
        do {
            let store = try VaultStore(directory: directory)
            try await store.save(original)
        }

        let reopened = try VaultStore(directory: directory)
        let loaded = try await reopened.results(profileID: profileID)

        #expect(loaded == [original])
    }

    @Test("An unusable vault path is a typed error, not a crash")
    func unusableDirectoryFails() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: blocker)
        let nested = blocker.appendingPathComponent("vault", isDirectory: true)

        #expect(throws: VaultError.self) {
            _ = try VaultStore(directory: nested)
        }
    }
}
