import Foundation
import SQLite3

public enum VaultError: Error, Equatable, Sendable {
    case openFailed(path: String, message: String)
    case statementFailed(sql: String, message: String)
    case corruptRow(table: String, description: String)
    case directoryCreationFailed(path: String, description: String)
}

/// Minimal, dependency-free wrapper over the system SQLite3 C API.
/// Confined to the `VaultStore` actor — deliberately not Sendable.
/// (GRDB remains the DESIGN.md target; this wrapper keeps M1 free of
/// network-fetched dependencies. Swapping it out is internal to
/// VellumVault.)
final class SQLiteDatabase {
    enum Value {
        case text(String)
        case int(Int64)
        case null
    }

    private let handle: OpaquePointer
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        var rawHandle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &rawHandle, flags, nil) == SQLITE_OK, let opened = rawHandle else {
            let message = rawHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let leaked = rawHandle { sqlite3_close(leaked) }
            throw VaultError.openFailed(path: path, message: message)
        }
        handle = opened
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw VaultError.statementFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func run(_ sql: String, bindings: [Value]) throws {
        let statement = try prepare(sql, bindings: bindings)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw VaultError.statementFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Run a query; each row is the list of column values as optional
    /// strings (all vault columns are TEXT/INTEGER by schema).
    func query(_ sql: String, bindings: [Value] = []) throws -> [[String?]] {
        let statement = try prepare(sql, bindings: bindings)
        defer { sqlite3_finalize(statement) }
        var rows: [[String?]] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE { break }
            guard stepResult == SQLITE_ROW else {
                throw VaultError.statementFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
            let columnCount = sqlite3_column_count(statement)
            let row = (0 ..< columnCount).map { index -> String? in
                guard let cString = sqlite3_column_text(statement, index) else { return nil }
                return String(cString: cString)
            }
            rows.append(row)
        }
        return rows
    }

    private func prepare(_ sql: String, bindings: [Value]) throws -> OpaquePointer {
        var rawStatement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &rawStatement, nil) == SQLITE_OK, let statement = rawStatement else {
            throw VaultError.statementFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
        for (offset, value) in bindings.enumerated() {
            let position = Int32(offset + 1)
            let bindResult: Int32 = switch value {
            case let .text(text): sqlite3_bind_text(statement, position, text, -1, Self.transient)
            case let .int(number): sqlite3_bind_int64(statement, position, number)
            case .null: sqlite3_bind_null(statement, position)
            }
            guard bindResult == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw VaultError.statementFailed(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
            }
        }
        return statement
    }
}
