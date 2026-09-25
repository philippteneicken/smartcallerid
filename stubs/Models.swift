import Foundation

/// Eine Firma aus dem Adressbuch, für die wir Durchwahlen generieren.
struct Company: Identifiable, Codable, Equatable {
    var id: Int64?
    let contactIdentifier: String       // CNContact.identifier
    var organizationName: String
    var basePhoneE164: String           // bereits normalisiert
    var extensionCount: Int             // wie viele Durchwahlen generieren (10, 100, 1000)
    var isEnabled: Bool
    var updatedAt: Date
}

/// Ein einzelner Eintrag, der an die Call Directory Extension übergeben wird.
struct DirectoryEntry: Equatable {
    let e164: String         // "+4956329699716"
    let phoneNumber: Int64   // 4956329699716 — für CXCallDirectory
    let label: String        // "Möglich: CLEANGAS GmbH"
}
