# XCODE_SETUP.md — Manuelle Schritte in Xcode

⚠️ Claude Code kann Xcode-Projektdateien (`.xcodeproj`) nicht zuverlässig generieren oder modifizieren. Diese Schritte musst du selbst in Xcode klicken. Danach kann Claude Code die Swift-Files schreiben.

## Voraussetzungen

- macOS mit Xcode 15+
- Apple Developer Account (kostenlos reicht für Entwicklung; für TestFlight/App Store: kostenpflichtig)

## Schritt 1: Hauptprojekt anlegen

1. Xcode öffnen → "Create New Project"
2. iOS → App → Next
3. Eingaben:
   - Product Name: `SmartCallerID`
   - Team: dein Developer-Team
   - Organization Identifier: `de.cleangas`
   - Bundle Identifier: wird automatisch `de.cleangas.SmartCallerID` — auf `de.cleangas.smartcallerid` ändern
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **NEIN** (wir nutzen GRDB)
   - Include Tests: **JA**
4. Speicherort wählen, Create

## Schritt 2: iOS-Deployment-Target setzen

1. Projekt im Navigator anklicken
2. Target `SmartCallerID` → General → Minimum Deployments → iOS **17.0**

## Schritt 3: App Group hinzufügen (Hauptapp)

1. Target `SmartCallerID` → Signing & Capabilities
2. `+ Capability` → "App Groups" hinzufügen
3. `+` Button im App-Groups-Block → `group.de.cleangas.smartcallerid` eintragen
4. Häkchen aktivieren

## Schritt 4: Call Directory Extension Target hinzufügen

1. File → New → Target
2. iOS → "Call Directory Extension" → Next
3. Eingaben:
   - Product Name: `CallDirectoryExtension`
   - Team: dasselbe wie Hauptapp
   - Project: `SmartCallerID`
   - Embed in Application: `SmartCallerID`
4. Finish (NICHT "Activate" wenn gefragt — es geht um Scheme-Aktivierung, nicht relevant)

5. Bundle Identifier des Extension-Targets prüfen: sollte `de.cleangas.smartcallerid.calldirectory` sein. Wenn nicht, anpassen.

## Schritt 5: App Group für Extension aktivieren

1. Target `CallDirectoryExtension` → Signing & Capabilities
2. `+ Capability` → "App Groups"
3. `group.de.cleangas.smartcallerid` aktivieren (sollte schon in der Liste sein)

## Schritt 6: Swift Packages hinzufügen

1. File → Add Package Dependencies
2. URL: `https://github.com/iziz/libPhoneNumber-iOS`
3. Add Package → Beim Auswahl-Dialog: Sowohl `SmartCallerID` als auch `CallDirectoryExtension` aktivieren
4. Wiederholen für: `https://github.com/groue/GRDB.swift`

## Schritt 7: Info.plist Eintrag

1. Target `SmartCallerID` → Info → Custom iOS Target Properties
2. `+` → Key: `Privacy - Contacts Usage Description`
3. Value: `SmartCallerID liest deine Kontakte, um Firmennummern zu erkennen und Durchwahlen automatisch zu identifizieren. Deine Kontakte verlassen das Gerät nie.`

## Schritt 8: Ordner-Struktur

Im Xcode-Navigator unter `SmartCallerID` (gelber Ordner) folgende Gruppen anlegen (Right-Click → New Group):

```
SmartCallerID/
├── App/                  ← SmartCallerIDApp.swift, MainTabView.swift
├── Features/
│   ├── Overview/
│   ├── Companies/
│   └── Settings/
├── Services/             ← ContactsService, SyncCoordinator, ExtensionStatusChecker
└── Shared/               ← Cross-Target-Code (siehe nächster Schritt!)
```

## Schritt 9: Shared-Code für beide Targets

Files in `Shared/` müssen sowohl von `SmartCallerID` als auch von `CallDirectoryExtension` benutzt werden. Zwei Optionen:

**Option A (einfach):** Pro Datei in `Shared/` rechtsklicken → "Show File Inspector" → unter "Target Membership" beide Targets aktivieren.

**Option B (sauber, empfohlen):** Lokales Swift Package erstellen.
1. File → New → Package → "Library"
2. Name: `SmartCallerKit`, im Projekt-Root speichern
3. Beide Targets fügen `SmartCallerKit` als Dependency hinzu (Frameworks, Libraries, and Embedded Content)

Für Phase 1 reicht Option A vollkommen.

## Schritt 10: Verifizieren

1. Cmd+B → beide Targets müssen kompilieren
2. App im Simulator starten — sollte leere Hauptansicht zeigen
3. Im Simulator: Settings → Phone → Call Blocking & Identification → SmartCallerID sollte erscheinen (zunächst deaktiviert)

## Ab hier: Claude Code übernimmt

Nach Phase 0 öffne dein Projekt in Claude Code:

```bash
cd ~/Projekte/SmartCallerID
claude code
```

Und sag Claude Code:

> Lies die Dateien in `docs/` und im `stubs/`-Ordner und arbeite die Tasks in `docs/TASKS.md` ab Phase 1 sequenziell ab. Frage mich, bevor du destruktive Änderungen am Xcode-Projekt machst.
