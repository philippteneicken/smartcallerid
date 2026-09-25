# SmartCallerID

iOS-App, die eingehende Anrufer als wahrscheinliche Durchwahl bekannter Firmen erkennt — auch wenn die exakte Nummer nicht im Adressbuch steht.

## Beispiel

- Im Adressbuch: `CLEANGAS GmbH` mit `+49 5632 969970`
- Eingehender Anruf: `+49 5632 9699716`
- iOS zeigt: **"Möglich: CLEANGAS GmbH"**

## Quickstart für Entwicklung mit Claude Code

### Schritt 1: Xcode-Projekt anlegen

Folge `docs/XCODE_SETUP.md` und lege das Xcode-Projekt mit beiden Targets manuell an. Das ist eine Einmal-Sache (~ 15 Minuten).

### Schritt 2: Projekt mit Claude Code öffnen

```bash
cd ~/Projekte/SmartCallerID
claude
```

### Schritt 3: Claude Code anweisen

Sag Claude Code:

> Lies `CLAUDE.md`, dann alle Dateien in `docs/` und `stubs/`.
> Arbeite die Tasks in `docs/TASKS.md` ab Phase 1 sequenziell ab.
> Nutze die Stubs in `stubs/` als Vorlage. Implementiere die `fatalError("Not implemented yet")`-Stellen.
> Frage mich bevor du Xcode-Projekteinstellungen änderst.

## Projektstruktur

```
SmartCallerID/
├── CLAUDE.md                      ← Hauptkontext für Claude Code
├── README.md                      ← diese Datei
├── docs/
│   ├── SPEC.md                    ← funktionale Spec
│   ├── TASKS.md                   ← step-by-step Aufgabenliste
│   ├── FUZZY_LOGIC.md             ← Heuristik-Spec
│   └── XCODE_SETUP.md             ← manuelle Xcode-Schritte
└── stubs/
    ├── AppGroupConstants.swift
    ├── PhoneNumberNormalizer.swift
    ├── NumberClassifier.swift
    ├── FuzzyMatchGenerator.swift
    ├── DatabaseManager.swift
    ├── CallDirectoryHandler.swift
    ├── Models.swift
    └── SyncCoordinator.swift
```

## Tech Stack

- Swift 5.9, iOS 17+
- SwiftUI mit `@Observable`
- CallKit (Call Directory Extension)
- Contacts Framework
- GRDB.swift (SQLite-Wrapper)
- libPhoneNumber-iOS (E.164-Normalisierung)

## Status

🟢 Implementiert (v2.0) — App-Review-Fixes eingearbeitet, bereit zur erneuten Einreichung.

Für die Einreichung: siehe `docs/APP_STORE_SUBMISSION.md` (Checkliste, Review-Notes,
Ablehnungsgründe-Analyse), `docs/APP_STORE_METADATA.md` (Store-Texte de/en/es/pt)
und `docs/legal/privacy-policy.html` (hosten, Adresse eintragen!).
