import Foundation

/// Generiert wahrscheinliche Durchwahl-Nummern für eine Firma.
///
/// Heuristik siehe `docs/FUZZY_LOGIC.md`.
enum FuzzyMatchGenerator {

    /// Maximale Label-Länge (iOS-Limit ist ungefähr 70 Zeichen, wir bleiben defensiv).
    static let maxLabelLength = 60

    /// Erzeugt DirectoryEntries für eine gegebene Company.
    /// Gibt leere Liste zurück, wenn die Stamm-Nummer keine Festnetznummer ist.
    static func generateEntries(for company: Company) -> [DirectoryEntry] {
        let category = NumberClassifier.classify(company.basePhoneE164)
        guard category.supportsFuzzyMatch else { return [] }

        let label = makeLabel(for: company.organizationName)
        let baseE164 = company.basePhoneE164  // z.B. "+4956329699970"

        // Heuristik A: Nummer endet auf "0", "00" oder "000"
        let trailingZeros = countTrailingZeros(in: baseE164, max: 3)

        let stem: String
        let extensionDigits: Int

        if trailingZeros > 0 {
            stem = String(baseE164.dropLast(trailingZeros))
            extensionDigits = trailingZeros
        } else {
            // Heuristik B: keine offensichtliche Hauptnummer
            // Annahme: letzte 2 Ziffern könnten Durchwahl sein
            extensionDigits = 2
            stem = String(baseE164.dropLast(extensionDigits))
        }

        // Anzahl Einträge: 10^extensionDigits, aber gedeckelt durch company.extensionCount
        let maxPossible = pow10(extensionDigits)
        let count = min(maxPossible, company.extensionCount)

        var entries: [DirectoryEntry] = []
        entries.reserveCapacity(count)

        for i in 0..<count {
            let suffix = String(format: "%0\(extensionDigits)d", i)
            let candidateE164 = stem + suffix

            // E.164 ohne führendes "+" für CallKit (das will Int64)
            guard let phoneNumber = e164ToInt64(candidateE164) else { continue }

            entries.append(
                DirectoryEntry(
                    e164: candidateE164,
                    phoneNumber: phoneNumber,
                    label: label
                )
            )
        }

        return entries
    }

    // MARK: - Helpers

    private static func countTrailingZeros(in s: String, max: Int) -> Int {
        var count = 0
        for ch in s.reversed() {
            if ch == "0" && count < max {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private static func pow10(_ n: Int) -> Int {
        var result = 1
        for _ in 0..<n { result *= 10 }
        return result
    }

    private static func e164ToInt64(_ e164: String) -> Int64? {
        // "+4956329699970" → 4956329699970
        guard e164.hasPrefix("+") else { return nil }
        return Int64(e164.dropFirst())
    }

    private static func makeLabel(for organizationName: String) -> String {
        let prefix = "Möglich: "
        let trimmedOrg = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = prefix + trimmedOrg

        if full.count <= maxLabelLength {
            return full
        }

        // Kürzen mit Ellipsis
        let allowedOrgLength = maxLabelLength - prefix.count - 1  // -1 für "…"
        let truncated = String(trimmedOrg.prefix(allowedOrgLength))
        return prefix + truncated + "…"
    }
}
