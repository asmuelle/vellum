import Foundation
import Testing
import VellumTestSupport

/// PRODUCT INVARIANT #1: no page ever leaves the device. No networking
/// code in any production module — the allowlist is empty.
@Suite("No-egress invariant (PRODUCT INVARIANT #1)")
struct NoEgressInvariantTests {
    static let forbiddenFragments = [
        "URLSession",
        "import Network",
        "NWConnection",
        "CFNetwork",
        "Alamofire",
        "import FoundationNetworking",
    ]

    @Test("Production sources contain no networking primitives")
    func noNetworkingInProductionSources() throws {
        let files = try SourceScanner.productionSwiftFiles()
        #expect(!files.isEmpty, "source scan found no production files — scanner misconfigured")
        for file in files {
            for fragment in Self.forbiddenFragments {
                #expect(
                    !file.contents.contains(fragment),
                    "\(file.relativePath) contains forbidden networking fragment '\(fragment)'"
                )
            }
        }
    }
}
