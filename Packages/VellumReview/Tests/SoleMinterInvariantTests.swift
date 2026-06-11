import Foundation
import Testing
import VellumTestSupport

/// PRODUCT INVARIANT #3, source-level enforcement: only `VellumReview`
/// mints `ReviewReceipt`s (and therefore `LabResult`s), and only
/// `VellumVault` rehydrates already-minted rows.
@Suite("Sole-minter invariant (PRODUCT INVARIANT #3)")
struct SoleMinterInvariantTests {
    @Test("ReviewReceipt is constructed only inside VellumReview")
    func receiptConstructionConfinedToReview() throws {
        let files = try SourceScanner.productionSwiftFiles()
        #expect(!files.isEmpty)
        for file in files where !file.relativePath.hasPrefix("Packages/VellumReview/Sources/") {
            let isDeclarationFile = file.relativePath == "Packages/VellumCore/Sources/LabResult.swift"
            if isDeclarationFile { continue }
            #expect(
                !file.contents.contains("ReviewReceipt("),
                "\(file.relativePath) constructs a ReviewReceipt outside VellumReview"
            )
        }
    }

    @Test("LabResult rehydration is confined to VellumVault")
    func rehydrationConfinedToVault() throws {
        let files = try SourceScanner.productionSwiftFiles()
        for file in files where !file.relativePath.hasPrefix("Packages/VellumVault/Sources/") {
            let isDeclarationFile = file.relativePath == "Packages/VellumCore/Sources/LabResult.swift"
            if isDeclarationFile { continue }
            #expect(
                !file.contents.contains("rehydratingID"),
                "\(file.relativePath) uses the vault-only rehydration initializer"
            )
        }
    }

    @Test("Downstream surfaces never import ExtractedValue producers")
    func downstreamSurfacesTakeLabResultOnly() throws {
        // Trends/Ask/Explain may depend on Core+Vault only — never on
        // Parsing, Extraction or Review (they must be unable to see
        // unconfirmed proposals at the module-graph level).
        let files = try SourceScanner.swiftFiles(under: [
            RepoPaths.packagesDirectory.appendingPathComponent("VellumTrends/Sources"),
            RepoPaths.packagesDirectory.appendingPathComponent("VellumAsk/Sources"),
            RepoPaths.packagesDirectory.appendingPathComponent("VellumExplain/Sources"),
        ])
        #expect(!files.isEmpty)
        for file in files {
            for forbidden in ["import VellumParsing", "import VellumExtraction", "import VellumReview", "ExtractedValue"] {
                #expect(
                    !file.contents.contains(forbidden),
                    "\(file.relativePath) reaches upstream of the confirmation gate ('\(forbidden)')"
                )
            }
        }
    }
}
