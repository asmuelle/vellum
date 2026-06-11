import Foundation

/// A unit symbol exactly as it appears on lab paper (or as a canonical unit).
/// Comparison is exact and case-sensitive: "mg/dL" and "mEq/L" are distinct,
/// and any equivalence (e.g. mEq/L == mmol/L for monovalent ions) must be an
/// explicit entry in the static conversion table — never an implicit alias.
public struct LabUnit: Sendable, Codable, Hashable, CustomStringConvertible {
    public let symbol: String

    public init(_ symbol: String) {
        self.symbol = symbol
    }

    public var description: String {
        symbol
    }
}

public extension LabUnit {
    static let mgPerDL = LabUnit("mg/dL")
    static let mmolPerL = LabUnit("mmol/L")
    static let mEqPerL = LabUnit("mEq/L")
    static let gPerDL = LabUnit("g/dL")
    static let gPerL = LabUnit("g/L")
    static let umolPerL = LabUnit("umol/L")
    static let unitsPerL = LabUnit("U/L")
    static let internationalUnitsPerL = LabUnit("IU/L")
    static let thousandPerUL = LabUnit("Thousand/uL")
    static let millionPerUL = LabUnit("Million/uL")
    static let percent = LabUnit("%")
    static let femtoliter = LabUnit("fL")
    static let mlPerMinPer173 = LabUnit("mL/min/1.73")
}
