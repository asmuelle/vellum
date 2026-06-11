import Foundation

/// Deterministic, locale-pinned date rendering for record surfaces
/// (trends, ask, explain). UTC + en_US_POSIX keeps output identical
/// across devices, simulators and CI — snapshot tests depend on it.
public enum VellumDateFormat {
    public static func mediumUTC(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
