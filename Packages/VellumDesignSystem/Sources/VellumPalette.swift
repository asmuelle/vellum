import Foundation
import SwiftUI

/// "Archival paper-trust" palette (DESIGN.md visual direction).
/// Color is strictly semantic, never decorative:
///   amber = awaiting confirmation, teal = confirmed/in-range,
///   claret = out-of-range, slate = unparsed scan.
/// Every semantic ink is AA-contrast (>= 4.5:1) against the vellum
/// surface — pinned by VellumDesignSystemTests.
public enum VellumPalette: String, CaseIterable, Sendable {
    case surface = "#F7F3EA"
    case surfaceRaised = "#FDFBF5"
    case inkPrimary = "#2A241E"
    case inkSecondary = "#5C5347"
    case awaiting = "#7A5200"
    case confirmed = "#0F5E58"
    case outOfRange = "#7E2A35"
    case unparsed = "#4E5A63"
    case hairline = "#D8D0BF"

    public var hex: String {
        rawValue
    }

    public var rgb: RGBColor {
        // Raw values are compile-time constants; a malformed hex would
        // trip the palette unit tests immediately.
        RGBColor.fromHex(rawValue) ?? RGBColor(red: 0, green: 0, blue: 0)
    }

    public var color: Color {
        let rgb = rgb
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// The tokens that render as text/glyphs on `surface` and must hold
    /// WCAG AA contrast.
    public static var semanticInks: [VellumPalette] {
        [.inkPrimary, .inkSecondary, .awaiting, .confirmed, .outOfRange, .unparsed]
    }
}
