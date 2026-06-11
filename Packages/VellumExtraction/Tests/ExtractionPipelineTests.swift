import Foundation
import Testing
import VellumCapture
@testable import VellumCore
@testable import VellumExtraction
import VellumParsing
import VellumTestSupport

/// Counts LLM invocations so the deterministic-first invariant is
/// observable from outside the pipeline.
actor CallCounter {
    private(set) var count = 0
    func increment() {
        count += 1
    }
}

struct SpyLLMProvider: LLMExtractionProviding {
    let counter = CallCounter()
    var availability: LLMAvailability {
        .available
    }

    func extractValues(fromOCRText _: String, documentID _: UUID, pageID _: UUID) async throws -> [ExtractedValue] {
        await counter.increment()
        return []
    }
}

/// A misbehaving provider that lies about its extraction method.
struct MislabelingLLMProvider: LLMExtractionProviding {
    var availability: LLMAvailability {
        .available
    }

    func extractValues(fromOCRText _: String, documentID: UUID, pageID: UUID) async throws -> [ExtractedValue] {
        [ExtractedValue(
            documentID: documentID,
            pageID: pageID,
            boundingBox: .zero,
            analyteRaw: "POTASSIUM",
            valueRaw: "4.1",
            unitRaw: "mmol/L",
            refRangeRaw: "3.5-5.1",
            extractionMethod: .deterministic, // the lie
            confidence: 0.4
        )]
    }
}

struct ThrowingLLMProvider: LLMExtractionProviding {
    var availability: LLMAvailability {
        .available
    }

    func extractValues(fromOCRText _: String, documentID _: UUID, pageID _: UUID) async throws -> [ExtractedValue] {
        throw LLMExtractionError.extractionFailed("synthetic failure")
    }
}

func fixturePage(_ name: String) throws -> OCRPage {
    try OCRPageFactory.page(fromPlainText: FixtureLoader.text(named: name))
}

@Suite("Extraction pipeline (PRODUCT INVARIANT #2: deterministic before LLM, always)")
struct ExtractionPipelineTests {
    @Test(
        "The LLM path is NEVER invoked on a fixture a deterministic parser claims",
        arguments: ["quest_cmp_2026-04-12.txt", "quest_bmp_2026-05-20.txt", "labcorp_cbc_2026-03-02.txt"]
    )
    func llmNeverRunsOnClaimedFixtures(fixture: String) async throws {
        let spy = SpyLLMProvider()
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: spy)

        let outcome = try await pipeline.extract(from: fixturePage(fixture), documentID: UUID())

        guard case let .deterministic(values, _, _) = outcome else {
            Issue.record("expected deterministic outcome for \(fixture), got \(outcome)")
            return
        }
        #expect(!values.isEmpty)
        #expect(await spy.counter.count == 0, "invariant #2 violated: LLM consulted on a deterministically claimed page")
    }

    @Test("Deterministic miss falls back to the mock LLM, all values tagged .llm")
    func fallbackTagsValuesAsLLM() async throws {
        let mock = MockLLMExtractionProvider(cannedRows: [
            (analyteRaw: "POTASSIUM", valueRaw: "4.1", unitRaw: "mmol/L", refRangeRaw: "3.5-5.1"),
        ])
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: mock)

        let outcome = try await pipeline.extract(from: fixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())

        guard case let .llmFallback(values) = outcome else {
            Issue.record("expected llmFallback, got \(outcome)")
            return
        }
        #expect(values.count == 1)
        #expect(values.allSatisfy { $0.extractionMethod == .llm })
        #expect(values[0].valueRaw == "4.1", "raw strings pass through verbatim — no model-side normalization")
    }

    @Test("A provider lying about its method is force-retagged .llm")
    func mislabeledValuesAreRetagged() async throws {
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: MislabelingLLMProvider())

        let outcome = try await pipeline.extract(from: fixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())

        guard case let .llmFallback(values) = outcome else {
            Issue.record("expected llmFallback, got \(outcome)")
            return
        }
        #expect(values.allSatisfy { $0.extractionMethod == .llm }, "a provider can never smuggle values in as deterministic")
    }

    @Test("No AFM on device → stored as searchable scan, never a crash (invariant #7)")
    func unavailableLLMDegradesGracefully() async throws {
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: UnavailableLLMExtractionProvider())

        let outcome = try await pipeline.extract(from: fixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())

        #expect(outcome == .storedAsScan(.llmUnavailable(reason: UnavailableLLMExtractionProvider.defaultReason)))
    }

    @Test("LLM returning nothing → stored as scan with .noValuesFound")
    func emptyLLMResultStoresAsScan() async throws {
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: SpyLLMProvider())

        let outcome = try await pipeline.extract(from: fixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())

        #expect(outcome == .storedAsScan(.noValuesFound))
    }

    @Test("LLM failure → stored as scan with the failure description")
    func llmFailureStoresAsScan() async throws {
        let pipeline = ExtractionPipeline(deterministic: ParserRegistry(), llm: ThrowingLLMProvider())

        let outcome = try await pipeline.extract(from: fixturePage("unknown_hospital_2026-01-15.txt"), documentID: UUID())

        guard case .storedAsScan(.llmFailed(_)) = outcome else {
            Issue.record("expected storedAsScan(.llmFailed), got \(outcome)")
            return
        }
    }
}
