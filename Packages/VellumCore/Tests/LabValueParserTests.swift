import Foundation
import Testing
@testable import VellumCore

@Suite("Lab value parsing")
struct LabValueParserTests {
    @Test("Parses integers and decimals", arguments: [("110", "110"), ("4.2", "4.2"), (" 0.92 ", "0.92")])
    func parsesNumbers(raw: String, expected: String) throws {
        #expect(try LabValueParser.parseDecimal(raw) == .success(#require(Decimal(string: expected))))
    }

    @Test("Rejects non-numeric text as a typed failure", arguments: ["", "abc", "4,2", "-5", "1.2.3", "5.5 H"])
    func rejectsNonNumbers(raw: String) {
        #expect(LabValueParser.parseDecimal(raw) == .failure(.notANumber(raw)))
    }

    @Test("Display rounding is plain and place-exact")
    func displayRounding() {
        #expect(Decimal(string: "4.25")?.rounded(toPlaces: 1) == Decimal(string: "4.3")!)
        #expect(Decimal(string: "4.24")?.rounded(toPlaces: 1) == Decimal(string: "4.2")!)
        #expect(Decimal(string: "92")?.rounded(toPlaces: 0) == Decimal(92))
    }
}

@Suite("Deterministic date rendering")
struct VellumDateFormatTests {
    @Test("Renders UTC dates with pinned locale")
    func mediumUTC() {
        // 2026-04-12 08:15:00 UTC
        let date = Date(timeIntervalSince1970: 1_775_981_700)
        #expect(VellumDateFormat.mediumUTC(date) == "Apr 12, 2026")
    }
}
