import Foundation
import Observation
import VellumCapture
import VellumCore
import VellumExtraction
import VellumParsing
import VellumReview
import VellumTrends
import VellumVault

/// Drives the M1 vertical slice: scan a sample → deterministic parse →
/// per-value confirmation → mint into the encrypted vault → trend.
/// Every stage goes through the same engine the tests exercise.
@MainActor
@Observable
final class FolioModel {
    enum Phase: Equatable {
        case idle
        case reviewing(documentTitle: String)
        case failed(String)
    }

    let profile = Profile(displayName: "Dad", relationship: .parent, createdAt: Date(timeIntervalSince1970: 0))
    let trendAnalyteID = AnalyteID.potassium

    private(set) var phase: Phase = .idle
    private(set) var session: ReviewSession?
    private(set) var trend: TrendSeries?
    private(set) var confirmedResultCount = 0
    private(set) var remainingSamples = SampleDocuments.all

    private let ocr = FixtureOCRProvider()
    private let pipeline = ExtractionPipeline(
        deterministic: ParserRegistry(),
        llm: UnavailableLLMExtractionProvider() // graceful no-AFM path (invariant #7)
    )
    private var store: VaultStore?

    var trendAnalyte: Analyte? {
        AnalyteCatalog.standard.analyte(withID: trendAnalyteID)
    }

    // MARK: Scan → review

    func scanNextSample() async {
        guard session == nil, let sample = remainingSamples.first else { return }
        do {
            let page = try await ocr.recognizePage(from: Data(sample.transcript.utf8))
            let documentID = UUID()
            switch await pipeline.extract(from: page, documentID: documentID) {
            case let .deterministic(values, _, _), let .llmFallback(values):
                session = ReviewSession(documentID: documentID, proposals: values)
                phase = .reviewing(documentTitle: sample.title)
            case let .storedAsScan(reason):
                phase = .failed("Stored as a searchable scan: \(describe(reason))")
            }
            remainingSamples.removeFirst()
        } catch {
            phase = .failed("Could not read the page: \(error)")
        }
    }

    // MARK: Per-value confirmation (PRODUCT INVARIANT #3)

    func confirm(_ valueID: UUID) {
        mutateSession { try $0.confirming(valueID) }
    }

    func reject(_ valueID: UUID) {
        mutateSession { try $0.rejecting(valueID) }
    }

    func bulkConfirmEligibleRows() {
        mutateSession { try $0.bulkConfirmingEligibleDeterministicRows() }
    }

    private func mutateSession(_ action: (ReviewSession) throws -> ReviewSession) {
        guard let current = session else { return }
        do {
            let updated = try action(current)
            session = updated
            if updated.isComplete {
                mintAndStore(updated)
            }
        } catch {
            phase = .failed("Review action failed: \(error)")
        }
    }

    // MARK: Mint → vault → trend

    private func mintAndStore(_ completed: ReviewSession) {
        do {
            let outcome = try completed.mintConfirmedResults(profileID: profile.id)
            let vault = try openVaultIfNeeded()
            session = nil
            phase = .idle
            Task {
                try await vault.save(outcome.results)
                await refreshTrend()
            }
            confirmedResultCount += outcome.results.count
        } catch {
            phase = .failed("Could not store confirmed values: \(error)")
        }
    }

    func refreshTrend() async {
        do {
            let vault = try openVaultIfNeeded()
            trend = try await TrendLoader.series(for: trendAnalyteID, profileID: profile.id, from: vault)
        } catch {
            phase = .failed("Could not load the trend: \(error)")
        }
    }

    private func openVaultIfNeeded() throws -> VaultStore {
        if let store { return store }
        let directory = URL.documentsDirectory.appendingPathComponent("Vault", isDirectory: true)
        let opened = try VaultStore(directory: directory)
        store = opened
        return opened
    }

    private func describe(_ reason: ScanFallbackReason) -> String {
        switch reason {
        case let .llmUnavailable(reason): reason
        case let .llmFailed(description): description
        case .noValuesFound: "no values found on the page"
        }
    }
}
