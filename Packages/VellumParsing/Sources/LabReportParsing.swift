import Foundation
import VellumCore

/// A parsed page: proposals plus how much of the page's candidate result
/// rows the parser actually understood.
public struct ParsedReport: Sendable, Equatable {
    public let format: LabFormat
    public let values: [ExtractedValue]
    /// parsed candidate rows / total candidate rows, 0...1.
    public let coverage: Double
    public let collectedAtRaw: String?

    public init(format: LabFormat, values: [ExtractedValue], coverage: Double, collectedAtRaw: String?) {
        self.format = format
        self.values = values
        self.coverage = coverage
        self.collectedAtRaw = collectedAtRaw
    }
}

/// One deterministic parser for one lab-paper format. Parsers are pure:
/// OCR page in, proposals out; misses are values, not exceptions.
public protocol LabReportParser: Sendable {
    var format: LabFormat { get }
    /// Cheap format check (header keywords) before full parsing.
    func claims(_ page: OCRPage) -> Bool
    func parse(_ page: OCRPage, documentID: UUID) -> ParsedReport
}

/// Shared row heuristics. A "candidate" line is anything that looks like
/// a result row (two-plus numeric tokens including a reference-range
/// token); coverage = parsed candidates / all candidates, which lets a
/// garbled page fall below the registry threshold instead of silently
/// losing rows.
public enum ResultRowHeuristics {
    private nonisolated(unsafe) static let rangeToken = /(?:\d+(?:\.\d+)?\s*-\s*\d+(?:\.\d+)?|[<>]\s*\d+(?:\.\d+)?)/
    private nonisolated(unsafe) static let numberToken = /\d+(?:\.\d+)?/

    public static func isCandidateResultRow(_ text: String) -> Bool {
        guard text.first?.isLetter == true else { return false }
        guard text.firstMatch(of: rangeToken) != nil else { return false }
        let numberCount = text.matches(of: numberToken).count
        return numberCount >= 2
    }

    public static func coverage(parsedRows: Int, candidateRows: Int) -> Double {
        guard candidateRows > 0 else { return 0 }
        return Double(parsedRows) / Double(candidateRows)
    }
}

/// Finds the collection date line. Quest prints "COLLECTED: …",
/// Labcorp prints "Date Collected: …". The raw substring is stamped
/// onto every extracted value; date *parsing* happens at review time.
public enum CollectedDateScanner {
    public static func collectedAtRaw(in page: OCRPage) -> String? {
        for line in page.lines {
            let upper = line.text.uppercased().trimmingCharacters(in: .whitespaces)
            if upper.hasPrefix("DATE COLLECTED:") {
                return rawValue(of: line.text, afterPrefixLength: "DATE COLLECTED:".count)
            }
            if upper.hasPrefix("COLLECTED:") {
                return rawValue(of: line.text, afterPrefixLength: "COLLECTED:".count)
            }
        }
        return nil
    }

    private static func rawValue(of text: String, afterPrefixLength length: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let value = String(trimmed.dropFirst(length)).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
