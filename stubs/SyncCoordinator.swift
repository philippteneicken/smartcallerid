import Foundation
import CallKit
import Contacts
import os.log

/// Orchestriert den Sync-Flow:
/// 1. Kontakte aus Adressbuch lesen
/// 2. Firmenkontakte filtern
/// 3. Pro Firma Fuzzy-Einträge generieren
/// 4. In DB schreiben
/// 5. Extension reloaden
@Observable
final class SyncCoordinator {

    enum SyncState: Equatable {
        case idle
        case running(progress: Double)
        case completed(companyCount: Int, entryCount: Int, at: Date)
        case failed(message: String)
    }

    private(set) var state: SyncState = .idle

    private let contactsService: ContactsService
    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "SyncCoordinator")

    init(contactsService: ContactsService = ContactsService()) {
        self.contactsService = contactsService
    }

    @MainActor
    func runSync() async {
        state = .running(progress: 0)

        do {
            // 1. Permission
            guard await contactsService.requestAccess() else {
                state = .failed(message: "Kein Zugriff auf Kontakte")
                return
            }

            // 2. Kontakte holen
            let companyContacts = try await contactsService.fetchCompanyContacts()
            logger.info("Gefundene Firmenkontakte: \(companyContacts.count)")

            // 3. DB öffnen
            let db = try DatabaseManager.openShared()

            var totalEntries = 0
            let total = max(companyContacts.count, 1)

            // 4. Pro Kontakt verarbeiten
            for (index, (contact, phoneNumbers)) in companyContacts.enumerated() {
                for rawPhone in phoneNumbers {
                    guard let e164 = PhoneNumberNormalizer.shared.normalize(rawPhone) else {
                        continue
                    }

                    var company = Company(
                        id: nil,
                        contactIdentifier: contact.identifier,
                        organizationName: contact.organizationName,
                        basePhoneE164: e164,
                        extensionCount: 100,
                        isEnabled: true,
                        updatedAt: Date()
                    )

                    let companyId = try db.upsertCompany(company)
                    company.id = companyId

                    let entries = FuzzyMatchGenerator.generateEntries(for: company)
                    try db.replaceEntries(forCompanyId: companyId, with: entries)
                    totalEntries += entries.count
                }

                state = .running(progress: Double(index + 1) / Double(total))
            }

            // 5. Extension reloaden
            try await reloadExtension()

            state = .completed(
                companyCount: companyContacts.count,
                entryCount: totalEntries,
                at: Date()
            )
            logger.info("Sync abgeschlossen: \(companyContacts.count) Firmen, \(totalEntries) Einträge")

        } catch {
            logger.error("Sync fehlgeschlagen: \(error.localizedDescription)")
            state = .failed(message: error.localizedDescription)
        }
    }

    private func reloadExtension() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            CXCallDirectoryManager.sharedInstance.reloadExtension(
                withIdentifier: AppGroupConstants.extensionBundleID
            ) { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
}
