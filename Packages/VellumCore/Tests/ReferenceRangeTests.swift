import Foundation
import Testing
@testable import VellumCore

@Suite("Reference range parsing and classification")
struct ReferenceRangeTests {
    @Test("Parses a bounded range")
    func boundedRange() throws {
        let range = try ReferenceRange.parse("65-99").get()
        #expect(range.low == 65)
        #expect(range.high == 99)
        #expect(range.rawText == "65-99")
    }

    @Test("Parses '>' lower-bound-only ranges")
    func lowerBoundOnly() throws {
        let range = try ReferenceRange.parse(">59").get()
        #expect(range.low == 59)
        #expect(range.high == nil)
    }

    @Test("Parses '<' upper-bound-only ranges")
    func upperBoundOnly() throws {
        let range = try ReferenceRange.parse("<150").get()
        #expect(range.low == nil)
        #expect(range.high == 150)
    }

    @Test("Decimal bounds parse exactly")
    func decimalBounds() throws {
        let range = try ReferenceRange.parse("0.60-1.35").get()
        #expect(range.low == Decimal(string: "0.60")!)
        #expect(range.high == Decimal(string: "1.35")!)
    }

    @Test("Malformed ranges are typed failures", arguments: ["", "banana", "3.5 to 5.1", "--", "65 -"])
    func malformedRanges(raw: String) {
        #expect(ReferenceRange.parse(raw) == .failure(.unrecognizedFormat(raw)))
    }

    @Test("Classification treats bounds as inclusive")
    func inclusiveBounds() throws {
        let range = try ReferenceRange.parse("3.5-5.3").get()
        #expect(try range.classify(#require(Decimal(string: "3.5"))) == .inRange)
        #expect(try range.classify(#require(Decimal(string: "5.3"))) == .inRange)
        #expect(try range.classify(#require(Decimal(string: "3.4"))) == .belowRange)
        #expect(try range.classify(#require(Decimal(string: "5.4"))) == .aboveRange)
    }

    @Test("Open-ended ranges classify on the single bound")
    func openEndedClassification() throws {
        let range = try ReferenceRange.parse(">59").get()
        #expect(range.classify(60) == .inRange)
        #expect(range.classify(59) == .inRange)
        #expect(range.classify(58) == .belowRange)
    }

    @Test("Range conversion uses the same table as the value (invariant #4)")
    func rangeConversion() throws {
        let printed = try ReferenceRange.parse("65-99").get()
        let converted = try printed.converted(of: .glucose, from: .mgPerDL, to: .mmolPerL, using: .standard).get()
        #expect(converted.low == Decimal(string: "3.6075")!)
        #expect(converted.high == Decimal(string: "5.4945")!)
        #expect(converted.rawText == "65-99", "raw printed text is preserved for provenance display")
    }

    @Test("Range conversion fails as a value when the table has no entry")
    func rangeConversionMiss() throws {
        let printed = try ReferenceRange.parse("65-99").get()
        let result = printed.converted(of: .glucose, from: .mgPerDL, to: .percent, using: .standard)
        #expect(result == .failure(.unsupportedConversion(analyte: .glucose, from: .mgPerDL, to: .percent)))
    }
}
