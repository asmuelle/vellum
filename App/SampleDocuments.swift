import Foundation

/// Bundled synthetic sample printouts (same synthetic corpus as
/// `Fixtures/`) so the M1 slice runs end-to-end in the simulator with
/// no camera, no network, and no platform AI. Real capture (VisionKit +
/// Vision OCR) replaces this entry point on device.
struct SampleDocument: Identifiable, Equatable {
    let id: UUID
    let title: String
    let transcript: String
}

enum SampleDocuments {
    static let all: [SampleDocument] = [
        SampleDocument(
            id: UUID(),
            title: "Quest CMP — Apr 12, 2026",
            transcript: """
            QUEST DIAGNOSTICS INCORPORATED
            PATIENT: SAMPLE, VERA                                SYNTHETIC FIXTURE
            COLLECTED: 04/12/2026 08:15
            REPORTED: 04/13/2026 06:02
            COMPREHENSIVE METABOLIC PANEL

            TEST NAME                        RESULT        REFERENCE RANGE    UNITS
            GLUCOSE                          110 H         65-99              mg/dL
            UREA NITROGEN (BUN)              18            7-25               mg/dL
            CREATININE                       0.92          0.60-1.35          mg/dL
            SODIUM                           139           135-146            mmol/L
            POTASSIUM                        4.2           3.5-5.3            mmol/L
            CHLORIDE                         102           98-110             mmol/L
            CARBON DIOXIDE                   24            20-32              mmol/L
            CALCIUM                          9.4           8.6-10.3           mg/dL
            """
        ),
        SampleDocument(
            id: UUID(),
            title: "Quest BMP — May 20, 2026",
            transcript: """
            QUEST DIAGNOSTICS INCORPORATED
            PATIENT: SAMPLE, VERA                                SYNTHETIC FIXTURE
            COLLECTED: 05/20/2026 07:40
            REPORTED: 05/20/2026 19:12
            BASIC METABOLIC PANEL

            TEST NAME                        RESULT        REFERENCE RANGE    UNITS
            GLUCOSE                          94            65-99              mg/dL
            UREA NITROGEN (BUN)              16            7-25               mg/dL
            CREATININE                       0.95          0.60-1.35          mg/dL
            SODIUM                           141           135-146            mmol/L
            POTASSIUM                        5.6 H         3.5-5.3            mmol/L
            CHLORIDE                         104           98-110             mmol/L
            CARBON DIOXIDE                   26            20-32              mmol/L
            CALCIUM                          9.2           8.6-10.3           mg/dL
            """
        ),
    ]
}
