import Foundation
import Testing
@testable import VellumDesignSystem

@Suite("Color math")
struct ColorHexTests {
    @Test("Parses #RRGGBB with and without the hash")
    func parsesHex() {
        let white = RGBColor.fromHex("#FFFFFF")
        #expect(white == RGBColor(red: 1, green: 1, blue: 1))
        #expect(RGBColor.fromHex("000000") == RGBColor(red: 0, green: 0, blue: 0))
    }

    @Test("Rejects malformed hex strings", arguments: ["", "#FFF", "#GGGGGG", "#FFFFFFF"])
    func rejectsMalformedHex(hex: String) {
        #expect(RGBColor.fromHex(hex) == nil)
    }

    @Test("Black on white is the maximum 21:1 contrast")
    func maxContrast() {
        let ratio = RGBColor.contrastRatio(
            RGBColor(red: 0, green: 0, blue: 0),
            RGBColor(red: 1, green: 1, blue: 1)
        )
        #expect(abs(ratio - 21) < 0.01)
    }
}

@Suite("Archival paper-trust palette (accessibility floor: WCAG AA)")
struct PaletteContrastTests {
    @Test("Every palette token is valid hex")
    func allTokensParse() {
        for token in VellumPalette.allCases {
            #expect(RGBColor.fromHex(token.hex) != nil, "malformed hex for \(token)")
        }
    }

    @Test("Every semantic ink holds AA contrast (>= 4.5:1) on the vellum surface")
    func semanticInksAreAA() {
        let surface = VellumPalette.surface.rgb
        for ink in VellumPalette.semanticInks {
            let ratio = RGBColor.contrastRatio(ink.rgb, surface)
            #expect(ratio >= 4.5, "\(ink) contrast \(ratio) on surface is below WCAG AA")
        }
    }

    @Test("Semantic inks also hold AA on the raised surface")
    func semanticInksAreAAOnRaisedSurface() {
        let raised = VellumPalette.surfaceRaised.rgb
        for ink in VellumPalette.semanticInks {
            #expect(RGBColor.contrastRatio(ink.rgb, raised) >= 4.5)
        }
    }

    @Test("Every token materializes a SwiftUI color from its hex")
    func tokensMaterializeColors() {
        for token in VellumPalette.allCases {
            _ = token.color
            let rgb = token.rgb
            #expect((0 ... 1).contains(rgb.red) && (0 ... 1).contains(rgb.green) && (0 ... 1).contains(rgb.blue))
        }
    }
}
