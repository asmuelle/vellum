import Foundation

public enum Relationship: String, Sendable, Codable, CaseIterable, Hashable {
    case selfPerson = "self"
    case parent
    case child
    case partner
    case other
}

public struct Profile: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let relationship: Relationship
    public let createdAt: Date

    public init(id: UUID = UUID(), displayName: String, relationship: Relationship, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.relationship = relationship
        self.createdAt = createdAt
    }
}

public enum DocumentKind: String, Sendable, Codable, CaseIterable, Hashable {
    case labReport
    case prescription
    case dischargeSummary
    case eob
    case other
}

public enum LabFormat: String, Sendable, Codable, Hashable {
    case quest
    case labcorp
    case epic
    case unknown
}

public enum ParseStatus: String, Sendable, Codable, Hashable {
    case captured
    case parsed
    case awaitingReview
    case reviewed
}

public struct DocumentRecord: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let profileID: UUID
    public let kind: DocumentKind
    public let capturedAt: Date
    public let detectedFormat: LabFormat?
    public let parseStatus: ParseStatus
    public let pageCount: Int

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        kind: DocumentKind,
        capturedAt: Date,
        detectedFormat: LabFormat?,
        parseStatus: ParseStatus,
        pageCount: Int
    ) {
        self.id = id
        self.profileID = profileID
        self.kind = kind
        self.capturedAt = capturedAt
        self.detectedFormat = detectedFormat
        self.parseStatus = parseStatus
        self.pageCount = pageCount
    }

    public func withParseStatus(_ status: ParseStatus) -> DocumentRecord {
        DocumentRecord(
            id: id, profileID: profileID, kind: kind, capturedAt: capturedAt,
            detectedFormat: detectedFormat, parseStatus: status, pageCount: pageCount
        )
    }
}
