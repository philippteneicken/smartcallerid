import SwiftUI
import os.log

@main
struct SmartCallerIDApp: App {

    @State private var syncCoordinator = SyncCoordinator()
    @State private var extensionStatus = ExtensionStatusChecker()
    @State private var contactsPermission = ContactsPermissionState()
    @State private var subscription = SubscriptionManager()

    init() {
        do {
            _ = try DatabaseManager.openShared()
        } catch {
            Logger(subsystem: "de.cleangas.smartcallerid", category: "App")
                .error("DB-Init fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(syncCoordinator)
                .environment(extensionStatus)
                .environment(contactsPermission)
                .environment(subscription)
                .task {
                    await contactsPermission.bootstrap()
                    await extensionStatus.refresh()
                    await subscription.bootstrap()
                }
        }
    }
}
