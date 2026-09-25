import Foundation
import StoreKit
import Observation
import os.log

@Observable
@MainActor
final class SubscriptionManager {

    /// Muss identisch zum Produkt in App Store Connect (und in Products.storekit) sein.
    static let monthlyProductID = "de.cleangas.smartcallerid.pro.monthly"
    static let freeContactLimit = AppGroupConstants.freeContactLimit

    enum PurchaseResult: Equatable {
        case success
        case userCancelled
        case pending
        case failed(message: String)
    }

    enum RestoreResult: Equatable {
        case restored
        case failed(message: String)
    }

    private(set) var product: Product?
    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var loadError: String?

    private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "Subscription")

    func bootstrap() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(transactionResult: update)
                }
            }
        }
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            product = products.first(where: { $0.id == Self.monthlyProductID }) ?? products.first
            if product == nil {
                loadError = Self.unavailableProductMessage
                logger.warning("Produkt \(Self.monthlyProductID) nicht gefunden.")
            } else {
                loadError = nil
            }
        } catch {
            loadError = L10n.tr("subscription.error.load", error.localizedDescription)
            logger.error("Produkt-Load fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                active = true
            }
        }
        isPro = active
        AppGroupConstants.setProAccessUnlocked(active)
    }

    func purchase() async -> PurchaseResult {
        if product == nil {
            await loadProduct()
        }

        guard let product else {
            return .failed(message: loadError ?? L10n.tr("subscription.error.not_loaded"))
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return .success
                case .unverified(_, let error):
                    logger.error("Transaktion unverified: \(error.localizedDescription)")
                    return .failed(message: L10n.tr("subscription.error.unverified"))
                }
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(message: L10n.tr("subscription.error.unknown_result"))
            }
        } catch {
            logger.error("Kauf fehlgeschlagen: \(error.localizedDescription)")
            return .failed(message: error.localizedDescription)
        }
    }

    func restore() async -> RestoreResult {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return .restored
        } catch {
            logger.error("Restore fehlgeschlagen: \(error.localizedDescription)")
            return .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Display helpers

    var priceText: String? {
        product?.displayPrice
    }

    /// "14 Tage kostenlos, danach 0,99 €/Monat" o.ä., aus App-Store-Metadaten abgeleitet.
    var offerText: String? {
        guard let product else { return nil }
        guard let subscription = product.subscription else { return product.displayPrice }
        guard let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial else {
            return L10n.tr("subscription.offer.standard", product.displayPrice, periodText(subscription.subscriptionPeriod))
        }
        let trial = periodText(intro.period)
        return L10n.tr("subscription.offer.trial", trial, product.displayPrice, periodText(subscription.subscriptionPeriod))
    }

    var paywallStatusMessage: String? {
        if let loadError { return loadError }
        if product == nil {
            return Self.unavailableProductMessage
        }
        return nil
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day:   unit = period.value == 1 ? L10n.tr("period.day.one") : L10n.tr("period.day.other")
        case .week:  unit = period.value == 1 ? L10n.tr("period.week.one") : L10n.tr("period.week.other")
        case .month: unit = period.value == 1 ? L10n.tr("period.month.one") : L10n.tr("period.month.other")
        case .year:  unit = period.value == 1 ? L10n.tr("period.year.one") : L10n.tr("period.year.other")
        @unknown default: unit = ""
        }
        return L10n.tr("period.format", period.value, unit)
    }

    // MARK: - Private

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = transactionResult {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    private static let unavailableProductMessage =
        L10n.tr("subscription.error.unavailable")
}
