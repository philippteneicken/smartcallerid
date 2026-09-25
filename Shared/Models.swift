import Foundation
import GRDB

struct Company: Identifiable, Codable, Equatable, Hashable, FetchableRecord, MutablePersistableRecord {
    struct SyncKey: Hashable {
        let contactIdentifier: String
        let basePhoneE164: String
    }

    var id: Int64?
    var contactIdentifier: String
    var organizationName: String
    var basePhoneE164: String
    var extensionCount: Int
    var isEnabled: Bool
    var updatedAt: Date

    static let databaseTableName = "companies"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let contactIdentifier = Column(CodingKeys.contactIdentifier)
        static let organizationName = Column(CodingKeys.organizationName)
        static let basePhoneE164 = Column(CodingKeys.basePhoneE164)
        static let extensionCount = Column(CodingKeys.extensionCount)
        static let isEnabled = Column(CodingKeys.isEnabled)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var syncKey: SyncKey {
        SyncKey(contactIdentifier: contactIdentifier, basePhoneE164: basePhoneE164)
    }
}

struct DirectoryEntry: Equatable {
    let e164: String
    let phoneNumber: Int64
    let label: String
}
