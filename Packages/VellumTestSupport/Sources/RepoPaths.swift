import Foundation

/// Locates the repository root from this file's compile-time path.
/// Works for `swift test` on macOS and for simulator-hosted unit tests,
/// because both run on the machine that compiled the sources.
public enum RepoPaths {
    /// …/Packages/VellumTestSupport/Sources/RepoPaths.swift → repo root.
    public static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // VellumTestSupport
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repo root
    }

    public static var fixturesDirectory: URL {
        repoRoot.appendingPathComponent("Fixtures", isDirectory: true)
    }

    public static var packagesDirectory: URL {
        repoRoot.appendingPathComponent("Packages", isDirectory: true)
    }

    public static var appSourcesDirectory: URL {
        repoRoot.appendingPathComponent("App", isDirectory: true)
    }
}
