import Foundation

public enum UnitConversionError: Error, Equatable, Sendable {
    case unsupportedConversion(analyte: AnalyteID, from: LabUnit, to: LabUnit)
}

/// PRODUCT INVARIANT #4: unit normalization lives here, in code, never in a model.
/// The table is static, analyte-scoped, and direction-aware: a forward entry
/// (factor, offset) also serves the reverse direction via exact inverse math.
public struct UnitConversionTable: Sendable {
    public struct Entry: Sendable, Hashable {
        public let analyte: AnalyteID
        public let from: LabUnit
        public let to: LabUnit
        public let factor: Decimal
        public let offset: Decimal

        public init(analyte: AnalyteID, from: LabUnit, to: LabUnit, factor: Decimal, offset: Decimal = 0) {
            self.analyte = analyte
            self.from = from
            self.to = to
            self.factor = factor
            self.offset = offset
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    /// Convert a value between units for a given analyte.
    /// Identity conversions always succeed; anything else must have a
    /// table entry (forward or reverse). Misses are values, not crashes.
    public func convert(
        _ value: Decimal,
        of analyte: AnalyteID,
        from sourceUnit: LabUnit,
        to targetUnit: LabUnit
    ) -> Result<Decimal, UnitConversionError> {
        if sourceUnit == targetUnit {
            return .success(value)
        }
        if let forward = entry(analyte: analyte, from: sourceUnit, to: targetUnit) {
            return .success(value * forward.factor + forward.offset)
        }
        if let reverse = entry(analyte: analyte, from: targetUnit, to: sourceUnit) {
            return .success((value - reverse.offset) / reverse.factor)
        }
        return .failure(.unsupportedConversion(analyte: analyte, from: sourceUnit, to: targetUnit))
    }

    public func supportsConversion(of analyte: AnalyteID, from sourceUnit: LabUnit, to targetUnit: LabUnit) -> Bool {
        if sourceUnit == targetUnit { return true }
        return entry(analyte: analyte, from: sourceUnit, to: targetUnit) != nil
            || entry(analyte: analyte, from: targetUnit, to: sourceUnit) != nil
    }

    private func entry(analyte: AnalyteID, from: LabUnit, to: LabUnit) -> Entry? {
        entries.first { $0.analyte == analyte && $0.from == from && $0.to == to }
    }
}

public extension UnitConversionTable {
    /// Bundled static conversions for the M1 catalog.
    /// Factors per common clinical conversion references (UCUM-derived);
    /// monovalent electrolytes: 1 mEq/L == 1 mmol/L exactly.
    static let standard = UnitConversionTable(entries: [
        Entry(analyte: .glucose, from: .mgPerDL, to: .mmolPerL, factor: Decimal(string: "0.0555")!),
        Entry(analyte: .bun, from: .mgPerDL, to: .mmolPerL, factor: Decimal(string: "0.357")!),
        Entry(analyte: .creatinine, from: .mgPerDL, to: .umolPerL, factor: Decimal(string: "88.42")!),
        Entry(analyte: .calcium, from: .mgPerDL, to: .mmolPerL, factor: Decimal(string: "0.2495")!),
        Entry(analyte: .bilirubinTotal, from: .mgPerDL, to: .umolPerL, factor: Decimal(string: "17.104")!),
        Entry(analyte: .totalProtein, from: .gPerDL, to: .gPerL, factor: 10),
        Entry(analyte: .albumin, from: .gPerDL, to: .gPerL, factor: 10),
        Entry(analyte: .hemoglobin, from: .gPerDL, to: .gPerL, factor: 10),
        Entry(analyte: .sodium, from: .mEqPerL, to: .mmolPerL, factor: 1),
        Entry(analyte: .potassium, from: .mEqPerL, to: .mmolPerL, factor: 1),
        Entry(analyte: .chloride, from: .mEqPerL, to: .mmolPerL, factor: 1),
        Entry(analyte: .co2, from: .mEqPerL, to: .mmolPerL, factor: 1),
        Entry(analyte: .alp, from: .internationalUnitsPerL, to: .unitsPerL, factor: 1),
        Entry(analyte: .ast, from: .internationalUnitsPerL, to: .unitsPerL, factor: 1),
        Entry(analyte: .alt, from: .internationalUnitsPerL, to: .unitsPerL, factor: 1),
    ])
}
