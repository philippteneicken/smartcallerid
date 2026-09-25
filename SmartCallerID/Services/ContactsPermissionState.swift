import Foundation
import Contacts
import Observation
import os.log

@Observable
@MainActor
final class ContactsPermissionState {
    enum Status: Equatable {
        case unknown
        case notDetermined
        case denied
        case restricted
        case authorized
        case limited

        var isUsable: Bool {
            self == .authorized || self == .limited
        }
    }

    private(set) var status: Status = .unknown
    private let store = CNContactStore()
    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "ContactsPermission")

    /// Liest nur den aktuellen Status. Die eigentliche Permission-Abfrage passiert
    /// bewusst NICHT beim App-Start, sondern erst, wenn der Nutzer im Setup-Schritt
    /// auf „Zugriff erlauben“ tippt (App-Review-Guideline 5.1.1: Abfrage im Kontext).
    func bootstrap() async {
        refreshFromSystem()
    }

    func refresh() {
        refreshFromSystem()
    }

    @discardableResult
    func requestAccessIfNeeded() async -> Bool {
        if status.isUsable { return true }
        if status == .denied || status == .restricted { return false }

        do {
            let granted = try await store.requestAccess(for: .contacts)
            refreshFromSystem()
            return granted
        } catch {
            logger.error("Kontakt-Zugriff fehlgeschlagen: \(error.localizedDescription)")
            refreshFromSystem()
            return false
        }
    }

    private func refreshFromSystem() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: status = .notDetermined
        case .restricted:    status = .restricted
        case .denied:        status = .denied
        case .authorized:    status = .authorized
        case .limited:       status = .limited
        @unknown default:    status = .unknown
        }
    }
}
