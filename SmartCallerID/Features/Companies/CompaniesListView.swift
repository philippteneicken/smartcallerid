import SwiftUI
import os.log

struct CompaniesListView: View {
    @State private var companies: [Company] = []
    @State private var entryCountsByCompany: [Int64: Int] = [:]
    @State private var loadError: String?

    private let logger = Logger(subsystem: "de.cleangas.smartcallerid", category: "CompaniesListView")

    var body: some View {
        NavigationStack {
            Group {
                if companies.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Arbeit-Nummern",
                        systemImage: "person.crop.circle.badge.phone",
                        description: Text("Lege in deinen normalen Kontakten Telefonnummern mit dem Label „Arbeit“ an und synchronisiere dann in der Übersicht.")
                    )
                } else {
                    List(companies) { company in
                        NavigationLink(value: company) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(company.organizationName)
                                    .font(.headline)
                                Text(company.basePhoneE164)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let id = company.id {
                                    Text(L10n.tr("company.entry_count", entryCountsByCompany[id] ?? 0))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: Company.self) { company in
                        CompanyDetailView(company: company)
                    }
                }
            }
            .navigationTitle("Kontakte")
            .task { await load() }
            .refreshable { await load() }
            .overlay(alignment: .bottom) {
                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
        }
    }

    private func load() async {
        do {
            let db = try DatabaseManager.openShared()
            let loaded = try db.allCompanies()
            var counts: [Int64: Int] = [:]
            for c in loaded {
                if let id = c.id {
                    counts[id] = try db.entryCount(forCompanyId: id)
                }
            }
            companies = loaded
            entryCountsByCompany = counts
            loadError = nil
        } catch {
            logger.error("Laden fehlgeschlagen: \(error.localizedDescription)")
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    CompaniesListView()
}
