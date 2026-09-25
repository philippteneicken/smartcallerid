import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Übersicht", systemImage: "chart.bar.fill")
                }

            CompaniesListView()
                .tabItem {
                    Label("Kontakte", systemImage: "person.2.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(SyncCoordinator())
        .environment(ExtensionStatusChecker())
        .environment(ContactsPermissionState())
        .environment(SubscriptionManager())
}
