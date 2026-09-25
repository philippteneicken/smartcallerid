import Foundation

/// Zentrale rechtliche Links. Apple verlangt für Abo-Apps (Guideline 3.1.2)
/// funktionierende Links zu Datenschutzerklärung UND Nutzungsbedingungen —
/// sowohl in der App (Paywall) als auch in den App-Store-Metadaten.
///
/// WICHTIG VOR DER EINREICHUNG:
/// Die Datenschutzerklärung aus `docs/legal/` muss unter der hier eingetragenen
/// URL öffentlich erreichbar sein (siehe docs/APP_STORE_SUBMISSION.md, Schritt 1).
enum LegalLinks {
    /// Öffentlich gehostete Datenschutzerklärung (DE/EN auf einer Seite).
    static let privacyPolicy = URL(string: "https://cleangas.com/smartcallerid/privacy.html")!

    /// Apples Standard-EULA — von Apple ausdrücklich als "Terms of Use (EULA)"
    /// für Abo-Apps akzeptiert; keine eigene EULA nötig.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
