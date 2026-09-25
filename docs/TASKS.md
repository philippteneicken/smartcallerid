# TASKS.md — Schritt-für-Schritt Umsetzungsplan

## Phase 0: Projekt-Setup

Automatisiert via `xcodegen` — `project.yml` im Repo-Root beschreibt das gesamte
Xcode-Projekt. Generieren mit:

```bash
xcodegen generate
```

- [x] Xcode-Projekt `SmartCallerID` (Bundle-ID `de.cleangas.smartcallerid`, iOS 17+)
- [x] App Group `group.de.cleangas.smartcallerid` via Entitlements-Datei
- [x] Call Directory Extension `CallDirectoryExtension` (Bundle-ID `de.cleangas.smartcallerid.calldirectory`)
- [x] App Group auch beim Extension-Target
- [x] Swift Packages: libPhoneNumber-iOS, GRDB.swift (beide Targets)
- [x] `NSContactsUsageDescription` in generierter Info.plist

## Phase 1: Shared-Code-Basis

- [x] **Task 1.1:** `Shared/AppGroupConstants.swift` (inkl. Dev-Fallback)
- [x] **Task 1.2:** `Shared/PhoneNumberNormalizer.swift` (libPhoneNumber-Wrapper)
- [x] **Task 1.3:** `Shared/NumberClassifier.swift`
- [x] **Task 1.4:** `Shared/Models.swift` (Company, DirectoryEntry)
- [x] **Task 1.5:** `Shared/DatabaseManager.swift` (GRDB)
- [x] **Task 1.6:** `Shared/FuzzyMatchGenerator.swift`

## Phase 2: Hauptapp

- [x] **Task 2.1:** `SmartCallerIDApp.swift`
- [x] **Task 2.2:** `ContactsService.swift`
- [x] **Task 2.3:** `SyncCoordinator.swift`
- [x] **Task 2.4:** `OverviewView.swift`
- [x] **Task 2.5:** `CompaniesListView.swift` + `CompanyDetailView.swift`
- [x] **Task 2.6:** `SettingsView.swift`
- [x] **Task 2.7:** `MainTabView.swift`
- [x] **Task 2.8:** `ExtensionStatusChecker.swift`

## Phase 3: Call Directory Extension

- [x] **Task 3.1:** `CallDirectoryHandler.swift`
- [x] **Task 3.2:** `os.Logger` in der Extension

## Phase 4: Polish & Testing

- [x] **Task 4.1:** Unit Tests `PhoneNumberNormalizerTests` (3 Tests)
- [x] **Task 4.2:** Unit Tests `NumberClassifierTests` (6 Tests)
- [x] **Task 4.3:** Unit Tests `FuzzyMatchGeneratorTests` (12 Tests)
- [ ] **Task 4.4:** Manueller End-to-End-Test auf echtem Gerät mit Provisioning-Profile
- [ ] **Task 4.5:** App-Icon & Launch-Screen (aktuell Platzhalter in Asset-Catalog)
- [ ] **Task 4.6:** End-User-README

## Phase 5 (später)

- [ ] iCloud-Sync der Einstellungen
- [ ] Spam-Blocking-Modus
- [ ] Manuelle Markierung „ist Firma"
- [ ] Multi-Region-Support

## Bauen & Testen

```bash
# Projekt (neu) generieren
xcodegen generate

# Baut beide Targets (ohne Signing, SDK iphoneos)
xcodebuild -project SmartCallerID.xcodeproj -scheme SmartCallerID \
           -sdk iphoneos -destination 'generic/platform=iOS' \
           -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Unit-Tests im Simulator
xcodebuild -project SmartCallerID.xcodeproj -scheme SmartCallerID \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
           -configuration Debug test CODE_SIGNING_ALLOWED=NO
```

Für Installation auf echtem Gerät muss `DEVELOPMENT_TEAM` in `project.yml`
eingetragen und Code-Signing aktiviert werden.
