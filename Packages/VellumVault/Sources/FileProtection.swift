import Foundation

public enum FileProtectionError: Error, Equatable, Sendable {
    case attributeWriteFailed(path: String, description: String)
}

/// Seam for PRODUCT INVARIANT #5 so the vault's protection behavior is
/// testable on macOS (where iOS data protection does not exist) and real
/// on device.
public protocol FileProtectionApplying: Sendable {
    func applyCompleteFileProtection(to url: URL) throws
    func excludeFromBackup(_ url: URL) throws
}

/// Production applier. `NSFileProtectionComplete` is an iOS data-
/// protection attribute; on macOS (dev/test host) it is a no-op by
/// definition, while backup exclusion works on both platforms.
public struct DefaultFileProtectionApplier: FileProtectionApplying {
    public init() {}

    public func applyCompleteFileProtection(to url: URL) throws {
        #if os(iOS)
            do {
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: url.path
                )
            } catch {
                throw FileProtectionError.attributeWriteFailed(path: url.path, description: String(describing: error))
            }
        #endif
    }

    public func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            throw FileProtectionError.attributeWriteFailed(path: url.path, description: String(describing: error))
        }
    }
}
