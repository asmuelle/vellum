import Foundation
import Testing
@testable import VellumCore

@Suite("Document and profile models")
struct DocumentModelsTests {
    @Test("Profiles carry the caregiver relationship model")
    func profileModel() {
        let profile = Profile(displayName: "Dad", relationship: .parent, createdAt: Date(timeIntervalSince1970: 0))
        #expect(profile.displayName == "Dad")
        #expect(profile.relationship == .parent)
        #expect(Relationship.selfPerson.rawValue == "self")
    }

    @Test("withParseStatus is an immutable update")
    func documentStatusUpdate() {
        let document = DocumentRecord(
            profileID: UUID(),
            kind: .labReport,
            capturedAt: Date(timeIntervalSince1970: 1_775_981_700),
            detectedFormat: .quest,
            parseStatus: .captured,
            pageCount: 1
        )

        let reviewed = document.withParseStatus(.reviewed)

        #expect(document.parseStatus == .captured, "original is untouched")
        #expect(reviewed.parseStatus == .reviewed)
        #expect(reviewed.id == document.id)
        #expect(reviewed.detectedFormat == .quest)
        #expect(reviewed.pageCount == 1)
    }

    @Test("Lab units render their printed symbol")
    func labUnitDescription() {
        #expect(LabUnit.mgPerDL.description == "mg/dL")
        #expect(LabUnit("mmol/L") == LabUnit.mmolPerL)
        #expect(LabUnit.mEqPerL != LabUnit.mmolPerL, "equivalence must be an explicit table entry, never an alias")
    }
}
