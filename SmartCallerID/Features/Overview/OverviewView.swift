import SwiftUI
import UIKit
import os.log

struct OverviewView: View {
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(ExtensionStatusChecker.self) private var extensionStatus
    @Environment(ContactsPermissionState.self) private var contactsPermission
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.scenePhase) private var scenePhase

    @State private var companyCount: Int = 0
    @State private var entryCount: Int = 0
    @State private var lastSync: Date?
    @State private var showPaywall = false

    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "OverviewView")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    uniquenessCard

                    if allStepsReady {
                        statsCard
                        syncButton
                    } else {
                        setupSteps
                    }

                    if case .failed(let message) = syncCoordinator.state {
                        errorBanner(message)
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SmartCallerID")
            .navigationBarTitleDisplayMode(.large)
            .task { await refreshStats() }
            .onChange(of: syncCoordinator.state) { _, newValue in
                if case .completed = newValue {
                    Task {
                        await refreshStats()
                        await extensionStatus.refresh()
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    contactsPermission.refresh()
                    Task {
                        await extensionStatus.refresh()
                        await subscription.refreshEntitlements()
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: heroGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)
                Image(systemName: heroSymbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text(heroTitle)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private var heroGradient: [Color] {
        allStepsReady
            ? [Color.green, Color(red: 0, green: 0.78, blue: 0.55)]
            : [Color.accentColor, Color(red: 0, green: 0.78, blue: 0.75)]
    }

    private var heroSymbol: String {
        allStepsReady ? "checkmark" : "phone.badge.waveform"
    }

    private var heroTitle: String {
        allStepsReady ? L10n.tr("Alles bereit") : L10n.tr("Kurze Einrichtung nötig")
    }

    private var heroSubtitle: String {
        if allStepsReady {
            if subscription.isPro {
                return L10n.tr("overview.hero.subtitle.pro")
            }
            return L10n.tr("overview.hero.subtitle.free", SubscriptionManager.freeContactLimit)
        } else {
            return L10n.tr(
                incompleteSteps == 1 ? "overview.hero.subtitle.setup.one" : "overview.hero.subtitle.setup.other",
                incompleteSteps
            )
        }
    }

    // MARK: - Steps

    private var setupSteps: some View {
        VStack(spacing: 12) {
            StepCard(
                number: 1,
                title: L10n.tr("Kontakte freigeben"),
                description: contactsDescription,
                state: contactsStepState,
                actionTitle: contactsActionTitle,
                action: handleContactsAction
            )

            StepCard(
                number: 2,
                title: L10n.tr("In iOS-Einstellungen aktivieren"),
                description: L10n.tr("Tippe unten auf „Einstellungen öffnen“ und navigiere zu **Telefon → Anrufblockierung & Identifizierung → SmartCallerID aktivieren**."),
                state: extensionStepState,
                actionTitle: L10n.tr("action.open_settings"),
                action: openAppSettings
            )

            if !subscription.isPro {
                upgradeCard
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        VStack(spacing: 0) {
            statsRow(label: L10n.tr("Überwachte Kontakte"), value: "\(companyCount)")
            Divider().padding(.leading, 16)
            statsRow(label: L10n.tr("Generierte Einträge"), value: "\(entryCount)")
            if let lastSync {
                Divider().padding(.leading, 16)
                statsRow(label: L10n.tr("Letzter Sync"), value: Self.relativeFormatter.localizedString(for: lastSync, relativeTo: Date()))
            }
            if !subscription.isPro {
                Divider().padding(.leading, 16)
                Text(L10n.tr("overview.free_limit.note", SubscriptionManager.freeContactLimit))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var uniquenessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("overview.unique.title"))
                .font(.headline)

            uniquenessRow(
                icon: "person.crop.circle.badge.checkmark",
                title: L10n.tr("overview.unique.contacts.title"),
                subtitle: L10n.tr("overview.unique.contacts.subtitle")
            )
            uniquenessRow(
                icon: "point.3.connected.trianglepath.dotted",
                title: L10n.tr("overview.unique.extensions.title"),
                subtitle: L10n.tr("overview.unique.extensions.subtitle")
            )
            uniquenessRow(
                icon: "lock.shield",
                title: L10n.tr("overview.unique.local.title"),
                subtitle: L10n.tr("overview.unique.local.subtitle")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func uniquenessRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Sync button

    private var syncButton: some View {
        Button(action: runSync) {
            Group {
                if case .running(let progress) = syncCoordinator.state {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("\(Int(progress * 100)) %")
                    }
                } else {
                    Label("Jetzt synchronisieren", systemImage: "arrow.clockwise")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isRunning)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync fehlgeschlagen").font(.subheadline.weight(.semibold))
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var upgradeCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("overview.upgrade.title", SubscriptionManager.freeContactLimit))
                    .font(.headline)
                Text(subscriptionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "paywall.start_trial")) {
                    showPaywall = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Step state

    private var contactsStepState: StepCard.State {
        if contactsPermission.status.isUsable { return .done }
        if contactsPermission.status == .denied || contactsPermission.status == .restricted {
            return .actionRequired
        }
        return .inProgress
    }

    private var contactsActionTitle: String {
        switch contactsPermission.status {
        case .denied, .restricted: return L10n.tr("action.open_settings")
        default: return L10n.tr("action.allow_access")
        }
    }

    private var contactsDescription: String {
        switch contactsPermission.status {
        case .authorized, .limited:
            return L10n.tr("overview.contacts.authorized")
        case .denied, .restricted:
            return L10n.tr("overview.contacts.denied")
        default:
            return L10n.tr("overview.contacts.unknown")
        }
    }

    private var subscriptionDescription: String {
        if subscription.isPro { return L10n.tr("overview.subscription.active") }
        let offer = subscription.offerText ?? L10n.tr("overview.subscription.default_offer")
        return L10n.tr("overview.subscription.free", SubscriptionManager.freeContactLimit, offer)
    }

    private var extensionStepState: StepCard.State {
        extensionStatus.status.isEnabled ? .done : .actionRequired
    }

    private var allStepsReady: Bool {
        contactsStepState == .done &&
        extensionStepState == .done
    }

    private var incompleteSteps: Int {
        [contactsStepState, extensionStepState]
            .filter { $0 != .done }
            .count
    }

    // MARK: - Actions

    private func handleContactsAction() {
        switch contactsPermission.status {
        case .denied, .restricted:
            openAppSettings()
        default:
            Task { await contactsPermission.requestAccessIfNeeded() }
        }
    }

    private func openAppSettings() {
        Task {
            await extensionStatus.openSettings()
        }
    }

    private var isRunning: Bool {
        if case .running = syncCoordinator.state { return true }
        return false
    }

    private func runSync() {
        Task { await syncCoordinator.runSync() }
    }

    private func refreshStats() async {
        do {
            let db = try DatabaseManager.openShared()
            companyCount = try db.companyCount()
            entryCount = try db.entryCount()
            if case .completed(_, _, let at) = syncCoordinator.state {
                lastSync = at
            }
        } catch {
            logger.error("Stats-Refresh fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}

// MARK: - StepCard

private struct StepCard: View {
    enum State: Equatable { case done, inProgress, actionRequired }

    let number: Int
    let title: String
    let description: String
    let state: State
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            indicator
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(.init(description))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state != .done {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(state == .done ? Color.green.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .done:
            ZStack {
                Circle().fill(Color.green)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .inProgress:
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.18))
                ProgressView()
                    .controlSize(.small)
            }
        case .actionRequired:
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Text("\(number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

#Preview {
    OverviewView()
        .environment(SyncCoordinator())
        .environment(ExtensionStatusChecker())
        .environment(ContactsPermissionState())
        .environment(SubscriptionManager())
}
