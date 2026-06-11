import SwiftUI
import VellumCore
import VellumDesignSystem
import VellumReview
import VellumTrends

/// The family folio: profile header, scan entry point, the per-value
/// review ledger, and one trend. Archival paper-trust direction —
/// vellum surface, serif record titles, strictly semantic color.
struct FolioHomeView: View {
    @Bindable var model: FolioModel

    var body: some View {
        NavigationStack {
            List {
                folioHeader
                if let session = model.session {
                    reviewSection(session)
                } else {
                    scanSection
                }
                trendSection
                privacySection
            }
            .scrollContentBackground(.hidden)
            .background(VellumPalette.surface.color)
            .navigationTitle("Vellum")
            .task { await model.refreshTrend() }
        }
    }

    private var folioHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: VellumSpacing.xs) {
                Text("\(model.profile.displayName)’s folio")
                    .font(VellumTypography.recordTitle)
                    .foregroundStyle(VellumPalette.inkPrimary.color)
                Text("\(model.confirmedResultCount) values verified by you")
                    .font(VellumTypography.chrome)
                    .foregroundStyle(VellumPalette.inkSecondary.color)
            }
            .listRowBackground(VellumPalette.surfaceRaised.color)
        }
    }

    private var scanSection: some View {
        Section {
            Group {
                if let sample = model.remainingSamples.first {
                    Button {
                        Task { await model.scanNextSample() }
                    } label: {
                        Label("Scan sample: \(sample.title)", systemImage: "doc.viewfinder")
                            .font(VellumTypography.chrome)
                    }
                    .accessibilityIdentifier("scan-next-sample")
                } else {
                    Text("All sample pages filed.")
                        .font(VellumTypography.chrome)
                        .foregroundStyle(VellumPalette.inkSecondary.color)
                }
                if case let .failed(message) = model.phase {
                    Text(message)
                        .font(VellumTypography.caption)
                        .foregroundStyle(VellumPalette.outOfRange.color)
                }
            }
            .listRowBackground(VellumPalette.surfaceRaised.color)
        }
    }

    private func reviewSection(_ session: ReviewSession) -> some View {
        Section {
            ForEach(session.values) { value in
                ReviewRowView(
                    value: value,
                    onConfirm: { model.confirm(value.id) },
                    onReject: { model.reject(value.id) }
                )
            }
            Button("Verify all high-confidence parsed rows") {
                model.bulkConfirmEligibleRows()
            }
            .font(VellumTypography.chrome)
            .foregroundStyle(VellumPalette.confirmed.color)
            .accessibilityIdentifier("bulk-confirm-eligible")
        } header: {
            Text("Review — every value needs your stamp")
                .font(VellumTypography.caption)
                .foregroundStyle(VellumPalette.awaiting.color)
        }
        .listRowBackground(VellumPalette.surfaceRaised.color)
    }

    @ViewBuilder private var trendSection: some View {
        if let analyte = model.trendAnalyte, let trend = model.trend, !trend.points.isEmpty {
            Section {
                TrendChartView(analyte: analyte, series: trend)
                    .listRowInsets(EdgeInsets())
                Text("Across \(trend.documentCount) source document(s); ranges as printed on each page.")
                    .font(VellumTypography.caption)
                    .foregroundStyle(VellumPalette.inkSecondary.color)
            } header: {
                Text("Trend")
                    .font(VellumTypography.caption)
                    .foregroundStyle(VellumPalette.inkSecondary.color)
            }
            .listRowBackground(VellumPalette.surfaceRaised.color)
        }
    }

    private var privacySection: some View {
        Section {
            Label("Nothing leaves this phone. No account, no upload, ever.", systemImage: "lock.shield")
                .font(VellumTypography.caption)
                .foregroundStyle(VellumPalette.inkSecondary.color)
                .listRowBackground(VellumPalette.surfaceRaised.color)
        }
    }
}
