import Foundation
import GRDB

/// Geteilter SQLite-Manager. Wird sowohl von Hauptapp (read/write) als auch
/// Extension (read-only) verwendet.
///
/// Datenbank liegt im App-Group-Container, damit beide Targets darauf zugreifen können.
final class DatabaseManager {

    private let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Factory

    /// Öffnet die geteilte DB. `readOnly: true` für die Extension.
    static func openShared(readOnly: Bool = false) throws -> DatabaseManager {
        let url = AppGroupConstants.databaseURL

        var config = Configuration()
        config.readonly = readOnly

        let queue = try DatabaseQueue(path: url.path, configuration: config)

        let manager = DatabaseManager(dbQueue: queue)
        if !readOnly {
            try manager.migrate()
        }
        return manager
    }

    // MARK: - Migrations

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "companies") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contact_identifier", .text).notNull().unique()
                t.column("organization_name", .text).notNull()
                t.column("base_phone_e164", .text).notNull()
                t.column("extension_count", .integer).notNull().defaults(to: 100)
                t.column("is_enabled", .integer).notNull().defaults(to: 1)
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("e164", .text).notNull().unique()
                t.column("phone_number", .integer).notNull()
                t.column("label", .text).notNull()
                t.column("company_id", .integer).notNull()
                    .references("companies", onDelete: .cascade)
            }

            try db.create(index: "idx_entries_phone_number", on: "entries", columns: ["phone_number"])
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Companies CRUD

    func upsertCompany(_ company: Company) throws -> Int64 {
        try dbQueue.write { db in
            // ... (Implementation: INSERT OR REPLACE, return rowid)
            // TODO: Claude Code soll dies vervollständigen
            fatalError("Not implemented yet")
        }
    }

    func allCompanies() throws -> [Company] {
        try dbQueue.read { db in
            // TODO
            fatalError("Not implemented yet")
        }
    }

    // MARK: - Entries

    func replaceEntries(forCompanyId companyId: Int64, with entries: [DirectoryEntry]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM entries WHERE company_id = ?", arguments: [companyId])
            for entry in entries {
                try db.execute(
                    sql: """
                        INSERT OR REPLACE INTO entries (e164, phone_number, label, company_id)
                        VALUES (?, ?, ?, ?)
                    """,
                    arguments: [entry.e164, entry.phoneNumber, entry.label, companyId]
                )
            }
        }
    }

    func entryCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM entries") ?? 0
        }
    }

    // MARK: - Streaming für Extension

    /// Streamt Einträge in Batches, aufsteigend sortiert nach phone_number.
    /// WICHTIG: Sortierung ist Pflicht für CallKit.
    func streamIdentificationEntries(
        batchSize: Int,
        handler: ([DirectoryEntry]) -> Void
    ) throws {
        try dbQueue.read { db in
            let cursor = try Row.fetchCursor(
                db,
                sql: "SELECT e164, phone_number, label FROM entries ORDER BY phone_number ASC"
            )

            var batch: [DirectoryEntry] = []
            batch.reserveCapacity(batchSize)

            while let row = try cursor.next() {
                let entry = DirectoryEntry(
                    e164: row["e164"],
                    phoneNumber: row["phone_number"],
                    label: row["label"]
                )
                batch.append(entry)

                if batch.count >= batchSize {
                    handler(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }

            if !batch.isEmpty {
                handler(batch)
            }
        }
    }
}
