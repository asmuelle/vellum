import Foundation
import VellumCore

/// Deterministic parser for Labcorp printouts.
///
/// Labcorp column order differs from Quest: NAME  VALUE  [High|Low]
/// UNITS  REFERENCE-INTERVAL, separated by runs of 2+ spaces.
public struct LabcorpLabReportParser: LabReportParser {
    public let format = LabFormat.labcorp

    private nonisolated(unsafe) static let row =
        /^(?<name>[A-Za-z][A-Za-z0-9 ,().\/-]*?)\s{2,}(?<value>\d+(?:\.\d+)?)(?:\s{2,}(?<flag>High|Low))?\s{2,}(?<unit>\S+)\s{2,}(?<range>(?:\d+(?:\.\d+)?-\d+(?:\.\d+)?|[<>]\d+(?:\.\d+)?))\s*$/

    public init() {}

    public func claims(_ page: OCRPage) -> Bool {
        FormatDetector.detect(page) == .labcorp
    }

    public func parse(_ page: OCRPage, documentID: UUID) -> ParsedReport {
        let collectedAtRaw = CollectedDateScanner.collectedAtRaw(in: page)
        var values: [ExtractedValue] = []
        var candidateRows = 0
        for line in page.lines {
            let text = line.text.trimmingCharacters(in: CharacterSet(charactersIn: " "))
            if ResultRowHeuristics.isCandidateResultRow(text) {
                candidateRows += 1
            }
            guard let match = text.wholeMatch(of: Self.row) else { continue }
            values.append(ExtractedValue(
                documentID: documentID,
                pageID: page.id,
                boundingBox: line.boundingBox,
                analyteRaw: String(match.name).trimmingCharacters(in: .whitespaces),
                valueRaw: String(match.value),
                unitRaw: String(match.unit),
                refRangeRaw: String(match.output.range),
                flagRaw: match.flag.map(String.init),
                collectedAtRaw: collectedAtRaw,
                extractionMethod: .deterministic,
                confidence: line.confidence
            ))
        }
        return ParsedReport(
            format: format,
            values: values,
            coverage: ResultRowHeuristics.coverage(parsedRows: values.count, candidateRows: candidateRows),
            collectedAtRaw: collectedAtRaw
        )
    }
}
