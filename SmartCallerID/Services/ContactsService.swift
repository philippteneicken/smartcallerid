import Foundation
import Contacts
import os.log

final class ContactsService {
    struct WorkContactSeed: Equatable {
        let contactIdentifier: String
        let displayName: String
        let phoneNumbers: [String]
    }

    private let store = CNContactStore()
    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "ContactsService")

    func requestAccess() async -> Bool {
        let current = CNContactStore.authorizationStatus(for: .contacts)
        switch current {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            do {
                return try await store.requestAccess(for: .contacts)
            } catch {
                logger.error("Kontakt-Zugriff fehlgeschlagen: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    func fetchWorkLabeledContacts() throws -> [WorkContactSeed] {
        // CNContactFormatter greift KVC-artig auf diverse Name-Keys zu. Fehlt einer,
        // wirft iOS eine CNPropertyNotFetchedException (NSException, in Swift
        // uncatchable) -> App-Crash. `descriptorForRequiredKeys` liefert alle
        // dafür nötigen Keys in einem Rutsch.
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)

        var results: [WorkContactSeed] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let phones = contact.phoneNumbers
                .filter { Self.isWorkPhoneLabel($0.label) }
                .map { $0.value.stringValue }
            guard !phones.isEmpty else { return }

            let organizationName = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayName = organizationName.isEmpty ? fullName : organizationName
            guard !displayName.isEmpty else { return }

            results.append(
                WorkContactSeed(
                    contactIdentifier: contact.identifier,
                    displayName: displayName,
                    phoneNumbers: phones
                )
            )
        }

        return results
    }

    static func isWorkPhoneLabel(_ rawLabel: String?) -> Bool {
        guard let rawLabel else { return false }
        if rawLabel == CNLabelWork { return true }

        let localized = CNLabeledValue<NSString>.localizedString(forLabel: rawLabel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return localized == "arbeit"
            || localized == "work"
            || localized == "trabalho"
            || localized == "trabajo"
    }
}
