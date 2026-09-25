import SwiftUI
import os.log

struct CompanyDetailView: View {
    let company: Company

    @State private var extensionCount: Int
    @State private var isEnabled: Bool
    @State private var entryCount: Int = 0
    @State private var sampleEntries: [DirectoryEntry] = []
    @State private var strategy: FuzzyMatchGenerator.StrategyExplanation?
    @State private var isDirty = false

    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "CompanyDetailView")
    private let availableCounts = [10, 100, 1000]

    init(company: Company) {
        self.company = company
        _extensionCount = State(initialValue: company.extensionCount)
        _isEnabled = State(initialValue: company.isEnabled)
    }

    var body: some View {
        Form {
            Section("Stamm-Nummer") {
                Text(company.basePhoneE164)
                    .font(.system(.body, design: .monospaced))
            }

            Section("Fuzzy-Match") {
                Toggle("Für diesen Kontakt aktiv", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, _ in isDirty = true }

                Picker("Durchwahl-Anzahl", selection: $extensionCount) {
                    ForEach(availableCounts, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .onChange(of: extensionCount) { _, _ in isDirty = true }

                LabeledContent("Aktuelle Einträge") {
                    Text("\(entryCount)").monospacedDigit()
                }
            }

            if let strategy {
                Section(L10n.tr("company.logic.section")) {
                    LabeledContent(L10n.tr("company.logic.source")) {
                        Text(L10n.tr("company.logic.source_value"))
                    }
                    LabeledContent(L10n.tr("company.logic.method")) {
                        Text(
                            strategy.usesTrailingZeros
                            ? L10n.tr("company.logic.method.trailing_zeros")
                            : L10n.tr("company.logic.method.fallback")
                        )
                    }
                    LabeledContent(L10n.tr("company.logic.range")) {
                        Text("\(strategy.firstExtension) – \(strategy.lastExtension)")
                            .monospacedDigit()
                    }
                    Text(L10n.tr("company.logic.footer"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !sampleEntries.isEmpty {
                Section("Beispiel-Einträge") {
                    ForEach(sampleEntries.prefix(5), id: \.e164) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.e164)
                                .font(.system(.footnote, design: .monospaced))
                            Text(entry.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isDirty {
                Section {
                    Button("Änderungen speichern", action: save)
                }
            }
        }
        .navigationTitle(company.organizationName)
        .task { await load() }
    }

    private func load() async {
        guard let id = company.id else { return }
        do {
            let db = try DatabaseManager.openShared()
            entryCount = try db.entryCount(forCompanyId: id)
            sampleEntries = FuzzyMatchGenerator.generateEntries(for: company)
            strategy = FuzzyMatchGenerator.strategyExplanation(for: company)
        } catch {
            logger.error("Detail-Load fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func save() {
        guard let id = company.id else { return }
        do {
            let db = try DatabaseManager.openShared()
            try db.setCompanyEnabled(id: id, enabled: isEnabled)

            var updated = company
            updated.extensionCount = extensionCount
            updated.isEnabled = isEnabled
            updated.updatedAt = Date()
            _ = try db.upsertCompany(updated)

            if isEnabled {
                let entries = FuzzyMatchGenerator.generateEntries(for: updated)
                try db.replaceEntries(forCompanyId: id, with: entries)
                entryCount = entries.count
                strategy = FuzzyMatchGenerator.strategyExplanation(for: updated)
            } else {
                entryCount = 0
            }
            isDirty = false
        } catch {
            logger.error("Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}
