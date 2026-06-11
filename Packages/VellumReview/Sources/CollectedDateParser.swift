import Foundation

/// Parses the raw collection-date strings stamped by the parsers
/// ("04/12/2026 08:15" or "05/20/2026"). Fixed locale and timezone keep
/// results deterministic across devices and CI.
public enum CollectedDateParser {
    private static let formats = ["MM/dd/yyyy HH:mm", "MM/dd/yyyy"]

    public static func parse(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }
}
