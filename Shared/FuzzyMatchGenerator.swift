import Foundation

enum FuzzyMatchGenerator {

    struct StrategyExplanation: Equatable {
        let stem: String
        let extensionDigits: Int
        let usesTrailingZeros: Bool
        let generatedCount: Int

        var firstExtension: String {
            String(format: "%0\(extensionDigits)d", 0)
        }

        var lastExtension: String {
            let maxIndex = max(0, generatedCount - 1)
            return String(format: "%0\(extensionDigits)d", maxIndex)
        }
    }

    static let maxLabelLength = 60

    /// Lokalisierter Prefix ("Möglich: " / "Possible: " …). Wird beim Sync in der
    /// Haupt-App aufgelöst und mit dem Eintrag in der DB gespeichert.
    static var labelPrefix: String {
        L10n.tr("label.possible_prefix")
    }

    static func generateEntries(for company: Company) -> [DirectoryEntry] {
        guard let strategy = strategyExplanation(for: company) else { return [] }

        let label = makeLabel(for: company.organizationName)

        var entries: [DirectoryEntry] = []
        entries.reserveCapacity(strategy.generatedCount)

        for i in 0..<strategy.generatedCount {
            let suffix = String(format: "%0\(strategy.extensionDigits)d", i)
            let candidateE164 = strategy.stem + suffix

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

    static func strategyExplanation(for company: Company) -> StrategyExplanation? {
        let category = NumberClassifier.classify(company.basePhoneE164)
        guard category.supportsFuzzyMatch else { return nil }

        let baseE164 = company.basePhoneE164
        let digitsOnly = baseE164.dropFirst()
        guard digitsOnly.count >= 7 else { return nil }

        let trailingZeros = countTrailingZeros(in: baseE164, max: 3)
        let stem: String
        let extensionDigits: Int
        let usesTrailingZeros: Bool

        if trailingZeros > 0 {
            stem = String(baseE164.dropLast(trailingZeros))
            extensionDigits = trailingZeros
            usesTrailingZeros = true
        } else {
            extensionDigits = 2
            stem = String(baseE164.dropLast(extensionDigits))
            usesTrailingZeros = false
        }

        let maxPossible = pow10(extensionDigits)
        let generatedCount = min(maxPossible, max(0, company.extensionCount))

        return StrategyExplanation(
            stem: stem,
            extensionDigits: extensionDigits,
            usesTrailingZeros: usesTrailingZeros,
            generatedCount: generatedCount
        )
    }

    static func makeLabel(for organizationName: String, prefix: String = labelPrefix) -> String {
        let trimmedOrg = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = prefix + trimmedOrg

        if full.count <= maxLabelLength {
            return full
        }

        let allowedOrgLength = max(1, maxLabelLength - prefix.count - 1)
        let truncated = String(trimmedOrg.prefix(allowedOrgLength))
        return prefix + truncated + "…"
    }

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
        guard e164.hasPrefix("+") else { return nil }
        return Int64(e164.dropFirst())
    }
}
