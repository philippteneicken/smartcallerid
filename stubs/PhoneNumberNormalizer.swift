import Foundation
import libPhoneNumber_iOS

/// Normalisiert Telefonnummern ins E.164-Format (z.B. "+4956329699970").
///
/// Wrapper um libPhoneNumber-iOS. Thread-safe Singleton.
final class PhoneNumberNormalizer {
    static let shared = PhoneNumberNormalizer()

    private let util = NBPhoneNumberUtil()

    private init() {}

    /// Konvertiert eine Roh-Telefonnummer in E.164.
    /// - Parameters:
    ///   - input: Roh-Eingabe wie "05632 969970", "+49 5632/969970", "00495632969970"
    ///   - defaultRegion: ISO-Ländercode (default: "DE")
    /// - Returns: E.164-String wie "+4956329699970", oder nil bei ungültiger Nummer
    func normalize(_ input: String, defaultRegion: String = "DE") -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let parsed = try util.parse(trimmed, defaultRegion: defaultRegion)
            guard util.isValidNumber(parsed) else { return nil }
            return try util.format(parsed, numberFormat: .E164)
        } catch {
            return nil
        }
    }

    /// Prüft ob eine bereits normalisierte E.164-Nummer gültig ist.
    func isValid(_ e164: String) -> Bool {
        normalize(e164) != nil
    }
}
