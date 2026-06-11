import SwiftUI

/// Typographic cues of paper records: serif (New York) for record
/// titles, analyte names and large trend numerals; the system sans
/// (SF Pro) for UI chrome. Dynamic Type friendly throughout.
public enum VellumTypography {
    /// Large trend numeral — the hero of a trend screen.
    public static let trendNumeral = Font.system(size: 56, weight: .semibold, design: .serif)
    /// Record / document titles.
    public static let recordTitle = Font.system(.title2, design: .serif).weight(.semibold)
    /// Analyte names in lists and review rows.
    public static let analyteName = Font.system(.headline, design: .serif)
    /// Values and ranges presented next to analyte names.
    public static let valueText = Font.system(.body, design: .monospaced)
    /// UI chrome: buttons, captions, metadata.
    public static let chrome = Font.system(.subheadline)
    public static let caption = Font.system(.caption)
}

public enum VellumSpacing {
    public static let hairline: CGFloat = 1
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 40
}
