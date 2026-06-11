import Foundation

/// PRODUCT INVARIANT #6 enforcement: no diagnosis, dosing, or treatment
/// language may ever reach the screen. Runs over every explanation
/// before display; the template tests pin the wording itself.
public enum BannedPhraseLint {
    /// Lowercased stems matched by containment.
    public static let bannedStems: [String] = [
        "diagnos",
        "dose",
        "dosing",
        "dosage",
        "treat",
        "prescri",
        "medicat",
        "stop taking",
        "start taking",
        "you should",
        "normal", // we only compare to the printed range; we never declare "normal"
    ]

    public static func violations(in text: String) -> [String] {
        let lowered = text.lowercased()
        return bannedStems.filter { lowered.contains($0) }
    }
}
