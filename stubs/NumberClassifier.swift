import Foundation

/// Klassifiziert deutsche E.164-Nummern, um zu entscheiden, ob Fuzzy-Matching sinnvoll ist.
enum PhoneNumberCategory {
    case deutscheFestnetz
    case deutschesMobilfunk
    case sondernummer       // 0800, 0180, 0900, etc.
    case international      // nicht +49
    case ungültig

    /// Soll für diese Kategorie Fuzzy-Match (Durchwahl-Erkennung) angewendet werden?
    var supportsFuzzyMatch: Bool {
        self == .deutscheFestnetz
    }
}

enum NumberClassifier {

    /// Klassifiziert eine E.164-Nummer.
    /// Erwartet Input im E.164-Format (z.B. "+4956329699970").
    static func classify(_ e164: String) -> PhoneNumberCategory {
        guard e164.hasPrefix("+") else { return .ungültig }

        // International, nicht Deutschland
        guard e164.hasPrefix("+49") else { return .international }

        // Nur Ziffern nach +49
        let nationalPart = String(e164.dropFirst(3))
        guard nationalPart.allSatisfy(\.isNumber) else { return .ungültig }
        guard nationalPart.count >= 6 else { return .ungültig }

        // Deutsches Mobilfunk: +491[567]x...
        // 015x, 016x, 017x — siehe Bundesnetzagentur Nummerierungsplan
        if nationalPart.hasPrefix("15") || nationalPart.hasPrefix("16") || nationalPart.hasPrefix("17") {
            return .deutschesMobilfunk
        }

        // Sondernummern
        let sonderPräfixe = ["800", "900", "180", "137", "138", "1900", "10"]
        for präfix in sonderPräfixe {
            if nationalPart.hasPrefix(präfix) {
                return .sondernummer
            }
        }

        // Notrufe (defensiv)
        if nationalPart == "110" || nationalPart == "112" || nationalPart == "116117" {
            return .sondernummer
        }

        // Default: Festnetz mit Ortsvorwahl (2-9 als erste Ziffer der Vorwahl)
        if let firstDigit = nationalPart.first, firstDigit >= "2", firstDigit <= "9" {
            return .deutscheFestnetz
        }

        return .ungültig
    }
}
