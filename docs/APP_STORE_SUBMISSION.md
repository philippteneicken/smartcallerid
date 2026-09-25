# App Store Submission Guide — SmartCallerID

Komplette Anleitung für die (erneute) Einreichung nach der Ablehnung.
Stand: Juli 2026, Version 2.0 (Build 2).

---

## Teil A — Was war wahrscheinlich der Ablehnungsgrund?

Ohne den genauen Rejection-Text lässt sich der Grund nicht sicher benennen —
**bitte den Text aus App Store Connect → App Review nachreichen**, dann lässt er
sich exakt zuordnen. Der Code enthielt aber fünf Probleme, die jedes für sich
regelmäßig zur Ablehnung führen. Alle sind jetzt behoben:

| # | Guideline | Problem (vorher) | Fix (jetzt) |
|---|---|---|---|
| 1 | **3.1.2** | Paywall ohne Links zu Datenschutzerklärung und Nutzungsbedingungen (EULA) — der häufigste Ablehnungsgrund bei Abo-Apps | Links in Paywall + Einstellungen ([LegalLinks.swift](../SmartCallerID/App/LegalLinks.swift)) |
| 2 | **2.1** | App lief auch auf iPad — dort gibt es keine Telefon-App, die Anruferkennung kann nie aktiviert werden. Apple testet häufig auf iPads → „App funktioniert nicht“ | iPhone-only: `TARGETED_DEVICE_FAMILY=1` + `UIRequiredDeviceCapabilities: telephony` |
| 3 | **2.1** | Durchwahl-Erkennung funktionierte **nur für deutsche Festnetznummern**. Ein US-Reviewer mit US-Testkontakten sah null Funktion | Internationalisiert: Nummerntyp-Erkennung via libPhoneNumber für alle Länder |
| 4 | **5.1.1** | Kontakte-Berechtigung wurde sofort beim App-Start abgefragt, ohne Kontext | Abfrage erst, wenn der Nutzer im Setup-Schritt „Zugriff erlauben“ tippt |
| 5 | **3.1.2 / 2.3.7** | Hartkodierte Preise („0,99 €“) in UI-Fallbacks — stimmen in anderen Storefronts nicht | Preise kommen ausschließlich aus StoreKit |

Zusätzlich behoben (Funktions-Bug, der in der Review als „broken“ auffallen konnte):

- **Call Directory Extension:** Bei inkrementellen Reloads (jeder Reload nach dem
  ersten) wurden Einträge doppelt hinzugefügt → Reload schlug fehl. Jetzt werden
  alte Einträge zuerst entfernt.
- Gemischt deutsch/englische Oberfläche für englischsprachige Reviewer (mehrere
  nicht lokalisierte Strings) — vollständig lokalisiert (de, en, es, pt).
- `ITSAppUsesNonExemptEncryption = false` gesetzt (keine Export-Compliance-Frage
  mehr pro Build).

---

## Teil B — Pflicht-Schritte VOR der Einreichung

### 1. Datenschutzerklärung hosten (BLOCKER)

Die Datei [docs/legal/privacy-policy.html](legal/privacy-policy.html) muss
öffentlich erreichbar sein. In der Datei vorher **die Adresse des Unternehmens
eintragen** (Platzhalter `[Straße und Hausnummer]` etc.).

Erwartete URL (in der App verlinkt): `https://cleangas.com/smartcallerid/privacy.html`

Wenn die Policy woanders gehostet wird (z. B. GitHub Pages), die URL in
[SmartCallerID/App/LegalLinks.swift](../SmartCallerID/App/LegalLinks.swift)
anpassen — der Link ist in der Paywall und den Einstellungen live und wird von
Apple geklickt.

### 2. Abo in App Store Connect korrekt anlegen

- **Produkt-ID exakt:** `de.cleangas.smartcallerid.pro.monthly`
  (muss zu `SubscriptionManager.monthlyProductID` passen)
- Abo-Gruppe „Pro“, monatlich, Preis z. B. 0,99 € (Tier automatisch pro Land)
- **Einführungsangebot:** 2 Wochen kostenlos (entspricht der StoreKit-Konfiguration)
- Lokalisierte Abo-Metadaten für de/en/es/pt (Texte: [APP_STORE_METADATA.md](APP_STORE_METADATA.md), unten)
- **Screenshot für das IAP-Review-Feld** hochladen (Paywall-Screenshot)
- ⚠️ **Beim allerersten Abo einer App muss das Abo zusammen mit der App-Version
  eingereicht werden:** In App Store Connect auf der Versionsseite unter
  „In-App-Käufe und Abonnements“ das Abo der Version hinzufügen. Fehlt das, kann
  der Reviewer nicht kaufen → garantierte 2.1-Ablehnung.
- Der **Paid-Apps-Vertrag** (Agreements, Tax, and Banking) muss aktiv sein,
  inkl. Bankverbindung und Steuerformularen — sonst laden Produkte nie.

### 3. App-Privacy-Angaben („Nutrition Label“)

Im Abschnitt App Privacy:

- **„Do you or your third-party partners collect data from this app?“ → NEIN.**
  (Kontakte werden nur on-device verarbeitet und verlassen das Gerät nie —
  das gilt bei Apple nicht als „Collection“.)
- Ergebnis: Label „Data Not Collected“ / „Keine Daten erfasst“.
- Privacy Policy URL: die gehostete URL aus Schritt 1.

Hinweis: Das Projekt nutzt GRDB (SQLite) und libPhoneNumber — beide sammeln
nichts, kein SDK telefoniert nach Hause. Die `PrivacyInfo.xcprivacy`-Anforderung
betrifft UserDefaults (Required-Reason-API): GRDB und die App nutzen
UserDefaults/File-Timestamp-APIs; falls beim Upload eine Warnung zu
Required-Reason-APIs kommt, in Xcode ein Privacy-Manifest mit
`NSPrivacyAccessedAPICategoryUserDefaults` → Reason `CA92.1` ergänzen.

