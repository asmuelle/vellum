#if canImport(Charts) && canImport(SwiftUI)
    import Charts
    import SwiftUI
    import VellumCore
    import VellumDesignSystem

    /// The M1 trend surface: serif hero numeral, one Swift Charts line,
    /// semantic point colors (teal in range, claret out of range), full
    /// VoiceOver labels on every mark.
    public struct TrendChartView: View {
        public let analyte: Analyte
        public let series: TrendSeries

        public init(analyte: Analyte, series: TrendSeries) {
            self.analyte = analyte
            self.series = series
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: VellumSpacing.m) {
                header
                chart
            }
            .padding(VellumSpacing.l)
            .background(VellumPalette.surface.color)
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: VellumSpacing.xs) {
                Text(analyte.canonicalName)
                    .font(VellumTypography.recordTitle)
                    .foregroundStyle(VellumPalette.inkPrimary.color)
                if let latest = series.latest {
                    Text(displayValue(latest.value))
                        .font(VellumTypography.trendNumeral)
                        .foregroundStyle(color(for: latest.status))
                        .accessibilityLabel("Latest \(analyte.canonicalName): \(displayValue(latest.value)) \(latest.unit.symbol)")
                    Text("\(latest.unit.symbol)  ·  printed range \(latest.printedRange.rawText)")
                        .font(VellumTypography.chrome)
                        .foregroundStyle(VellumPalette.inkSecondary.color)
                }
            }
        }

        private var chart: some View {
            Chart(series.points) { point in
                LineMark(
                    x: .value("Collected", point.collectedAt),
                    y: .value(analyte.canonicalName, doubleValue(point.value))
                )
                .foregroundStyle(VellumPalette.confirmed.color)
                PointMark(
                    x: .value("Collected", point.collectedAt),
                    y: .value(analyte.canonicalName, doubleValue(point.value))
                )
                .foregroundStyle(color(for: point.status))
                .accessibilityLabel(accessibilityLabel(for: point))
            }
            .frame(minHeight: 220)
        }

        private func color(for status: RangeStatus) -> Color {
            status == .inRange ? VellumPalette.confirmed.color : VellumPalette.outOfRange.color
        }

        private func displayValue(_ value: Decimal) -> String {
            String(describing: value.rounded(toPlaces: analyte.displayPrecision))
        }

        private func doubleValue(_ value: Decimal) -> Double {
            NSDecimalNumber(decimal: value).doubleValue
        }

        private func accessibilityLabel(for point: TrendPoint) -> String {
            let status = switch point.status {
            case .inRange: "within the printed range"
            case .aboveRange: "above the printed range"
            case .belowRange: "below the printed range"
            }
            return "\(VellumDateFormat.mediumUTC(point.collectedAt)): \(displayValue(point.value)) \(point.unit.symbol), \(status)"
        }
    }
#endif
