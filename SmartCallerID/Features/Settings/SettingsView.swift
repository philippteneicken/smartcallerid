import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(ExtensionStatusChecker.self) private var extensionStatus
    @Environment(SubscriptionManager.self) private var subscription
    @State private var showPaywall = false
    @State private var showTechnicalInfo = false

    private let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection

                Section("Call Directory Extension") {
                    LabeledContent("Status") {
                        Text(extensionStatus.status.displayText)
                            .foregroundStyle(extensionStatus.status.isEnabled ? .green : .orange)
                    }
                    Button("Einstellungen öffnen", systemImage: "arrow.up.right.square") {
                        Task {
                            await extensionStatus.openSettings()
                        }
                    }
                    Button("Status aktualisieren") {
                        Task { await extensionStatus.refresh() }
                    }
                }

                Section("Datenschutz") {
                    Text("Es werden nur Telefonnummern aus deinen Kontakten mit dem Label „Arbeit“ ausgewertet. Die Verarbeitung erfolgt ausschließlich lokal auf diesem Gerät – keine Cloud, keine Weitergabe.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(String(localized: "legal.privacy_policy"), destination: LegalLinks.privacyPolicy)
                    Link(String(localized: "legal.terms_of_use"), destination: LegalLinks.termsOfUse)
                }

                Section("Info") {
                    DisclosureGroup("Technische Details", isExpanded: $showTechnicalInfo) {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("App Group", value: AppGroupConstants.identifier)
                            LabeledContent("Extension", value: AppGroupConstants.extensionBundleID)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showPaywall) {
                PaywallView().presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        Section("SmartCallerID Pro") {
            if subscription.isPro {
                LabeledContent("Status") {
                    Text("aktiv").foregroundStyle(.green)
                }
                Link("Abo verwalten", destination: manageSubscriptionURL)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("settings.subscription.free_tier", SubscriptionManager.freeContactLimit))
                        .font(.subheadline.weight(.semibold))
                    if let offerText = subscription.offerText {
                        Text(offerText)
                            .font(.subheadline)
                    }
                    Text("Jederzeit kündbar in den iOS-Einstellungen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let message = subscription.paywallStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Abo starten") { showPaywall = true }
                Button("Kauf wiederherstellen") {
                    Task { _ = await subscription.restore() }
                }
                .font(.footnote)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(ExtensionStatusChecker())
        .environment(SubscriptionManager())
}
