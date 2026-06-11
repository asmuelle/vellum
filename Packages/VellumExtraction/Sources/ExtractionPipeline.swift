import Foundation
import VellumCore

/// Why a document was stored as a plain searchable scan instead of
/// producing proposals (graceful degradation, invariant #7).
public enum ScanFallbackReason: Sendable, Equatable {
    case llmUnavailable(reason: String)
    case llmFailed(description: String)
    case noValuesFound
}

public enum ExtractionPipelineOutcome: Sendable, Equatable {
    case deterministic(values: [ExtractedValue], format: LabFormat, coverage: Double)
    case llmFallback(values: [ExtractedValue])
    case storedAsScan(ScanFallbackReason)
}

/// PRODUCT INVARIANT #2, executable form: deterministic before LLM,
/// always. The LLM provider is consulted ONLY on a deterministic miss,
/// and everything it returns is force-retagged `.llm` so a misbehaving
/// provider can never pose as the deterministic layer.
public struct ExtractionPipeline: Sendable {
    public let deterministic: any DeterministicExtracting
    public let llm: any LLMExtractionProviding

    public init(deterministic: any DeterministicExtracting, llm: any LLMExtractionProviding) {
        self.deterministic = deterministic
        self.llm = llm
    }

    public func extract(from page: OCRPage, documentID: UUID) async -> ExtractionPipelineOutcome {
        switch deterministic.extract(from: page, documentID: documentID) {
        case let .claimed(format, values, coverage):
            .deterministic(values: values, format: format, coverage: coverage)
        case .miss:
            await runLLMFallback(on: page, documentID: documentID)
        }
    }

    private func runLLMFallback(on page: OCRPage, documentID: UUID) async -> ExtractionPipelineOutcome {
        guard case .available = llm.availability else {
            if case let .unavailable(reason) = llm.availability {
                return .storedAsScan(.llmUnavailable(reason: reason))
            }
            return .storedAsScan(.llmUnavailable(reason: "unknown"))
        }
        do {
            // OCR text in, never pixels (DESIGN.md pipeline contract).
            let values = try await llm.extractValues(fromOCRText: page.fullText, documentID: documentID, pageID: page.id)
            guard !values.isEmpty else { return .storedAsScan(.noValuesFound) }
            return .llmFallback(values: values.map { $0.retagged(as: .llm) })
        } catch {
            return .storedAsScan(.llmFailed(description: String(describing: error)))
        }
    }
}
