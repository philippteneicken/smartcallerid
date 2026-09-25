import Foundation
import libPhoneNumber

enum PhoneNumberCategory {
    case festnetz
    case mobilfunk
    case sondernummer
    case ungueltig

    var supportsFuzzyMatch: Bool {
        self == .festnetz
    }
}

enum NumberClassifier {

    static func classify(_ e164: String) -> PhoneNumberCategory {
        guard e164.hasPrefix("+") else { return .ungueltig }

        let nationalAndCountry = String(e164.dropFirst())
        guard nationalAndCountry.allSatisfy(\.isNumber) else { return .ungueltig }
        guard nationalAndCountry.count >= 6 else { return .ungueltig }

        if e164.hasPrefix("+49") {
            return classifyGerman(nationalPart: String(e164.dropFirst(3)))
        }

        return classifyViaLibPhoneNumber(e164)
    }

    /// Präzise Regeln für +49: Mobilfunk-Gassen, Sondernummern, Notrufe.
    private static func classifyGerman(nationalPart: String) -> PhoneNumberCategory {
        guard nationalPart.count >= 6 else { return .ungueltig }

        if nationalPart.hasPrefix("15") || nationalPart.hasPrefix("16") || nationalPart.hasPrefix("17") {
            return .mobilfunk
        }

        let sonderPraefixe = ["800", "900", "180", "137", "138", "1900", "10"]
        for praefix in sonderPraefixe {
            if nationalPart.hasPrefix(praefix) {
                return .sondernummer
            }
        }

        if nationalPart == "110" || nationalPart == "112" || nationalPart == "116117" {
            return .sondernummer
        }

        if let firstDigit = nationalPart.first, firstDigit >= "2", firstDigit <= "9" {
            return .festnetz
        }

        return .ungueltig
    }

    /// Alle anderen Länder: Nummerntyp über die libPhoneNumber-Metadaten bestimmen.
    /// FIXED_LINE_OR_MOBILE (z. B. NANP/USA) wird wie Festnetz behandelt, da dort
    /// Durchwahlbereiche (DID-Ranges) üblich sind.
    private static func classifyViaLibPhoneNumber(_ e164: String) -> PhoneNumberCategory {
        let util = NBPhoneNumberUtil.sharedInstance()
        guard let parsed = try? util.parse(e164, defaultRegion: "ZZ"),
              util.isValidNumber(parsed) else {
            return .ungueltig
        }

        switch util.getNumberType(parsed) {
        case .FIXED_LINE, .FIXED_LINE_OR_MOBILE:
            return .festnetz
        case .MOBILE, .PAGER:
            return .mobilfunk
        case .TOLL_FREE, .PREMIUM_RATE, .SHARED_COST, .VOICEMAIL, .UAN:
            return .sondernummer
        default:
            return .ungueltig
        }
    }
}
