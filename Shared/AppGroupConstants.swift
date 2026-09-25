import Foundation
import os.log

enum AppGroupConstants {
    static let identifier = "group.de.cleangas.smartcallerid"
    static let extensionBundleID = "de.cleangas.smartcallerid.calldirectory"
    static let databaseFileName = "entries.sqlite"
    static let freeContactLimit = 10
    static let proAccessKey = "proAccessUnlocked"

    private static let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "AppGroup")

    /// Container-URL der App-Group, falls verfügbar — sonst ein lokaler Fallback im
    /// Application-Support-Verzeichnis. Der Fallback erlaubt Dev-Builds im Simulator
    /// ohne Provisioning-Profile und greift auch in Unit-Tests. Auf echten Geräten
    /// mit aktivierter App-Group-Capability wird immer der geteilte Container genutzt.
    static var sharedContainerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) {
            return url
        }

        logger.warning("App Group \(identifier) nicht verfügbar — nutze lokalen Fallback. Auf echten Geräten Capabilities prüfen.")

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(identifier, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var databaseURL: URL {
        sharedContainerURL.appendingPathComponent(databaseFileName)
    }

    static var sharedDefaults: UserDefaults {
        if let defaults = UserDefaults(suiteName: identifier) {
            return defaults
        }

        logger.warning("UserDefaults für App Group \(identifier) nicht verfügbar — nutze .standard als Fallback.")
        return .standard
    }

    static var isProAccessUnlocked: Bool {
        sharedDefaults.bool(forKey: proAccessKey)
    }

    static func setProAccessUnlocked(_ unlocked: Bool) {
        let defaults = sharedDefaults
        defaults.set(unlocked, forKey: proAccessKey)
        defaults.synchronize()
    }
}
