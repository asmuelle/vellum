import Foundation

public enum ValueParseError: Error, Equatable, Sendable {
    case notANumber(String)
}

/// Strict numeric parsing for lab values. Locale-independent:
/// lab paper in scope uses "." as the decimal separator.
public enum LabValueParser {
    public static func parseDecimal(_ raw: String) -> Result<Decimal, ValueParseError> {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard text.wholeMatch(of: /\d+(?:\.\d+)?/) != nil, let value = Decimal(string: text) else {
            return .failure(.notANumber(raw))
        }
        return .success(value)
    }
}

public extension Decimal {
    /// Round to a fixed number of fraction digits (plain/bankers-free rounding).
    /// Display-only helper; stored values keep full precision.
    func rounded(toPlaces places: Int) -> Decimal {
        var input = self
        var output = Decimal()
        NSDecimalRound(&output, &input, places, .plain)
        return output
    }
}