### 4. Verfügbarkeit (Länder)

Empfohlene Strategie:

- **Welle 1 (jetzt):** Deutschland, Österreich, Schweiz, Luxemburg — Kernmarkt,
  Heuristik dort am stärksten (deutsche Nummerngassen sind exakt implementiert).
- **Welle 2 (gleich mitmachen, funktioniert seit der Internationalisierung):**
  USA, Kanada, UK, Niederlande, Belgien, Frankreich, Italien, Spanien, Portugal.
- Oder schlicht: **alle Storefronts** — technisch spricht nichts mehr dagegen,
  die Nummernklassifizierung ist jetzt weltweit korrekt (libPhoneNumber).

### 5. Screenshots

Nur noch iPhone-Screenshots nötig (App ist jetzt iPhone-only): 6,9" (iPhone 17
Pro Max) und 6,5" werden von ASC verlangt bzw. skaliert. Empfohlene Motive:

1. Übersicht mit „Alles bereit“ + Statistiken
2. Anrufbildschirm-Mockup mit „Möglich: …“-Label (als Marketing-Bild)
3. Kontaktliste mit Durchwahl-Einträgen
4. Detailansicht mit Erkennungslogik
5. Paywall (zeigt Preis + Trial + rechtliche Links)

---

## Teil C — Review-Notes (in App Store Connect einfügen)

In App Store Connect → Version → „App Review Information“ → Notes. **Dieser Text
ist entscheidend**, weil der Reviewer die Funktion sonst nicht testen kann:

```
SmartCallerID is a CallKit Call Directory app that identifies incoming calls
from direct-dial extensions of businesses the user has saved in their own
contacts. All processing is 100% on-device; no account, no server, no data
collection.

HOW TO TEST (takes ~2 minutes):

1. Launch the app. On the "Overview" tab, tap "Allow access" (step 1) and
   grant Contacts permission.
2. Create a test contact in the iOS Contacts app:
   - Company name: e.g. "ACME Corp"
   - Phone number with label "work": e.g. +1 (415) 555-2600
     (a number ending in one or two zeros demonstrates the feature best)
3. In SmartCallerID, tap "Open Settings" (step 2) and enable:
   Settings → Apps → Phone → Call Blocking & Identification → SmartCallerID.
4. Return to the app and tap "Sync now". The app generates likely extension
   entries (e.g. +14155552600 … +14155552699) for the iOS call directory.
5. VERIFICATION: The "Contacts" tab shows the generated extension entries per
   company. If you can place a call to the device from a number within that
   range (e.g. +14155552671), iOS displays "Possible: ACME Corp" on the call
   screen. The system caller-ID display cannot be simulated, which is why the
   app transparently lists all generated entries in the "Contacts" tab.

SUBSCRIPTION: The free tier identifies up to 10 contacts. The monthly
auto-renewing subscription "SmartCallerID Pro" (with 2-week free trial)
removes the limit. Restore is available on the paywall and in Settings.
Privacy policy and Terms of Use (Apple standard EULA) are linked on the
paywall and in Settings.

The app is iPhone-only (requires the Phone app / telephony capability).
```

Kontaktdaten für Rückfragen im Review-Formular hinterlegen (Telefon + E-Mail,
z. B. it@cleangas.com).

---

## Teil D — Einreichungs-Checkliste (chronologisch)

1. ☐ Adresse in `docs/legal/privacy-policy.html` eintragen und Datei hosten;
     ggf. URL in `LegalLinks.swift` anpassen
2. ☐ `xcodegen generate` ausführen (falls project.yml geändert wurde)
3. ☐ In Xcode: Version 2.0 (Build hochzählen bei jedem Upload), Team/Signing prüfen,
     App-Group-Capability für beide Targets aktiv
4. ☐ Archive erstellen (echtes Gerät als Ziel wählen: Any iOS Device arm64)
     und via Organizer zu App Store Connect hochladen
5. ☐ In ASC: Abo anlegen/prüfen (Teil B.2) und **der Version hinzufügen**
6. ☐ App-Privacy-Angaben setzen (Teil B.3)
7. ☐ Metadaten für de/en/es/pt einpflegen ([APP_STORE_METADATA.md](APP_STORE_METADATA.md))
8. ☐ Privacy Policy URL + Support-URL eintragen
9. ☐ Screenshots hochladen (nur iPhone)
10. ☐ Review-Notes einfügen (Teil C)
11. ☐ Verfügbarkeit/Länder wählen (Teil B.4), Preis der App: Gratis
12. ☐ Altersfreigabe: 4+ (keine bedenklichen Inhalte)
13. ☐ Einreichen — und bei Rückfragen des Reviews schnell antworten (Resolution
      Center), das beschleunigt die zweite Runde deutlich

---

## Teil E — Bekannte Grenzen / Ehrlichkeit gegenüber dem Review

- Das „Möglich:“-Label ist eine Heuristik — die App kommuniziert das transparent
  (Erkennungslogik-Sektion in der Detailansicht). Nicht als „identifiziert
  garantiert jeden Anrufer“ bewerben, das wäre 2.3.1-Risiko (Misleading).
- iOS zeigt Kontakte aus dem Adressbuch immer bevorzugt an; die Extension greift
  nur bei unbekannten Nummern. Steht so in Beschreibung + Review-Notes.
- Wenn Apple erneut ablehnt: Rejection-Text hier ins Projekt legen
  (docs/REJECTION.md) — die meisten Folge-Ablehnungen betreffen Metadaten und
  sind ohne neuen Build lösbar (Antwort im Resolution Center genügt oft).
