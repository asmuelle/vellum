import Foundation
import VellumCore

/// Header-keyword format detection. Deliberately conservative: anything
/// not positively identified is `.unknown` and falls through to the
/// (gated, tagged) LLM fallback or manual entry — never a guess.
public enum FormatDetector {
    public static func detect(_ page: OCRPage) -> LabFormat {
        let headerText = page.lines.prefix(8).map { $0.text.uppercased() }.joined(separator: "\n")
        if headerText.contains("QUEST DIAGNOSTICS") {
            return .quest
        }
        if headerText.contains("LABCORP") {
            return .labcorp
        }
        if headerText.contains("EPIC") || headerText.contains("MYCHART") {
            return .epic
        }
        return .unknown
    }
}
