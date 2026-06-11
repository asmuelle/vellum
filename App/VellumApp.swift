import SwiftUI
import VellumDesignSystem

/// Composition root. The M1 slice wires the full engine —
/// capture (fixture OCR double) → deterministic parse → per-value
/// review → encrypted vault → trend — entirely on-device, with the
/// LLM seam wired to the production "unavailable" provider.
@main
struct VellumApp: App {
    @State private var model = FolioModel()

    var body: some Scene {
        WindowGroup {
            FolioHomeView(model: model)
                .background(VellumPalette.surface.color)
        }
    }
}
