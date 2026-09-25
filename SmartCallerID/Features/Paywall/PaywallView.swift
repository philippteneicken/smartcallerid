import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                featureList

                VStack(spacing: 10) {
                    // Preis & Laufzeit kommen ausschließlich aus StoreKit, damit sie
                    // immer zum Storefront des Nutzers passen (Guideline 3.1.2).
                    if let offerText = subscription.offerText {
                        Text(offerText)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    Text("Jederzeit in den iOS-Einstellungen kündbar. Keine Kündigungsfrist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: startPurchase) {
                        Text(isWorking ? String(localized: "paywall.please_wait") : String(localized: "paywall.start_trial"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isWorking || subscription.product == nil)

                    Button("Kauf wiederherstellen") {
                        Task {
                            isWorking = true
                            switch await subscription.restore() {
                            case .restored:
                                errorMessage = nil
                            case .failed(let message):
                                errorMessage = message
                            }
                            isWorking = false
                        }
                    }
                    .font(.footnote)

                    if let statusMessage = subscription.paywallStatusMessage, subscription.product == nil {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button(String(localized: "paywall.reload")) {
                            Task {
                                isWorking = true
                                await subscription.loadProduct()
                                isWorking = false
                            }
                        }
                        .font(.footnote)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    legalLinks
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            if subscription.product == nil && !subscription.isLoading {
                await subscription.loadProduct()
            }
        }
        .onChange(of: subscription.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color(red: 0, green: 0.78, blue: 0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                Image(systemName: "phone.badge.waveform")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("SmartCallerID Pro")
                .font(.largeTitle.bold())

            Text("Erkenne unbekannte Firmennummern und ihre Durchwahlen direkt beim Klingeln.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link(String(localized: "legal.privacy_policy"), destination: LegalLinks.privacyPolicy)
            Link(String(localized: "legal.terms_of_use"), destination: LegalLinks.termsOfUse)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature(
                icon: "checkmark.seal.fill",
                title: L10n.tr("paywall.feature.contacts.title", SubscriptionManager.freeContactLimit),
                subtitle: L10n.tr("paywall.feature.contacts.subtitle")
            )
            feature(
                icon: "lock.shield.fill",
                title: L10n.tr("paywall.feature.local.title"),
                subtitle: L10n.tr("paywall.feature.local.subtitle")
            )
            feature(
                icon: "arrow.clockwise.circle.fill",
                title: L10n.tr("paywall.feature.fresh.title"),
                subtitle: L10n.tr("paywall.feature.fresh.subtitle")
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func feature(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func startPurchase() {
        errorMessage = nil
        isWorking = true
        Task {
            let result = await subscription.purchase()
            isWorking = false
            switch result {
            case .success:
                dismiss()
            case .userCancelled:
                break
            case .pending:
                errorMessage = String(localized: "subscription.error.pending")
            case .failed(let message):
                errorMessage = message
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
