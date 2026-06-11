import Foundation

/// Walks production Swift sources so invariant tests can enforce
/// repo-wide rules (no-egress, sole-minter, …) as executable checks.
public enum SourceScanner {
    public struct ScannedFile: Sendable {
        public let url: URL
        public let contents: String

        /// Path relative to the repo root, for readable assertions.
        public let relativePath: String
    }

    /// All `.swift` files under the given directories (recursive).
    public static func swiftFiles(under directories: [URL]) throws -> [ScannedFile] {
        let rootPath = RepoPaths.repoRoot.path
        var results: [ScannedFile] = []
        for directory in directories {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            while let entry = enumerator?.nextObject() as? URL {
                guard entry.pathExtension == "swift" else { continue }
                let contents = try String(contentsOf: entry, encoding: .utf8)
                let relative = String(entry.path.dropFirst(rootPath.count + 1))
                results.append(ScannedFile(url: entry, contents: contents, relativePath: relative))
            }
        }
        return results.sorted { $0.relativePath < $1.relativePath }
    }

    /// Production sources only: every `Packages/*/Sources` directory plus `App/`.
    public static func productionSwiftFiles() throws -> [ScannedFile] {
        let packageSources = try FileManager.default
            .contentsOfDirectory(at: RepoPaths.packagesDirectory, includingPropertiesForKeys: nil)
            .filter(\.hasDirectoryPath)
            .map { $0.appendingPathComponent("Sources", isDirectory: true) }
        return try swiftFiles(under: packageSources + [RepoPaths.appSourcesDirectory])
    }
}
