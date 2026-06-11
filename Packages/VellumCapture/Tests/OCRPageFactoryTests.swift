import Foundation
import Testing
@testable import VellumCapture
@testable import VellumCore
import VellumTestSupport

@Suite("OCR page factory")
struct OCRPageFactoryTests {
    @Test("Assigns top-to-bottom synthetic bounding boxes")
    func boundingBoxesDescendThePage() {
        let page = OCRPageFactory.page(fromPlainText: "alpha\nbeta\ngamma")
        #expect(page.lines.count == 3)
        #expect(page.lines.map(\.text) == ["alpha", "beta", "gamma"])
        let ys = page.lines.map(\.boundingBox.y)
        #expect(ys == ys.sorted(), "boxes must descend top-to-bottom")
        #expect(page.lines.allSatisfy { $0.boundingBox.height > 0 && $0.boundingBox.width == 1 })
    }

    @Test("Filters blank lines but preserves order")
    func filtersBlankLines() {
        let page = OCRPageFactory.page(fromPlainText: "alpha\n\n   \nbeta\n")
        #expect(page.lines.map(\.text) == ["alpha", "beta"])
    }

    @Test("fullText joins lines with newlines")
    func fullTextJoins() {
        let page = OCRPageFactory.page(fromPlainText: "alpha\nbeta")
        #expect(page.fullText == "alpha\nbeta")
    }
}

@Suite("Fixture OCR provider (deterministic capture double)")
struct FixtureOCRProviderTests {
    @Test("Recognizes a checked-in fixture transcript")
    func recognizesFixture() async throws {
        let text = try FixtureLoader.text(named: "quest_cmp_2026-04-12.txt")
        let page = try await FixtureOCRProvider().recognizePage(from: Data(text.utf8))
        #expect(page.lines.first?.text == "QUEST DIAGNOSTICS INCORPORATED")
        #expect(page.lines.count > 10)
    }

    @Test("Empty input is a typed OCR error, never a silent drop")
    func emptyInputThrows() async {
        await #expect(throws: OCRError.unreadableInput) {
            _ = try await FixtureOCRProvider().recognizePage(from: Data())
        }
    }
}
