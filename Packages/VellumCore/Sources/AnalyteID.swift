import Foundation

/// Stable identifiers for the analytes Vellum understands in M1
/// (CMP-14 + CBC core panel). The bundled catalog maps printed
/// names/aliases on lab paper to these IDs.
public enum AnalyteID: String, Sendable, Codable, CaseIterable, Hashable {
    case glucose
    case bun
    case creatinine
    case egfr
    case sodium
    case potassium
    case chloride
    case co2
    case calcium
    case totalProtein
    case albumin
    case bilirubinTotal
    case alp
    case ast
    case alt
    case wbc
    case rbc
    case hemoglobin
    case hematocrit
    case mcv
    case plateletCount
}
