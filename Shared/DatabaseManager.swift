import Foundation
import GRDB

final class DatabaseManager {

    private let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

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

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "companies") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contactIdentifier", .text).notNull()
                t.column("organizationName", .text).notNull()
                t.column("basePhoneE164", .text).notNull()
                t.column("extensionCount", .integer).notNull().defaults(to: 100)
                t.column("isEnabled", .integer).notNull().defaults(to: 1)
                t.column("updatedAt", .datetime).notNull()
                t.uniqueKey(["contactIdentifier", "basePhoneE164"])
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

    // MARK: - Companies

    @discardableResult
    func upsertCompany(_ companyRecord: Company) throws -> Int64 {
        try dbQueue.write { db in
            if let existing = try company(
                contactIdentifier: companyRecord.contactIdentifier,
                basePhoneE164: companyRecord.basePhoneE164,
                db: db
            ) {
                var updated = companyRecord
                updated.id = existing.id
                try updated.update(db)
                return existing.id ?? -1
            } else {
                var inserted = companyRecord
                try inserted.insert(db)
                return inserted.id ?? -1
            }
        }
    }

    func company(contactIdentifier: String, basePhoneE164: String) throws -> Company? {
        try dbQueue.read { db in
            try company(contactIdentifier: contactIdentifier, basePhoneE164: basePhoneE164, db: db)
        }
    }

    func allCompanies() throws -> [Company] {
        try dbQueue.read { db in
            try Company
                .order(Company.Columns.organizationName)
                .fetchAll(db)
        }
    }

    func deleteCompany(id: Int64) throws {
        _ = try dbQueue.write { db in
            try Company.deleteOne(db, key: id)
        }
    }

    func deleteCompanies(excluding keys: Set<Company.SyncKey>) throws {
        try dbQueue.write { db in
            let all = try Company.fetchAll(db)
            for company in all where !keys.contains(company.syncKey) {
                if let id = company.id {
                    try Company.deleteOne(db, key: id)
                }
            }
        }
    }

    func setCompanyEnabled(id: Int64, enabled: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE companies SET isEnabled = ? WHERE id = ?",
                arguments: [enabled ? 1 : 0, id]
            )
            if !enabled {
                try db.execute(
                    sql: "DELETE FROM entries WHERE company_id = ?",
                    arguments: [id]
                )
            }
        }
    }

    // MARK: - Entries

    func replaceEntries(forCompanyId companyId: Int64, with entries: [DirectoryEntry]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM entries WHERE company_id = ?", arguments: [companyId])
            for entry in entries {
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO entries (e164, phone_number, label, company_id)
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

    func entryCount(forCompanyId companyId: Int64) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM entries WHERE company_id = ?",
                arguments: [companyId]
            ) ?? 0
        }
    }

    func companyCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companies") ?? 0
        }
    }

    private func company(contactIdentifier: String, basePhoneE164: String, db: Database) throws -> Company? {
        try Company
            .filter(
                Company.Columns.contactIdentifier == contactIdentifier
                && Company.Columns.basePhoneE164 == basePhoneE164
            )
            .fetchOne(db)
    }

    // MARK: - Streaming für Extension

    func streamIdentificationEntries(
        batchSize: Int,
        maxContactCount: Int? = nil,
        handler: ([DirectoryEntry]) -> Void
    ) throws {
        try dbQueue.read { db in
            let sql: String
            let arguments: StatementArguments

            if let maxContactCount {
                sql = """
                    SELECT e.e164, e.phone_number, e.label
                    FROM entries e
                    JOIN companies c ON c.id = e.company_id
                    WHERE c.contactIdentifier IN (
                        SELECT c2.contactIdentifier
                        FROM companies c2
                        GROUP BY c2.contactIdentifier
                        ORDER BY MIN(c2.organizationName) COLLATE NOCASE ASC, c2.contactIdentifier ASC
                        LIMIT ?
                    )
                    ORDER BY e.phone_number ASC
                """
                arguments = [maxContactCount]
            } else {
                sql = "SELECT e164, phone_number, label FROM entries ORDER BY phone_number ASC"
                arguments = []
            }

            let cursor = try Row.fetchCursor(db, sql: sql, arguments: arguments)

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
