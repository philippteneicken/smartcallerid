# SPEC.md — SmartCallerID Funktionale Spezifikation

## 1. Zielgruppe

Selbstständige, Außendienstler, Unternehmer und Sales-Mitarbeiter, die viele Anrufe von Firmen-Telefonanlagen (mit Durchwahlen) erhalten und nicht jede einzelne Durchwahl im Adressbuch hinterlegen wollen.

## 2. Kernfunktionen

### 2.1 Kontakt-Sync

- App fragt einmalig nach Berechtigung für Kontakte (`NSContactsUsageDescription`)
- Liest alle Kontakte über `CNContactStore`
- Filterregel: Nur Kontakte mit nicht-leerem `organizationName` werden berücksichtigt
- Optional (Phase 2): User kann manuell auch Kontakte ohne Firmennamen als "Firma" markieren
- Re-Sync: Manuell per Button + automatisch bei App-Start

### 2.2 Fuzzy-Match-Generierung

Für jede Firmennummer werden Durchwahl-Bereiche generiert. Details siehe `FUZZY_LOGIC.md`. Kurzfassung:

- Stamm-Nummer normalisieren auf E.164 (`+49...`)
- Letzte 1–3 Ziffern als potenzielle Durchwahl betrachten
- Heuristik: Endet die Stamm-Nummer auf `0`, `00` oder `000` → klassische Telefonanlage → Durchwahl-Range generieren
- Generierte Einträge werden in SQLite mit Spalten `e164`, `label`, `source_contact_id` gespeichert

### 2.3 Call Directory Extension

- Liest Einträge aus geteilter SQLite-DB
- Streamt sie batched (z.B. 10.000 pro Batch) an iOS
- Gibt Labels im Format `"Möglich: <Firmenname>"` zurück
- Kein Blocken von Nummern (Phase 1)

### 2.4 Reload-Trigger

Nach jeder Änderung der Einträge:

```swift
CXCallDirectoryManager.sharedInstance.reloadExtension(
    withIdentifier: "de.cleangas.smartcallerid.calldirectory"
) { error in /* ... */ }
```

User muss informiert werden, falls die Extension nicht aktiviert ist (`getEnabledStatusForExtension`).

### 2.5 UI (SwiftUI)

**Tab 1: Übersicht**
- Anzahl überwachter Firmen
- Anzahl generierter Einträge
- Status der Extension (aktiviert / deaktiviert / Fehler)
- Button "Jetzt synchronisieren"
- Letzter Sync-Zeitpunkt

**Tab 2: Firmen**
- Liste aller Firmenkontakte mit Anzahl generierter Durchwahl-Einträge
- Tap auf Firma → Detailansicht mit:
  - Stamm-Nummer
  - Generierte Durchwahl-Range
  - Toggle "für diese Firma deaktivieren"
  - Toggle "weniger / mehr Durchwahlen generieren" (Slider 10 / 100 / 1000)

**Tab 3: Einstellungen**
- Globale Standard-Durchwahl-Anzahl pro Firma (Default: 100)
- Label-Präfix anpassen (Default: "Möglich: ")
- App-Group-Status anzeigen
- Hilfe-Sektion: Anleitung wie man Extension in iOS-Einstellungen aktiviert
- Datenschutz: Hinweis dass Kontakte das Gerät nie verlassen

## 3. Datenmodell

### 3.1 SQLite-Schema (geteilte DB)

```sql
CREATE TABLE companies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_identifier TEXT NOT NULL UNIQUE, -- CNContact.identifier
    organization_name TEXT NOT NULL,
    base_phone_e164 TEXT NOT NULL,
    extension_count INTEGER NOT NULL DEFAULT 100,
    is_enabled INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL
);

CREATE TABLE entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    e164 TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    company_id INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
);

CREATE INDEX idx_entries_e164 ON entries(e164);
```

### 3.2 In-Memory-Modelle (Swift)

```swift
struct Company: Identifiable, Codable {
    let id: Int64
    let contactIdentifier: String
    let organizationName: String
    let basePhoneE164: String
    var extensionCount: Int
    var isEnabled: Bool
    let updatedAt: Date
}

struct DirectoryEntry {
    let e164: String         // z.B. "+4956329699716"
    let phoneNumber: Int64   // 4956329699716 — für CXCallDirectory
    let label: String        // z.B. "Möglich: CLEANGAS GmbH"
}
```

## 4. Berechtigungen (Info.plist)

```xml
<key>NSContactsUsageDescription</key>
<string>SmartCallerID liest deine Kontakte, um Firmennummern zu erkennen und Durchwahlen automatisch zu identifizieren. Deine Kontakte verlassen das Gerät nie.</string>
```

## 5. Bundle Identifiers

- Hauptapp: `de.cleangas.smartcallerid`
- Extension: `de.cleangas.smartcallerid.calldirectory`
- App Group: `group.de.cleangas.smartcallerid`

## 6. Nicht-Ziele (Phase 1)

- Kein Anruf-Blocking (CallKit erlaubt das prinzipiell, aber out-of-scope)
- Keine cloudbasierte Spam-DB
- Keine Erkennung über Telefonbuch-Drittanbieter
- Keine eigene UI während des Anrufs (technisch nicht möglich für Drittanbieter)
- Kein iCloud-Sync der App-Einstellungen (Phase 2)

## 7. Erfolgskriterien

- App identifiziert mindestens 80% der Durchwahlen einer korrekt konfigurierten Firma
- Reload der Extension dauert bei 100.000 Einträgen < 30 Sekunden
- Memory-Verbrauch der Extension bleibt unter 12 MB
- Keine False Positives für Mobilfunknummern (`+491...`) — diese werden NIE als "möglich" markiert
