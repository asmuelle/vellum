import Foundation
import VellumCore

/// The deterministic front door (PRODUCT INVARIANT #2): every page runs
/// through the registry first. The registry claims a page only when a
/// parser recognizes the format AND parses enough of its candidate rows;
/// otherwise it reports a typed miss and the caller may consult the
/// (separately gated) LLM fallback.
public struct ParserRegistry: DeterministicExtracting {
    public static let defaultCoverageThreshold = 0.8

    public let parsers: [any LabReportParser]
    public let coverageThreshold: Double

    public init(
        parsers: [any LabReportParser] = [QuestLabReportParser(), LabcorpLabReportParser()],
        coverageThreshold: Double = ParserRegistry.defaultCoverageThreshold
    ) {
        self.parsers = parsers
        self.coverageThreshold = coverageThreshold
    }

    public func extract(from page: OCRPage, documentID: UUID) -> DeterministicOutcome {
        guard let parser = parsers.first(where: { $0.claims(page) }) else {
            return .miss(.unknownFormat)
        }
        let report = parser.parse(page, documentID: documentID)
        guard report.coverage >= coverageThreshold, !report.values.isEmpty else {
            return .miss(.coverageBelowThreshold(coverage: report.coverage, threshold: coverageThreshold))
        }
        return .claimed(format: report.format, values: report.values, coverage: report.coverage)
    }
}
