import SwiftUI
import VellumCore
import VellumDesignSystem

/// One proposed value beside its provenance, with stamp-style confirm /
/// reject actions. The ledger metaphor: amber while awaiting, a teal
/// "verified" seal once confirmed, claret strikethrough when rejected.
public struct ReviewRowView: View {
    public let value: ExtractedValue
    public let onConfirm: () -> Void
    public let onReject: () -> Void

    public init(value: ExtractedValue, onConfirm: @escaping () -> Void, onReject: @escaping () -> Void) {
        self.value = value
        self.onConfirm = onConfirm
        self.onReject = onReject
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: VellumSpacing.m) {
            VStack(alignment: .leading, spacing: VellumSpacing.xs) {
                Text(value.analyteRaw)
                    .font(VellumTypography.analyteName)
                    .foregroundStyle(VellumPalette.inkPrimary.color)
                Text("\(value.valueRaw) \(value.unitRaw)  ·  printed range \(value.refRangeRaw)")
                    .font(VellumTypography.valueText)
                    .foregroundStyle(stateColor)
                    .strikethrough(value.reviewState == .rejected)
                Text(methodLabel)
                    .font(VellumTypography.caption)
                    .foregroundStyle(VellumPalette.inkSecondary.color)
            }
            Spacer()
            if value.reviewState == .pending {
                actionButtons
            } else {
                stateSeal
            }
        }
        .padding(.vertical, VellumSpacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value.analyteRaw), \(value.valueRaw) \(value.unitRaw), \(stateDescription)")
    }

    private var actionButtons: some View {
        HStack(spacing: VellumSpacing.s) {
            Button(action: onConfirm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(VellumPalette.confirmed.color)
            }
            .accessibilityIdentifier("review-confirm-\(value.id.uuidString)")
            Button(action: onReject) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(VellumPalette.outOfRange.color)
            }
            .accessibilityIdentifier("review-reject-\(value.id.uuidString)")
        }
        .buttonStyle(.plain)
    }

    private var stateSeal: some View {
        Image(systemName: value.reviewState == .rejected ? "xmark.circle.fill" : "checkmark.seal.fill")
            .foregroundStyle(stateColor)
            .accessibilityHidden(true)
    }

    private var stateColor: Color {
        switch value.reviewState {
        case .pending: VellumPalette.awaiting.color
        case .confirmed, .corrected: VellumPalette.confirmed.color
        case .rejected: VellumPalette.outOfRange.color
        }
    }

    private var methodLabel: String {
        value.extractionMethod == .deterministic ? "Parsed deterministically" : "Model-proposed — confirm individually"
    }

    private var stateDescription: String {
        switch value.reviewState {
        case .pending: "awaiting confirmation"
        case .confirmed: "confirmed"
        case .corrected: "corrected"
        case .rejected: "rejected"
        }
    }
}
