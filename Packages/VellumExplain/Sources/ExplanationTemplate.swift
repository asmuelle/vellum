import Foundation
import VellumCore

public struct Explanation: Sendable, Equatable {
    public let body: String
    public let footer: String
}

public enum ExplainError: Error, Equatable, Sendable {
    case analyteMismatch(expected: AnalyteID, got: AnalyteID)
    case bannedPhrase(violations: [String])
}

/// Template-grounded explanations (PRODUCT INVARIANT #6, FDA CDS
/// exemption posture): slots are filled from the confirmed record only,
/// the cited range is the one printed on the user's own document, and
/// the wording is pinned by snapshot tests. M2 lets AFM fill prose
/// around the same slots; the lint and footer never change.
public enum ExplanationTemplate {
    /// Persistent footer on every explanation (App Review 1.4.1).
    public static let footer = "Not medical advice. Talk to your clinician."

    public static func explanation(for result: LabResult, analyte: Analyte) -> Result<Explanation, ExplainError> {
        guard analyte.id == result.analyteID else {
            return .failure(.analyteMismatch(expected: analyte.id, got: result.analyteID))
        }
        let value = String(describing: result.value.rounded(toPlaces: analyte.displayPrecision))
        let date = VellumDateFormat.mediumUTC(result.collectedAt)
        let body = "\(analyte.canonicalName) was \(value) \(result.unit.symbol) on \(date). "
            + "The reference range printed on this document is \(result.referenceRange.rawText) \(result.unit.symbol). "
            + "This value sits \(positionPhrase(for: result))."
        let violations = BannedPhraseLint.violations(in: body + " " + footer)
        guard violations.isEmpty else {
            return .failure(.bannedPhrase(violations: violations))
        }
        return .success(Explanation(body: body, footer: footer))
    }

    private static func positionPhrase(for result: LabResult) -> String {
        switch result.referenceRange.classify(result.value) {
        case .inRange: "within that printed range"
        case .aboveRange: "above that printed range"
        case .belowRange: "below that printed range"
        }
    }
}
