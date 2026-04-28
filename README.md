# GitHub Pages Setup für SmartCallerID

Diese Dateien gehen in ein neues GitHub Repository und werden via GitHub Pages öffentlich zugänglich gemacht.

## Schritt 1: Vor dem Upload — Platzhalter ersetzen

In ALLEN HTML-Dateien (`privacy.html`, `support.html`, `terms.html`) suche und ersetze:

| Suchen nach | Ersetzen durch |
|-------------|----------------|
| `[BITTE ANPASSEN: Vorname Nachname / Firmenname]` | Dein echter Name oder Firmenname |
| `[BITTE ANPASSEN: Straße Hausnummer]` | Deine echte Adresse |
| `[BITTE ANPASSEN: PLZ Ort, Deutschland]` | Deine PLZ + Ort |
| `[BITTE ANPASSEN: kontakt@deine-domain.de]` | Deine echte E-Mail |
| `[BITTE ANPASSEN: support@deine-domain.de]` | Deine Support-E-Mail (kann gleich sein) |

⚠️ **Pflicht in Deutschland:** Vollständige Adresse (Impressumspflicht). Postfach reicht NICHT.

**Tipp:** Ich empfehle, die Dateien zuerst lokal zu öffnen (Doppelklick → öffnet im Browser) und zu prüfen, dass alles passt. Erst dann hochladen.

## Schritt 2: Repository auf GitHub erstellen

1. Gehe zu https://github.com → oben rechts auf das `+` → **"New repository"**
2. **Repository name:** `smartcallerid` (genau so, klein geschrieben)
3. **Public** auswählen (Pages funktioniert mit kostenlosen Accounts nur bei Public)
4. **NICHT** "Add a README" anhaken (wir laden eigene Dateien hoch)
5. **"Create repository"** klicken

## Schritt 3: Dateien hochladen

1. Auf der nächsten Seite klickst du auf **"uploading an existing file"** (Link mitten auf der Seite)
2. Ziehe folgende Dateien per Drag & Drop ins Browserfenster:
   - `index.html`
   - `privacy.html`
   - `support.html`
   - `terms.html`
3. Scroll runter zu **"Commit changes"**
4. Commit message: `Initial upload`
5. **"Commit changes"** klicken

## Schritt 4: GitHub Pages aktivieren

1. Im Repository: oben auf **"Settings"** klicken
2. Links in der Seitenleiste auf **"Pages"** klicken
3. Bei **"Source"**: Branch wählen → `main`
4. Folder: `/ (root)` lassen
5. **"Save"** klicken

Nach 1-2 Minuten ist die Seite live unter:

```
https://<DEIN-GITHUB-USERNAME>.github.io/smartcallerid/
```

## Schritt 5: URLs für App Store Connect

Diese URLs trägst du in App Store Connect ein:

| Feld in App Store Connect | URL |
|---------------------------|-----|
| **Datenschutz-URL** | `https://<DEIN-USERNAME>.github.io/smartcallerid/privacy.html` |
| **Support-URL** | `https://<DEIN-USERNAME>.github.io/smartcallerid/support.html` |
| **Marketing-URL** (optional) | `https://<DEIN-USERNAME>.github.io/smartcallerid/` |

⚠️ **Wichtig:** Teste alle drei URLs in einem Inkognito-Fenster (Cmd+Shift+N), bevor du sie bei Apple einträgst. Sie müssen ohne Login öffentlich erreichbar sein.

## Schritt 6: Später Änderungen machen

Wenn du z. B. eine E-Mail-Adresse ändern willst:

1. Im Repository: auf die Datei klicken (z. B. `privacy.html`)
2. Stift-Icon oben rechts ("Edit this file")
3. Änderung machen → unten **"Commit changes"**
4. Nach ~ 1 Minute ist die Änderung live

## Bei Problemen

**Seite zeigt 404:**
- Hast du Pages wirklich aktiviert (Schritt 4)?
- Warte 2-3 Minuten, GitHub braucht manchmal etwas
- Pfad in der URL korrekt? (`/smartcallerid/privacy.html`, nicht `/Privacy.html`)

**Apple lehnt die URL ab:**
- Inkognito-Test gemacht? Login-Wand vorhanden?
- HTTPS funktioniert? (sollte automatisch via GitHub)
- Alle `[BITTE ANPASSEN]`-Stellen ersetzt?
