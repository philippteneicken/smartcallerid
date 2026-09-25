import Foundation
import CallKit
import os.log

class CallDirectoryHandler: CXCallDirectoryProvider {

    private let logger = Logger(
        subsystem: "de.cleangas.smartcallerid.calldirectory",
        category: "CallDirectoryHandler"
    )

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        logger.info("beginRequest gestartet, isIncremental=\(context.isIncremental)")

        do {
            let db = try DatabaseManager.openShared(readOnly: true)
            let maxContactCount = AppGroupConstants.isProAccessUnlocked
                ? nil
                : AppGroupConstants.freeContactLimit

            // Bei inkrementellen Requests kennt iOS bereits die zuletzt gelieferten
            // Einträge. Da wir immer den kompletten Datenbestand streamen, müssen die
            // alten Einträge erst entfernt werden — sonst wirft addIdentificationEntry
            // wegen Duplikaten und der Reload schlägt ab dem zweiten Mal fehl.
            if context.isIncremental {
                logger.notice("Incremental request — entferne alte Einträge und liefere den vollen Bestand neu")
                context.removeAllIdentificationEntries()
            }

            var totalCount = 0

            try db.streamIdentificationEntries(batchSize: 5_000, maxContactCount: maxContactCount) { batch in
                autoreleasepool {
                    for entry in batch {
                        context.addIdentificationEntry(
                            withNextSequentialPhoneNumber: entry.phoneNumber,
                            label: entry.label
                        )
                        totalCount += 1
                    }
                }
            }

            if maxContactCount != nil {
                logger.info("Basisversion aktiv — liefere Einträge für maximal \(AppGroupConstants.freeContactLimit) Kontakte aus.")
            }
            logger.info("Identification entries hinzugefügt: \(totalCount)")
            context.completeRequest()

        } catch {
            logger.error("Fehler in beginRequest: \(error.localizedDescription)")
            context.cancelRequest(withError: error)
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(
        for extensionContext: CXCallDirectoryExtensionContext,
        withError error: Error
    ) {
        logger.error("Extension request failed: \(error.localizedDescription)")
    }
}
