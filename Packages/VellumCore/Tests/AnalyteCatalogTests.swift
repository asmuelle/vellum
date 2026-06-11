import Foundation
import Testing
@testable import VellumCore

@Suite("Analyte catalog")
struct AnalyteCatalogTests {
    let catalog = AnalyteCatalog.standard

    @Test("Resolves printed names case-insensitively with whitespace normalization")
    func aliasResolution() {
        #expect(catalog.analyte(matchingRawName: "POTASSIUM")?.id == .potassium)
        #expect(catalog.analyte(matchingRawName: "potassium")?.id == .potassium)
        #expect(catalog.analyte(matchingRawName: "  UREA   NITROGEN (BUN) ")?.id == .bun)
        #expect(catalog.analyte(matchingRawName: "Carbon Dioxide, Total")?.id == .co2)
    }

    @Test("Unknown printed names are a nil value, not an exception")
    func unknownName() {
        #expect(catalog.analyte(matchingRawName: "TRIGLYCERIDES") == nil)
    }

    @Test("Every AnalyteID case has a catalog entry")
    func catalogIsComplete() {
        for id in AnalyteID.allCases {
            #expect(catalog.analyte(withID: id) != nil, "missing catalog entry for \(id)")
        }
    }

    @Test("Canonical names resolve to their own entries")
    func canonicalNamesResolve() {
        for analyte in catalog.analytes {
            #expect(catalog.analyte(matchingRawName: analyte.canonicalName)?.id == analyte.id)
        }
    }
}
