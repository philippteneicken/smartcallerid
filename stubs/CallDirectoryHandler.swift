import Foundation
import CallKit
import os.log

/// Call Directory Extension Provider.
///
/// iOS ruft `beginRequest(with:)` auf, sobald die Extension neu geladen wird
/// (entweder durch System oder durch unseren `reloadExtension`-Aufruf aus der Hauptapp).
///
/// WICHTIG:
/// - Memory-Limit: ~12 MB. Niemals alle Einträge auf einmal in den Speicher laden.
/// - Einträge MÜSSEN aufsteigend sortiert nach phoneNumber (Int64) übergeben werden.
///   Sonst wirft `addIdentificationEntry` eine Exception.
class CallDirectoryHandler: CXCallDirectoryProvider {

    private let logger = Logger(
        subsystem: "de.cleangas.smartcallerid.calldirectory",
        category: "CallDirectoryHandler"
    )

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        logger.info("beginRequest gestartet, isIncremental=\(context.isIncremental)")

        do {
            // Read-only Zugriff auf die geteilte SQLite-DB
            let db = try DatabaseManager.openShared(readOnly: true)

            if context.isIncremental {
                // Inkrementelles Update: TODO Phase 2 — vorerst nicht unterstützt
                // Bei isIncremental=false werden alle Einträge neu geladen.
                logger.warning("Incremental request — fallback auf full reload")
            }

            var totalCount = 0

            // Streamen in Batches, sortiert nach phoneNumber aufsteigend
            try db.streamIdentificationEntries(batchSize: 5_000) { batch in
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
