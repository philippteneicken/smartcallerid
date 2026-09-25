import Foundation
import libPhoneNumber

final class PhoneNumberNormalizer {
    static let shared = PhoneNumberNormalizer()

    private let util = NBPhoneNumberUtil.sharedInstance()

    private init() {}

    /// Region für Nummern ohne Ländervorwahl: standardmäßig die Geräteregion,
    /// damit lokal gespeicherte Kontakte weltweit korrekt geparst werden.
    static var deviceRegion: String {
        Locale.current.region?.identifier ?? "DE"
    }

    func normalize(_ input: String, defaultRegion: String = PhoneNumberNormalizer.deviceRegion) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("*") || trimmed.contains("#") {
            return nil
        }

        do {
            let parsed = try util.parse(trimmed, defaultRegion: defaultRegion)
            guard util.isValidNumber(parsed) else { return nil }
            return try util.format(parsed, numberFormat: .E164)
        } catch {
            return nil
        }
    }

    func isValid(_ e164: String) -> Bool {
        normalize(e164) != nil
    }
}
