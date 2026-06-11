import Foundation
import Testing
@testable import VellumCore
@testable import VellumExplain

func explainResult(analyteID: AnalyteID, value: String, unit: LabUnit, low: String?, high: String?, rawRange: String) -> LabResult {
    LabResult(
        rehydratingID: UUID(),
        profileID: UUID(),
        analyteID: analyteID,
        value: Decimal(string: value)!,
        unit: unit,
        referenceRange: ReferenceRange(
            low: low.flatMap { Decimal(string: $0) },
            high: high.flatMap { Decimal(string: $0) },
            rawText: rawRange
        ),
        collectedAt: Date(timeIntervalSince1970: 1_775_981_700), // Apr 12, 2026 UTC
        provenance: Provenance(documentID: UUID(), pageID: UUID(), boundingBox: .zero, extractionMethod: .deterministic),
        reviewReceiptID: UUID()
    )
}

@Suite("Template-grounded explanations (PRODUCT INVARIANT #6) — wording is snapshot-pinned")
struct ExplanationTemplateTests {
    let catalog = AnalyteCatalog.standard

    @Test("In-range wording is pinned exactly")
    func inRangeSnapshot() throws {
        let result = explainResult(analyteID: .potassium, value: "4.2", unit: .mmolPerL, low: "3.5", high: "5.3", rawRange: "3.5-5.3")
        let analyte = try #require(catalog.analyte(withID: .potassium))

        let explanation = try ExplanationTemplate.explanation(for: result, analyte: analyte).get()

        #expect(explanation.body == "Potassium was 4.2 mmol/L on Apr 12, 2026. "
            + "The reference range printed on this document is 3.5-5.3 mmol/L. "
            + "This value sits within that printed range.")
        #expect(explanation.footer == "Not medical advice. Talk to your clinician.")
    }

    @Test("Above-range wording is pinned exactly — compares to the printed range, never declares 'normal'")
    func aboveRangeSnapshot() throws {
        let result = explainResult(analyteID: .glucose, value: "110", unit: .mgPerDL, low: "65", high: "99", rawRange: "65-99")
        let analyte = try #require(catalog.analyte(withID: .glucose))

        let explanation = try ExplanationTemplate.explanation(for: result, analyte: analyte).get()

        #expect(explanation.body == "Glucose was 110 mg/dL on Apr 12, 2026. "
            + "The reference range printed on this document is 65-99 mg/dL. "
            + "This value sits above that printed range.")
    }

    @Test("Below-range wording uses the below phrase")
    func belowRangePhrase() throws {
        let result = explainResult(analyteID: .sodium, value: "131", unit: .mmolPerL, low: "135", high: "146", rawRange: "135-146")
        let analyte = try #require(catalog.analyte(withID: .sodium))

        let explanation = try ExplanationTemplate.explanation(for: result, analyte: analyte).get()

        #expect(explanation.body.hasSuffix("This value sits below that printed range."))
    }

    @Test("The persistent footer never varies")
    func footerConstant() {
        #expect(ExplanationTemplate.footer == "Not medical advice. Talk to your clinician.")
    }

    @Test("Mismatched analyte/result pairs are typed failures")
    func analyteMismatchFails() throws {
        let result = explainResult(analyteID: .potassium, value: "4.2", unit: .mmolPerL, low: "3.5", high: "5.3", rawRange: "3.5-5.3")
        let glucose = try #require(catalog.analyte(withID: .glucose))

        let outcome = ExplanationTemplate.explanation(for: result, analyte: glucose)

        #expect(outcome == .failure(.analyteMismatch(expected: .glucose, got: .potassium)))
    }
}

@Suite("Banned-phrase lint (no diagnosis, dosing or treatment language)")
struct BannedPhraseLintTests {
    @Test(
        "Detects banned stems case-insensitively",
        arguments: [
            "We diagnose you with X",
            "Increase the dose",
            "This needs TREATMENT",
            "stop taking your medication",
            "Your value is normal",
        ]
    )
    func detectsBannedPhrases(text: String) {
        #expect(!BannedPhraseLint.violations(in: text).isEmpty)
    }

    @Test("Clean explanation copy passes the lint")
    func cleanCopyPasses() {
        let copy = "Potassium was 4.2 mmol/L on Apr 12, 2026. This value sits within that printed range."
        #expect(BannedPhraseLint.violations(in: copy).isEmpty)
    }

    @Test("The lint runs on every rendered explanation before display")
    func lintGatesRendering() {
        // An analyte whose (synthetic) catalog name carries a banned stem
        // must fail rendering — proof the gate sits inside the renderer.
        let poisoned = Analyte(
            id: .potassium,
            canonicalName: "Potassium dose panel",
            aliases: [],
            canonicalUnit: .mmolPerL,
            displayPrecision: 1
        )
        let result = explainResult(analyteID: .potassium, value: "4.2", unit: .mmolPerL, low: "3.5", high: "5.3", rawRange: "3.5-5.3")

        let outcome = ExplanationTemplate.explanation(for: result, analyte: poisoned)

        #expect(outcome == .failure(.bannedPhrase(violations: ["dose"])))
    }
}
