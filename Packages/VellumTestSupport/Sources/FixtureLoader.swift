import Foundation

public enum FixtureError: Error, Equatable {
    case missingFixture(String)
}

public enum FixtureLoader {
    /// Load a text fixture from `Fixtures/` (e.g. "quest_cmp_2026-04-12.txt").
    public static func text(named name: String) throws -> String {
        let url = RepoPaths.fixturesDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missingFixture(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Load and decode a JSON fixture from `Fixtures/expected/`.
    public static func expectedJSON<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        let url = RepoPaths.fixturesDirectory
            .appendingPathComponent("expected", isDirectory: true)
            .appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missingFixture("expected/\(name)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
