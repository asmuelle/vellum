import Foundation
import Testing
import VellumCapture
@testable import VellumCore
@testable import VellumParsing
import VellumTestSupport

/// The shape of `Fixtures/expected/*.json` rows — the golden spec every
/// deterministic parser change must keep byte-exact (AGENTS.md testing
/// policy #1).
struct ExpectedRow: Decodable, Equatable {
    let analyteRaw: String
    let valueRaw: String
    let unitRaw: String
    let refRangeRaw: String
    let flagRaw: String?
    let collectedAtRaw: String?
}

func extractedAsExpected(_ value: ExtractedValue) -> ExpectedRow {
    ExpectedRow(
        analyteRaw: value.analyteRaw,
        valueRaw: value.valueRaw,
        unitRaw: value.unitRaw,
        refRangeRaw: value.refRangeRaw,
        flagRaw: value.flagRaw,
        collectedAtRaw: value.collectedAtRaw
    )
}

func loadFixturePage(_ name: String) throws -> OCRPage {
    try OCRPageFactory.page(fromPlainText: FixtureLoader.text(named: name))
}

@Suite("Golden fixture parser tests")
struct GoldenFixtureParserTests {
    @Test(
        "Quest fixtures parse exact-match against the golden spec",
        arguments: ["quest_cmp_2026-04-12", "quest_bmp_2026-05-20"]
    )
    func questGolden(fixture: String) throws {
        let page = try loadFixturePage("\(fixture).txt")
        let expected = try FixtureLoader.expectedJSON([ExpectedRow].self, named: "\(fixture).json")

        let report = QuestLabReportParser().parse(page, documentID: UUID())

        #expect(report.format == .quest)
        #expect(report.coverage == 1.0, "every candidate row on the golden page must parse")
        #expect(report.values.map(extractedAsExpected) == expected)
        #expect(report.values.allSatisfy { $0.extractionMethod == .deterministic })
        #expect(report.values.allSatisfy { $0.reviewState == .pending })
        #expect(report.values.allSatisfy { $0.boundingBox.height > 0 }, "every value carries a page bounding box")
    }

    @Test("Labcorp fixture parses exact-match against the golden spec")
    func labcorpGolden() throws {
        let page = try loadFixturePage("labcorp_cbc_2026-03-02.txt")
        let expected = try FixtureLoader.expectedJSON([ExpectedRow].self, named: "labcorp_cbc_2026-03-02.json")

        let report = LabcorpLabReportParser().parse(page, documentID: UUID())

        #expect(report.format == .labcorp)
        #expect(report.coverage == 1.0)
        #expect(report.values.map(extractedAsExpected) == expected)
        #expect(report.values.allSatisfy { $0.extractionMethod == .deterministic })
    }

    @Test("Every golden value's analyte resolves in the bundled catalog")
    func goldenAnalytesResolve() throws {
        for fixture in ["quest_cmp_2026-04-12.txt", "quest_bmp_2026-05-20.txt"] {
            let report = try QuestLabReportParser().parse(loadFixturePage(fixture), documentID: UUID())
            for value in report.values {
                #expect(AnalyteCatalog.standard.analyte(matchingRawName: value.analyteRaw) != nil, "\(value.analyteRaw)")
            }
        }
        let labcorp = try LabcorpLabReportParser().parse(loadFixturePage("labcorp_cbc_2026-03-02.txt"), documentID: UUID())
        for value in labcorp.values {
            #expect(AnalyteCatalog.standard.analyte(matchingRawName: value.analyteRaw) != nil, "\(value.analyteRaw)")
        }
    }
}

@Suite("Format detection")
struct FormatDetectorTests {
    @Test("Detects Quest, Labcorp and unknown headers")
    func detection() throws {
        #expect(try FormatDetector.detect(loadFixturePage("quest_cmp_2026-04-12.txt")) == .quest)
        #expect(try FormatDetector.detect(loadFixturePage("labcorp_cbc_2026-03-02.txt")) == .labcorp)
        #expect(try FormatDetector.detect(loadFixturePage("unknown_hospital_2026-01-15.txt")) == .unknown)
    }
}

@Suite("Parser registry (deterministic front door)")
struct ParserRegistryTests {
    @Test("Claims golden fixtures with full coverage")
    func claimsGoldenFixtures() throws {
        let registry = ParserRegistry()
        let outcome = try registry.extract(from: loadFixturePage("quest_cmp_2026-04-12.txt"), documentID: UUID())
        guard case let .claimed(format, values, coverage) = outcome else {
            Issue.record("expected .claimed, got \(outcome)")
            return
        }
        #expect(format == .quest)
        #expect(values.count == 15)
        #expect(coverage == 1.0)
    }

    @Test("Unknown formats are a typed miss — never a guess")
    func unknownFormatMisses() throws {
        let registry = ParserRegistry()
        let outcome = try registry.extract(from: loadFixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())
        #expect(outcome == .miss(.unknownFormat))
    }

    @Test("Sub-threshold coverage is a typed miss with the measured coverage")
    func coverageBelowThresholdMisses() {
        // A Quest header whose result rows are too garbled for the row
        // regex (single-space columns) — candidates without parses.
        let garbled = """
        QUEST DIAGNOSTICS INCORPORATED
        COLLECTED: 04/12/2026 08:15
        GLUCOSE 110 65-99 mg/dL
        POTASSIUM 4.2 3.5-5.3 mmol/L
        """
        let page = OCRPageFactory.page(fromPlainText: garbled)
        let outcome = ParserRegistry().extract(from: page, documentID: UUID())
        #expect(outcome == .miss(.coverageBelowThreshold(coverage: 0, threshold: ParserRegistry.defaultCoverageThreshold)))
    }
}
