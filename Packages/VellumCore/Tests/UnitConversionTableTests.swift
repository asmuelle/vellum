import Foundation
import Testing
@testable import VellumCore

@Suite("Unit conversion table (PRODUCT INVARIANT #4)")
struct UnitConversionTableTests {
    let table = UnitConversionTable.standard

    @Test("Identity conversion always succeeds and is exact")
    func identityConversion() throws {
        let result = try table.convert(#require(Decimal(string: "4.2")), of: .potassium, from: .mmolPerL, to: .mmolPerL)
        #expect(try result == .success(#require(Decimal(string: "4.2"))))
    }

    @Test("Glucose mg/dL → mmol/L uses the exact table factor")
    func glucoseForward() throws {
        let result = table.convert(100, of: .glucose, from: .mgPerDL, to: .mmolPerL)
        #expect(try result == .success(#require(Decimal(string: "5.55"))))
    }

    @Test("Creatinine mg/dL → umol/L uses the exact table factor")
    func creatinineForward() throws {
        let result = table.convert(1, of: .creatinine, from: .mgPerDL, to: .umolPerL)
        #expect(try result == .success(#require(Decimal(string: "88.42"))))
    }

    @Test("Monovalent electrolytes: 1 mEq/L == 1 mmol/L exactly", arguments: [AnalyteID.sodium, .potassium, .chloride, .co2])
    func electrolyteEquivalence(analyte: AnalyteID) throws {
        let result = try table.convert(#require(Decimal(string: "4.4")), of: analyte, from: .mEqPerL, to: .mmolPerL)
        #expect(try result == .success(#require(Decimal(string: "4.4"))))
    }

    @Test("Every table entry round-trips exactly — no tolerance fudging")
    func everyEntryRoundTrips() throws {
        let sample = try #require(Decimal(string: "7.3"))
        for entry in table.entries {
            let forward = try table.convert(sample, of: entry.analyte, from: entry.from, to: entry.to).get()
            let back = try table.convert(forward, of: entry.analyte, from: entry.to, to: entry.from).get()
            #expect(back == sample, "round-trip failed for \(entry.analyte) \(entry.from) → \(entry.to)")
        }
    }

    @Test("Reverse direction is derived from the forward entry")
    func reverseDirection() throws {
        let result = try table.convert(#require(Decimal(string: "5.55")), of: .glucose, from: .mmolPerL, to: .mgPerDL)
        #expect(result == .success(100))
    }

    @Test("Unsupported conversion is a typed miss, not a crash")
    func unsupportedConversion() {
        let result = table.convert(1, of: .glucose, from: .mgPerDL, to: .percent)
        #expect(result == .failure(.unsupportedConversion(analyte: .glucose, from: .mgPerDL, to: .percent)))
    }

    @Test("supportsConversion covers identity, forward and reverse")
    func supportsConversion() {
        #expect(table.supportsConversion(of: .glucose, from: .mgPerDL, to: .mgPerDL))
        #expect(table.supportsConversion(of: .glucose, from: .mgPerDL, to: .mmolPerL))
        #expect(table.supportsConversion(of: .glucose, from: .mmolPerL, to: .mgPerDL))
        #expect(!table.supportsConversion(of: .glucose, from: .mgPerDL, to: .percent))
    }

    @Test("Every M1 catalog canonical unit is reachable from itself (identity floor)")
    func catalogCanonicalUnitsConvertible() {
        for analyte in AnalyteCatalog.standard.analytes {
            #expect(table.supportsConversion(of: analyte.id, from: analyte.canonicalUnit, to: analyte.canonicalUnit))
        }
    }
}
