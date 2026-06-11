import Foundation
import VellumCore

/// An answer over confirmed records. Every found answer cites its source
/// documents; a miss is an explicit "couldn't find" — never a guess.
public struct AskAnswer: Sendable, Equatable {
    public let text: String
    public let citedDocumentIDs: [UUID]

    public init(text: String, citedDocumentIDs: [UUID]) {
        self.text = text
        self.citedDocumentIDs = citedDocumentIDs
    }

    public var isNotFound: Bool {
        citedDocumentIDs.isEmpty
    }
}

/// Boundary for ask-your-records. The M2+ implementation composes
/// answers with AFM over a local embedding index; M1 ships only the
/// deterministic keyword search below. Both read confirmed `LabResult`s
/// ONLY (invariant #3) and must cite source documents.
public protocol RecordQuestionAnswering: Sendable {
    func answer(question: String, over results: [LabResult]) -> AskAnswer
}

/// Deterministic catalog-keyword search: finds the analyte named in the
/// question and reports the most recent confirmed observation, citing
/// its source document.
public struct LocalRecordSearch: RecordQuestionAnswering {
    public static let notFoundText = "I couldn't find that in these records."

    public let catalog: AnalyteCatalog

    public init(catalog: AnalyteCatalog = .standard) {
        self.catalog = catalog
    }

    public func answer(question: String, over results: [LabResult]) -> AskAnswer {
        guard let analyte = analyteNamed(in: question) else {
            return AskAnswer(text: Self.notFoundText, citedDocumentIDs: [])
        }
        let matches = results
            .filter { $0.analyteID == analyte.id }
            .sorted { $0.collectedAt < $1.collectedAt }
        guard let latest = matches.last else {
            return AskAnswer(text: Self.notFoundText, citedDocumentIDs: [])
        }
        let value = String(describing: latest.value.rounded(toPlaces: analyte.displayPrecision))
        let text = "Latest \(analyte.canonicalName): \(value) \(latest.unit.symbol) "
            + "on \(VellumDateFormat.mediumUTC(latest.collectedAt)), from a confirmed document in this vault."
        return AskAnswer(text: text, citedDocumentIDs: [latest.provenance.documentID])
    }

    private func analyteNamed(in question: String) -> Analyte? {
        let normalized = " " + AnalyteCatalog.searchNormalize(question) + " "
        // Longest alias first so "platelet count" beats "platelet".
        let candidates = catalog.analytes
            .flatMap { analyte in (analyte.aliases + [analyte.canonicalName]).map { (alias: $0, analyte: analyte) } }
            .sorted { $0.alias.count > $1.alias.count }
        return candidates.first { normalized.contains(" " + AnalyteCatalog.searchNormalize($0.alias) + " ") }?.analyte
    }
}

public extension AnalyteCatalog {
    /// Question-text normalization: uppercase, punctuation stripped,
    /// whitespace collapsed — so "Dad's potassium?" matches "POTASSIUM".
    static func searchNormalize(_ text: String) -> String {
        text.uppercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
