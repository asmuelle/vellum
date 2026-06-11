import Foundation

public enum RangeParseError: Error, Equatable, Sendable {
    case unrecognizedFormat(String)
}

public enum RangeStatus: String, Sendable, Codable, Equatable {
    case belowRange
    case inRange
    case aboveRange
}

/// The reference range as printed on the user's own document.
/// Vellum never substitutes its own ranges: out-of-range classification
/// always uses the bounds from the page the value came from (DESIGN.md,
/// risk #5 mitigation).
public struct ReferenceRange: Sendable, Codable, Hashable {
    /// Inclusive lower bound; nil for "< x" style ranges.
    public let low: Decimal?
    /// Inclusive upper bound; nil for "> x" style ranges.
    public let high: Decimal?
    /// The raw text exactly as printed, for provenance display.
    public let rawText: String

    public init(low: Decimal?, high: Decimal?, rawText: String) {
        self.low = low
        self.high = high
        self.rawText = rawText
    }

    /// Parse "65-99", ">59" or "<150". Bounds are treated as inclusive.
    public static func parse(_ raw: String) -> Result<ReferenceRange, RangeParseError> {
        let text = raw.trimmingCharacters(in: .whitespaces)
        if let match = text.wholeMatch(of: /(?<low>\d+(?:\.\d+)?)\s*-\s*(?<high>\d+(?:\.\d+)?)/) {
            guard let low = Decimal(string: String(match.low)), let high = Decimal(string: String(match.high)) else {
                return .failure(.unrecognizedFormat(raw))
            }
            return .success(ReferenceRange(low: low, high: high, rawText: text))
        }
        if let match = text.wholeMatch(of: />\s*(?<low>\d+(?:\.\d+)?)/) {
            guard let low = Decimal(string: String(match.low)) else { return .failure(.unrecognizedFormat(raw)) }
            return .success(ReferenceRange(low: low, high: nil, rawText: text))
        }
        if let match = text.wholeMatch(of: /<\s*(?<high>\d+(?:\.\d+)?)/) {
            guard let high = Decimal(string: String(match.high)) else { return .failure(.unrecognizedFormat(raw)) }
            return .success(ReferenceRange(low: nil, high: high, rawText: text))
        }
        return .failure(.unrecognizedFormat(raw))
    }

    public func classify(_ value: Decimal) -> RangeStatus {
        if let low, value < low { return .belowRange }
        if let high, value > high { return .aboveRange }
        return .inRange
    }

    /// Convert both bounds with the same table used for the value itself
    /// (invariant #4: normalization in code, applied consistently).
    public func converted(
        of analyte: AnalyteID,
        from sourceUnit: LabUnit,
        to targetUnit: LabUnit,
        using table: UnitConversionTable
    ) -> Result<ReferenceRange, UnitConversionError> {
        var newLow: Decimal?
        var newHigh: Decimal?
        if let low {
            switch table.convert(low, of: analyte, from: sourceUnit, to: targetUnit) {
            case let .success(converted): newLow = converted
            case let .failure(error): return .failure(error)
            }
        }
        if let high {
            switch table.convert(high, of: analyte, from: sourceUnit, to: targetUnit) {
            case let .success(converted): newHigh = converted
            case let .failure(error): return .failure(error)
            }
        }
        return .success(ReferenceRange(low: newLow, high: newHigh, rawText: rawText))
    }
}
