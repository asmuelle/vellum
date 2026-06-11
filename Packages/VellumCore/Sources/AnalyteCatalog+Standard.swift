import Foundation

public extension AnalyteCatalog {
    /// The bundled M1 catalog: CMP-14 + CBC core panel.
    /// Names/aliases cover Quest and Labcorp printed forms used in Fixtures/.
    static let standard = AnalyteCatalog(analytes: [
        Analyte(
            id: .glucose, canonicalName: "Glucose",
            aliases: ["GLUCOSE"], canonicalUnit: .mgPerDL, displayPrecision: 0
        ),
        Analyte(
            id: .bun, canonicalName: "Urea Nitrogen (BUN)",
            aliases: ["UREA NITROGEN (BUN)", "BUN"], canonicalUnit: .mgPerDL, displayPrecision: 0
        ),
        Analyte(
            id: .creatinine, canonicalName: "Creatinine",
            aliases: ["CREATININE"], canonicalUnit: .mgPerDL, displayPrecision: 2
        ),
        Analyte(
            id: .egfr, canonicalName: "eGFR",
            aliases: ["EGFR"], canonicalUnit: .mlPerMinPer173, displayPrecision: 0
        ),
        Analyte(
            id: .sodium, canonicalName: "Sodium",
            aliases: ["SODIUM"], canonicalUnit: .mmolPerL, displayPrecision: 0
        ),
        Analyte(
            id: .potassium, canonicalName: "Potassium",
            aliases: ["POTASSIUM"], canonicalUnit: .mmolPerL, displayPrecision: 1
        ),
        Analyte(
            id: .chloride, canonicalName: "Chloride",
            aliases: ["CHLORIDE"], canonicalUnit: .mmolPerL, displayPrecision: 0
        ),
        Analyte(
            id: .co2, canonicalName: "Carbon Dioxide",
            aliases: ["CARBON DIOXIDE", "CARBON DIOXIDE, TOTAL", "CO2"], canonicalUnit: .mmolPerL, displayPrecision: 0
        ),
        Analyte(
            id: .calcium, canonicalName: "Calcium",
            aliases: ["CALCIUM"], canonicalUnit: .mgPerDL, displayPrecision: 1
        ),
        Analyte(
            id: .totalProtein, canonicalName: "Protein, Total",
            aliases: ["PROTEIN, TOTAL", "TOTAL PROTEIN"], canonicalUnit: .gPerDL, displayPrecision: 1
        ),
        Analyte(
            id: .albumin, canonicalName: "Albumin",
            aliases: ["ALBUMIN"], canonicalUnit: .gPerDL, displayPrecision: 1
        ),
        Analyte(
            id: .bilirubinTotal, canonicalName: "Bilirubin, Total",
            aliases: ["BILIRUBIN, TOTAL", "TOTAL BILIRUBIN"], canonicalUnit: .mgPerDL, displayPrecision: 1
        ),
        Analyte(
            id: .alp, canonicalName: "Alkaline Phosphatase",
            aliases: ["ALKALINE PHOSPHATASE", "ALK PHOS"], canonicalUnit: .unitsPerL, displayPrecision: 0
        ),
        Analyte(
            id: .ast, canonicalName: "AST",
            aliases: ["AST", "AST (SGOT)"], canonicalUnit: .unitsPerL, displayPrecision: 0
        ),
        Analyte(
            id: .alt, canonicalName: "ALT",
            aliases: ["ALT", "ALT (SGPT)"], canonicalUnit: .unitsPerL, displayPrecision: 0
        ),
        Analyte(
            id: .wbc, canonicalName: "WBC",
            aliases: ["WBC", "WHITE BLOOD CELL COUNT"], canonicalUnit: .thousandPerUL, displayPrecision: 1
        ),
        Analyte(
            id: .rbc, canonicalName: "RBC",
            aliases: ["RBC", "RED BLOOD CELL COUNT"], canonicalUnit: .millionPerUL, displayPrecision: 2
        ),
        Analyte(
            id: .hemoglobin, canonicalName: "Hemoglobin",
            aliases: ["HEMOGLOBIN", "HGB"], canonicalUnit: .gPerDL, displayPrecision: 1
        ),
        Analyte(
            id: .hematocrit, canonicalName: "Hematocrit",
            aliases: ["HEMATOCRIT", "HCT"], canonicalUnit: .percent, displayPrecision: 1
        ),
        Analyte(
            id: .mcv, canonicalName: "MCV",
            aliases: ["MCV"], canonicalUnit: .femtoliter, displayPrecision: 1
        ),
        Analyte(
            id: .plateletCount, canonicalName: "Platelet Count",
            aliases: ["PLATELET COUNT", "PLATELETS"], canonicalUnit: .thousandPerUL, displayPrecision: 0
        ),
    ])
}
