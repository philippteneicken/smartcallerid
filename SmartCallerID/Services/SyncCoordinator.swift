import Foundation
import CallKit
import Contacts
import Observation
import os.log

@Observable
final class SyncCoordinator {
    private enum ReloadOutcome {
        case reloaded
        case skippedExtensionDisabled
        case skippedStatusUnavailable(String)
        case skippedReloadFailed(String)
    }


    enum SyncState: Equatable {
        case idle
        case running(progress: Double)
        case completed(contactCount: Int, entryCount: Int, at: Date)
        case failed(message: String)
    }

    private(set) var state: SyncState = .idle

    private let contactsService: ContactsService
    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "SyncCoordinator")

    init(contactsService: ContactsService = ContactsService()) {
        self.contactsService = contactsService
    }

    func runSync() async {
        await MainActor.run {
            state = .running(progress: 0)
        }

        do {
            guard await contactsService.requestAccess() else {
                await MainActor.run {
                    state = .failed(message: L10n.tr("sync.error.no_contacts_access"))
                }
                return
            }

            let syncResult = try await Task.detached(priority: .userInitiated) { [contactsService, logger] in
                let workContacts = try contactsService.fetchWorkLabeledContacts()
                    .sorted {
                        let nameOrder = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        if nameOrder != .orderedSame {
                            return nameOrder == .orderedAscending
                        }
                        return $0.contactIdentifier < $1.contactIdentifier
                    }

                let hasProAccess = AppGroupConstants.isProAccessUnlocked
                let contactsToSync = hasProAccess
                    ? workContacts
                    : Array(workContacts.prefix(AppGroupConstants.freeContactLimit))

                logger.info("Gefundene Kontakte mit Arbeit-Label: \(workContacts.count)")
                if !hasProAccess && workContacts.count > AppGroupConstants.freeContactLimit {
                    logger.info("Basisversion aktiv — synchronisiere nur die ersten \(AppGroupConstants.freeContactLimit) Kontakte.")
                }

                let db = try DatabaseManager.openShared()

                var totalEntries = 0
                var processedContacts = 0
                let total = max(contactsToSync.count, 1)
                var syncedKeys: Set<Company.SyncKey> = []

                for (index, contact) in contactsToSync.enumerated() {
                    var anyProcessed = false

                    for rawPhone in contact.phoneNumbers {
                        guard let e164 = PhoneNumberNormalizer.shared.normalize(rawPhone) else {
                            continue
                        }

                        guard NumberClassifier.classify(e164).supportsFuzzyMatch else {
                            continue
                        }

                        let existing = try db.company(
                            contactIdentifier: contact.contactIdentifier,
                            basePhoneE164: e164
                        )

                        let company = Company(
                            id: existing?.id,
                            contactIdentifier: contact.contactIdentifier,
                            organizationName: contact.displayName,
                            basePhoneE164: e164,
                            extensionCount: existing?.extensionCount ?? 100,
                            isEnabled: existing?.isEnabled ?? true,
                            updatedAt: Date()
                        )

                        let companyId = try db.upsertCompany(company)
                        var persisted = company
                        persisted.id = companyId
                        syncedKeys.insert(persisted.syncKey)

                        if persisted.isEnabled {
                            let entries = FuzzyMatchGenerator.generateEntries(for: persisted)
                            try db.replaceEntries(forCompanyId: companyId, with: entries)
                            totalEntries += entries.count
                        } else {
                            try db.replaceEntries(forCompanyId: companyId, with: [])
                        }
                        anyProcessed = true
                    }

                    if anyProcessed {
                        processedContacts += 1
                    }

                    await MainActor.run {
                        self.state = .running(progress: Double(index + 1) / Double(total))
                    }
                }

                try db.deleteCompanies(excluding: syncedKeys)
                return (processedContacts, totalEntries)
            }.value

            let reloadOutcome = await reloadExtensionIfPossible()

            await MainActor.run {
                self.state = .completed(
                    contactCount: syncResult.0,
                    entryCount: syncResult.1,
                    at: Date()
                )
            }
            switch reloadOutcome {
            case .reloaded:
                logger.info("Sync abgeschlossen: \(syncResult.0) Kontakte, \(syncResult.1) Einträge")
            case .skippedExtensionDisabled:
                logger.info("Sync abgeschlossen ohne Extension-Reload, da die Extension noch nicht aktiviert ist.")
            case .skippedStatusUnavailable(let message):
                logger.warning("Sync abgeschlossen ohne Statusprüfung der Extension: \(message)")
            case .skippedReloadFailed(let message):
                logger.warning("Sync abgeschlossen, aber Extension-Reload übersprungen: \(message)")
            }

        } catch {
            logger.error("Sync fehlgeschlagen: \(error.localizedDescription)")
            await MainActor.run {
                self.state = .failed(message: error.localizedDescription)
            }
        }
    }

    private func reloadExtensionIfPossible() async -> ReloadOutcome {
        let status: CXCallDirectoryManager.EnabledStatus
        do {
            status = try await extensionEnabledStatus()
        } catch {
            return .skippedStatusUnavailable(error.localizedDescription)
        }

        guard status == .enabled else {
            return .skippedExtensionDisabled
        }

        do {
            try await reloadExtension()
            return .reloaded
        } catch {
            return .skippedReloadFailed(error.localizedDescription)
        }
    }

    private func reloadExtension() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [extensionBundleID = AppGroupConstants.extensionBundleID] in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    CXCallDirectoryManager.sharedInstance.reloadExtension(
                        withIdentifier: extensionBundleID
                    ) { error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else {
                            cont.resume()
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw SyncError.reloadTimedOut
            }

            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func extensionEnabledStatus() async throws -> CXCallDirectoryManager.EnabledStatus {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CXCallDirectoryManager.EnabledStatus, Error>) in
            CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
                withIdentifier: AppGroupConstants.extensionBundleID
            ) { enabled, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: enabled)
                }
            }
        }
    }

    private enum SyncError: LocalizedError {
        case reloadTimedOut

        var errorDescription: String? {
            switch self {
            case .reloadTimedOut:
                return L10n.tr("sync.error.reload_timeout")
            }
        }
    }
}
