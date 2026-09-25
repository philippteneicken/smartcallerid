# FUZZY_LOGIC.md — Durchwahl-Erkennungs-Heuristik

## Ziel

Aus einer Stamm-Rufnummer (z.B. `05632 969970`) plausible Durchwahl-Varianten generieren, die als "Möglich: <Firma>" identifiziert werden sollen.

## Schritt 1: Normalisierung

Jede Rufnummer wird via `libPhoneNumber-iOS` ins E.164-Format gebracht:

```
"05632 969970"     → "+4956329699970" (Annahme: DE)
"05632/96 99 70"   → "+4956329699970"
"+49 5632 969970"  → "+4956329699970"
"00495632969970"   → "+4956329699970"
```

Default-Region: `DE`. Wird per Settings konfigurierbar (Phase 2).

## Schritt 2: Klassifizierung

Eingehende Nummer wird eingeteilt in:

| Typ | E.164-Muster | Behandlung |
|-----|--------------|------------|
| Deutsche Festnetznummer | `+49[2-9]xxxxxx...` | Fuzzy-Match aktiv |
| Deutsche Mobilfunknummer | `+491[567]x...` | **NIEMALS Fuzzy-Match** |
| Sondernummern (0800, 0180, etc.) | `+498xx`, `+4918xx` | Kein Fuzzy-Match |
| Internationale Nummer | nicht `+49` | Kein Fuzzy-Match (Phase 1) |

**Regel:** Mobilfunknummern haben keine Durchwahlen. False Positives wären peinlich.

## Schritt 3: Stamm-Erkennung

Pro Firmennummer wird die "Hauptnummer-Länge" bestimmt:

### Heuristik A: Endung auf `0`

| Stamm-Nummer | Erkannte Hauptnummer | Generierte Range |
|--------------|----------------------|------------------|
| `+4956329699970` (endet auf `0`) | `+495632969997` | `+4956329699970` bis `+4956329699799` (100 Einträge bei Default) |
| `+495632969970` (endet auf `0`) | `+49563296997` | `+495632969970` bis `+495632969979` |
| `+4956329699000` (endet auf `000`) | `+4956329699` | `+4956329699000` bis `+4956329699999` (1000 Einträge) |

**Algorithmus:**
1. Trailing `0`s zählen (max 3)
2. Stamm = Nummer ohne trailing `0`s
3. Range = Stamm + alle Ziffern-Kombinationen der Länge der trailing `0`s

### Heuristik B: Endung NICHT auf `0`

Beispiel: `+4956329699971` (keine offensichtliche Hauptnummer).

In diesem Fall:
- Annehmen: Letzte 2 Ziffern könnten Durchwahl sein
- Stamm = Nummer ohne letzte 2 Ziffern (`+49563296997`)
- Range = Stamm + `00` bis `99` (also 100 Einträge)
- **Aber:** Den exakten Originaleintrag NICHT überschreiben (das ist ja schon der echte Kontakt)

**Konfigurierbar pro Firma:** User kann im UI die Heuristik anpassen (10/100/1000 Durchwahlen).

## Schritt 4: Kollisionsbehandlung

Wenn zwei Firmen denselben Stamm-Bereich generieren (z.B. zwei Firmen mit `+49 5632 9...`):

- E.164 ist UNIQUE in der DB
- Bei Konflikt: Eintrag mit kombiniertem Label, z.B. `"Möglich: CLEANGAS oder Müller GmbH"`
- Implementierung: Beim Insert prüfen, ob `e164` schon existiert → Label updaten

## Schritt 5: Exklusionsliste

Bestimmte Nummern werden NIE generiert:
- Notrufnummern: 110, 112, 116117
- Nummern, die bereits als exakter Kontakt im Adressbuch sind (würden iOS verwirren)

## Schritt 6: Label-Format

```
Standard: "Möglich: <organizationName>"
Beispiel: "Möglich: CLEANGAS GmbH"
```

User kann den Präfix in den Einstellungen ändern (z.B. zu "?" oder "Vermutlich:").

iOS-Label hat ein Längenlimit (~ 70 Zeichen). Lange Firmennamen werden auf 60 Zeichen gekürzt + "...".

## Schritt 7: Beispielhafter Output

Für Kontakt `CLEANGAS GmbH` mit Nummer `+4956329699970` und Default-Setting (100 Einträge):

```
+4956329699900 → "Möglich: CLEANGAS GmbH"
+4956329699901 → "Möglich: CLEANGAS GmbH"
...
+4956329699999 → "Möglich: CLEANGAS GmbH"
```

**Hinweis:** Wenn `+4956329699970` selbst schon im Adressbuch ist, hat iOS Vorrang und zeigt den echten Kontaktnamen, nicht "Möglich:".

## Edge Cases

- **Sehr kurze Nummern (<7 Stellen):** Werden ignoriert — zu hohes Kollisionsrisiko
- **Nummern mit "*" oder "#":** Werden ignoriert
- **Doppelte Kontakte:** Per `contact_identifier` dedupliziert
- **Kontakt hat mehrere Nummern:** Jede Festnetz-Nummer wird einzeln verarbeitet, alle erzeugen Einträge
