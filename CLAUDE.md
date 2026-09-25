# SmartCallerID — Claude Code Projektkontext

## Was ist diese App?

SmartCallerID ist eine iOS-App, die eingehende Anrufer identifiziert, deren Nummer **nicht exakt** mit einem Kontakt übereinstimmt, aber **wahrscheinlich eine Durchwahl** einer im Adressbuch hinterlegten Firmennummer ist.

**Beispiel:**
- Im Adressbuch: `CLEANGAS GmbH` — `+49 5632 969970`
- Eingehender Anruf von: `+49 5632 9699716`
- iOS zeigt normalerweise: "Unbekannt"
- Mit SmartCallerID: "Möglich: CLEANGAS GmbH"

## Architektur (Kurzfassung)

Drei Targets in einem Xcode-Workspace:

1. **SmartCallerID** (Hauptapp, SwiftUI)
   - Liest Kontakte via `Contacts` Framework
   - Filtert Firmenkontakte (Kontakte mit `organizationName`)
   - Generiert Fuzzy-Match-Einträge (Durchwahl-Bereiche)
   - Schreibt Einträge in eine SQLite-Datenbank im App-Group-Container
   - Triggert Reload der Call Directory Extension
   - UI: Liste der überwachten Firmen, Statistiken, Einstellungen

2. **CallDirectoryExtension** (Call Directory Extension)
   - Implementiert `CXCallDirectoryProvider`
   - Streamt Identification-Einträge aus der SQLite-DB an iOS
   - Memory-Limit: ~12 MB → batched Streaming, sortiert aufsteigend nach E.164-Nummer
   - Liefert Labels im Format `"Möglich: <Firmenname>"`

3. **Shared** (Swift Package, lokal)
   - PhoneNumberNormalizer (E.164-Konvertierung, libPhoneNumber-iOS)
   - DatabaseManager (SQLite-Zugriff, in beiden Targets identisch)
   - FuzzyMatchGenerator (Durchwahl-Heuristik)
   - AppGroup-Konstanten

## App Group

App Group Identifier: `group.de.cleangas.smartcallerid`
- Geteilter Container enthält: `entries.sqlite`
- Beide Targets müssen die App-Group-Capability aktiviert haben

## Kritische iOS-Constraints

- **Call Directory Extension Memory Limit:** ~12 MB. Niemals alle Einträge auf einmal laden.
- **Einträge müssen aufsteigend nach E.164-Nummer sortiert sein** — sonst wirft `addIdentificationEntry` eine Exception.
- **E.164-Format zwingend:** `+49...` ohne Leerzeichen, ohne Klammern.
- **User muss Extension manuell aktivieren:** Einstellungen → Telefon → Anrufblockierung & Identifizierung → SmartCallerID
- **iOS-Kontakte haben Vorrang:** Wenn ein Anrufer im Adressbuch steht, zeigt iOS dessen Namen. Unsere Extension wird nur für unbekannte Nummern befragt.

## Coding-Konventionen

- Swift 5.9+, iOS 17+ (für moderne SwiftUI-Features)
- SwiftUI mit `@Observable` Macro statt `ObservableObject`
- Async/await statt Completion Handlers
- Strukturierte Logs via `os.Logger`
- Fehlerbehandlung mit `Result` oder typisierten Errors
- Keine Force-Unwraps in Production-Code

## Externe Abhängigkeiten

- **libPhoneNumber-iOS** (Swift Package Manager): https://github.com/iziz/libPhoneNumber-iOS
- **GRDB.swift** (Swift Package Manager): https://github.com/groue/GRDB.swift — typsicherer SQLite-Wrapper, deutlich angenehmer als rohes SQLite

## Bezugsdokumente

- `docs/SPEC.md` — vollständige funktionale Spezifikation
- `docs/TASKS.md` — Schritt-für-Schritt Umsetzungsplan für Claude Code
- `docs/FUZZY_LOGIC.md` — detaillierte Spezifikation der Durchwahl-Heuristik
- `docs/XCODE_SETUP.md` — manuelle Xcode-Schritte (Targets, Capabilities, Signing)
- `stubs/` — vorbereitete Code-Stubs für die wichtigsten Klassen
