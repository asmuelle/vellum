import Foundation

/// One entry of the bundled static analyte catalog.
///
/// Catalog source: analyte names and canonical units derived from
/// LOINC 2.78 / UCUM common lab usage (vendored knowledge, no runtime
/// fetch — see TOOLS.md "External Data Sources").
public struct Analyte: Sendable, Hashable, Identifiable {
    public let id: AnalyteID
    public let canonicalName: String
    /// Printed names seen on lab paper, matched case-insensitively
    /// after whitespace normalization.
    public let aliases: [String]
    public let canonicalUnit: LabUnit
    /// Digits after the decimal point for display purposes only.
    /// Stored values keep full precision.
    public let displayPrecision: Int

    public init(id: AnalyteID, canonicalName: String, aliases: [String], canonicalUnit: LabUnit, displayPrecision: Int) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.canonicalUnit = canonicalUnit
        self.displayPrecision = displayPrecision
    }
}

/// Lookup over the bundled analyte catalog. Pure value type; no I/O.
public struct AnalyteCatalog: Sendable {
    public let analytes: [Analyte]
    private let byNormalizedAlias: [String: AnalyteID]
    private let byID: [AnalyteID: Analyte]

    public init(analytes: [Analyte]) {
        self.analytes = analytes
        var aliasMap: [String: AnalyteID] = [:]
        var idMap: [AnalyteID: Analyte] = [:]
        for analyte in analytes {
            idMap[analyte.id] = analyte
            for alias in analyte.aliases + [analyte.canonicalName] {
                aliasMap[Self.normalize(alias)] = analyte.id
            }
        }
        byNormalizedAlias = aliasMap
        byID = idMap
    }

    public func analyte(withID id: AnalyteID) -> Analyte? {
        byID[id]
    }

    /// Resolve a printed analyte name ("UREA NITROGEN (BUN)", "Potassium")
    /// to a catalog entry. Returns nil for unknown names — callers must
    /// treat that as a value, not an exception (see AGENTS.md).
    public func analyte(matchingRawName rawName: String) -> Analyte? {
        byNormalizedAlias[Self.normalize(rawName)].flatMap { byID[$0] }
    }

    static func normalize(_ name: String) -> String {
        name.uppercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
