import Foundation
import CallKit
import Observation
import os.log
import UIKit

@Observable
@MainActor
final class ExtensionStatusChecker {

    enum Status: Equatable {
        case unknown
        case enabled
        case disabled
        case error(String)

        var displayText: String {
            switch self {
            case .unknown: return L10n.tr("status.unknown")
            case .enabled: return L10n.tr("status.enabled")
            case .disabled: return L10n.tr("status.disabled")
            case .error(let message): return L10n.tr("status.error", message)
            }
        }

        var isEnabled: Bool {
            if case .enabled = self { return true }
            return false
        }
    }

    private(set) var status: Status = .unknown

    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "ExtensionStatusChecker")

    func openSettings() async {
        await withCheckedContinuation { continuation in
            CXCallDirectoryManager.sharedInstance.openSettings(completionHandler: { error in
                if let error {
                    self.logger.error("Call Directory Einstellungen konnten nicht direkt geöffnet werden: \(error.localizedDescription)")
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                continuation.resume()
            })
        }
    }

    func refresh() async {
        let result: Result<CXCallDirectoryManager.EnabledStatus, Error> = await withCheckedContinuation { cont in
            CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
                withIdentifier: AppGroupConstants.extensionBundleID
            ) { enabled, error in
                if let error = error {
                    cont.resume(returning: .failure(error))
                } else {
                    cont.resume(returning: .success(enabled))
                }
            }
        }

        switch result {
        case .failure(let error):
            logger.error("Extension-Status-Abfrage fehlgeschlagen: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
        case .success(let enabled):
            switch enabled {
            case .enabled: status = .enabled
            case .disabled: status = .disabled
            case .unknown: status = .unknown
            @unknown default: status = .unknown
            }
        }
    }
}
