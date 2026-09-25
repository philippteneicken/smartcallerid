import Foundation

/// Zentrale Konstanten für die App Group, die zwischen Hauptapp und Extension geteilt wird.
enum AppGroupConstants {
    static let identifier = "group.de.cleangas.smartcallerid"
    static let extensionBundleID = "de.cleangas.smartcallerid.calldirectory"
    static let databaseFileName = "entries.sqlite"

    /// URL des geteilten App-Group-Containers.
    static var sharedContainerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group \(identifier) ist nicht konfiguriert. Prüfe Capabilities in Xcode.")
        }
        return url
    }

    /// Vollständiger Pfad zur geteilten SQLite-Datenbank.
    static var databaseURL: URL {
        sharedContainerURL.appendingPathComponent(databaseFileName)
    }
}
