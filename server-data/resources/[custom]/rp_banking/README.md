# Geldautomaten – rp_banking

Vorhandene GTA-Automaten mit **E** benutzen (unter F12 frei belegbar). Alternativ `/rp_atm` direkt am Automaten. Einzahlen, Auszahlen, Überweisen und Kontoverlauf; keine Gebühren. Die Sitzung endet beim Entfernen, Tod, Charakterwechsel oder Schließen. E schließt ebenfalls, solange kein Textfeld bearbeitet wird. Maus, Tab/Enter und Pfeiltasten werden unterstützt; Escape beendet immer die Oberfläche.

## ESX-Vertrag

Geprüfte Basis: **ESX Legacy 1.15.2**, dessen offizielle `xPlayer.getAccount`, `addAccountMoney`, `removeAccountMoney`, `getIdentifier`, `getName` und `esx:playerSaved`-Verträge. Die offizielle Resource [esx_banking](https://github.com/esx-framework/ESX-Legacy-Addons/tree/main/%5Besx_addons%5D/esx_banking) wurde vor der Umsetzung geprüft. Ihre ATM-Standortliste wird als Ausgangspunkt verwendet. Die eigene Resource ergänzt die gewünschte Darstellung, Überweisungen am Automaten und einen dauerhaften Verlauf; kein zweites Bankkonto und keine Vendor-Patches. `esx_banking` darf nicht parallel laufen.

- Geld bleibt ausschließlich in den ESX-Konten **money** und **bank**. Alle Online-Änderungen laufen über aktuelle xPlayer-APIs. `inventory:accounts` bleibt `[]`; keine Geld-Items, keine parallele Saldenverwaltung.
- Alle Banken greifen auf dasselbe persönliche ESX-Bankkonto zu. Die Marke ist das Terminaldesign, kein neues Konto.
- Überweisungen gehen in dieser Version an **Online-Spieler per Server-ID**. Vor der Bestätigung wird der Charaktername angezeigt. Die Empfängerfreigabe ist an den vollständigen Charakter-Identifier, die Sitzung und eine kurze Gültigkeit gebunden. Eine wiedervergebene ID kann nicht unbeabsichtigt das Geld erhalten. Offline-Überweisungen sind nicht implementiert; Online-`users` werden nie direkt per SQL verändert.
- Verlauf und Buchungsjournal gehören zum vollen ESX-Identifier (`charN:license…`). Zwei Charaktere eines Accounts haben getrennte Konten und Einträge.
- Der Verlauf enthält ATM-Buchungen sowie offizielle ESX-Events `esx:addAccountMoney`, `esx:removeAccountMoney` und `esx:setAccountMoney` für `bank` ab Aktivierung dieser Resource. Ein absolut gesetzter Kontostand wird als solcher angezeigt, ohne einen erfundenen Differenzbetrag. Direkte SQL-Manipulationen fremder Scripts und frühere Buchungen sind nicht rekonstruierbar. Fremde Events sind reine Beobachtung; ihre Speicherung ist kein Bestandteil der fremden Geldtransaktion.

## Installation / Start

1. `migrations/001_banking.sql` in derselben MariaDB wie ESX importieren. Sie erstellt nur zwei neue Tabellen, verändert keine vorhandenen Salden und ist wiederholbar.
2. NUI bauen: `npm run ui:build`.
3. Nach `oxmysql`, `ox_lib`, `es_extended`, `rp_core`, `rp_ui` starten. Beide Konfigurationen enthalten bereits:

```cfg
add_ace resource.rp_banking command.save allow
ensure rp_banking
```

Die ACE erlaubt ausschließlich den vorhandenen ESX-Speicherbefehl. Sie erteilt Spielern keine Adminrechte. Die Resource wartet auf die offizielle Speicherbestätigung und liest anschließend die gespeicherten Konten zur Prüfung; sie schreibt nicht selbst in `users`.

Bei einer anderen Datenbank als der lokalen Projektinstanz die Migration dort ebenfalls importieren. Beim erstmaligen Aktivieren ist ein vollständiger Serverneustart inklusive aktualisierter NUI sinnvoll. `npm run check:runtime` kontrolliert Resource und Startreihenfolge.

## Automaten und Gestaltung

`shared/locations.lua` enthält 70 Standorte aus der offiziellen ESX-Konfiguration. Es werden die vorhandenen GTA-Mapobjekte benutzt, keine doppelten Automaten gespawnt. Optional kurze Karten-Blips (Sprite 277). Der Client findet passende Modelle nur in der Nähe konfigurierte Standorte; der Server prüft unabhängig den konfigurierten Standort, Routing-Bucket, lebenden Charakter und Entfernung.

Die Standardzuordnung in `shared/config.lua` orientiert sich an den sichtbaren Gerätefarben:

| GTA-Modell | Oberfläche |
| --- | --- |
| `prop_fleeca_atm` | Fleeca, grün |
| `prop_atm_01`, `prop_atm_02` | Liberty, blau |
| `prop_atm_03` | Maze Bank, rot |

Die generischen `prop_atm_*` haben nicht überall eine eindeutige Bankbeschriftung. Diese Zuordnung ist unsere Designkonfiguration, keine Behauptung über einen verbindlichen GTA-Bankbetreiber. Retextures/MLOs bei Bedarf gezielt überschreiben:

```lua
-- In Banking.Config; Schlüssel = Index in shared/locations.lua.
overrides = { [1] = 'maze', [2] = 'fleeca' },
```

Neue ATM-Koordinaten in `shared/locations.lua` ergänzen; bei Instanzen `bucket` setzen. Neue Modelle zusätzlich in `Config.models` erlauben. Ein Client-Modellhinweis beeinflusst ausschließlich die Optik, niemals Konten oder Zugriff. Nicht konfigurierte fremde Mapobjekte gewähren keinen Zugriff.

Standard: Interaktion 1,5 m, Serverprüfung 3 m, Sitzung 5 Minuten, Empfängerfreigabe 90 Sekunden, maximal $1.000.000 je Buchung, zulässiger Zielsaldo $2.000.000.000. Verlauf wird mit 20 Einträgen pro Seite nachgeladen. `historyLimit` bei Änderung auch im TypeScript-Vertrag anpassen. Erkennung läuft entfernt alle 1.000 ms, am Automaten alle 250 ms; keine Dauerabfrage von Geld oder Datenbank, keine eigenen Entities/Kameras.

## Buchungssicherheit und Wiederherstellung

Serverseitige Betrags-/Typ-/Entfernungs-/Sitzungsprüfungen, Limits, Sperren für beide Charaktere und eindeutige Request-IDs verhindern parallele ATM-Buchungen und wiederholtes Abbuchen derselben Anfrage. Nach jedem SQL-Warten vor der Geldbewegung werden Sitzung und Guthaben erneut geprüft. Zwischen Debit und Credit gibt es kein eigenes Yield. Geld wird niemals aus dem NUI-Saldo übernommen.

Vor einer Änderung wird ein dauerhafter Buchungsauftrag angelegt. Erst nach ESX-Speicherbestätigung und Prüfung der gespeicherten Konten werden Auftrag und beide Verlaufseinträge zusammen abgeschlossen. Unklare Ergebnisse bleiben als `intent`/`review` bestehen, auch nach Resource-/Serverneustart. Weitere ATM-Buchungen der betroffenen Charaktere werden gesperrt; keine automatische Wiederholung oder pauschale Erstattung.

**Grenze:** Unverändertes ESX hat keine gemeinsame SQL-Transaktion für zwei xPlayer-Konten und dieses Journal. Ein harter Prozess-/DB-Ausfall zwischen Speichervorgängen kann deshalb eine administrative Abstimmung erfordern. Fremde ESX-Scripts teilen unsere Sperren nicht. Das Journal ist eine nachvollziehbare Prüfbasis, kein Ersatz für ESX und keine Garantie für beliebige andere Geldscripts.

Nur Server-/txAdmin-Konsole:

```text
rp_bank_pending
rp_bank_review <Buchungs-ID> completed <Prüfvermerk mit mindestens 8 Zeichen>
rp_bank_review <Buchungs-ID> cancelled <Prüfvermerk mit mindestens 8 Zeichen>
```

`pending` zeigt maximal 20 offene Aufträge. Vor einer Freigabe `payload.before`/`payload.after`, ESX-Speicherstände, Logs und gegebenenfalls weitere zwischenzeitliche Buchungen prüfen. `completed` bestätigt eine nachgewiesene vollständige Buchung und ergänzt fehlende Belege. `cancelled` ist für nachgewiesen nicht ausgeführte bzw. bereits abgeglichene Aufträge. **Beide Befehle bewegen kein Geld.** Teilweise ausgeführte Überweisungen zuerst kontrolliert über ESX-Adminfunktionen berichtigen und speichern; erst danach mit nachvollziehbarem Vermerk auflösen. Nicht einfach offene Zeilen löschen. Die Resource loggt Buchungs-ID/Request-ID bei Unklarheiten.

## Vorschau und Prüfung

`npm run ui:preview` → **Geldautomat · Fleeca / Maze Bank / Liberty**. Direkt: `/?view=banking`, `/?view=atm-maze`, `/?view=atm-liberty`. Die Vorschau simuliert Transaktionen lokal und verändert keine Spielerdaten. Layout: `rp_ui/web/src/views/Banking.tsx`, `banking.css`; Farben gemeinsam in `design.css`.

```text
npm run check
npm run ui:build
npm run check:runtime
python tests/banking-database.py
python tests/banking-ui.py
```

`tests/banking.lua` benötigt Lua 5.4, alternativ Python `lupa.lua54`. Datenbanktest benötigt Docker-Projekt-DB, `pymysql` und `lupa`; er nutzt ausschließlich zufällig benannte Testtabellen und räumt diese auf. UI-Test benötigt Playwright/Chrome und Vite auf Port 5173. Abgedeckt: Geldfluss, Replay, parallele Anfragen, fremde Charaktere/ID-Recycling, Positionswechsel, Speicherausfall, verlorene SQL-Antwort, dauerhafte Sperren, Migration/Constraints, Verlauf sowie Browserbedienung bis 4K/Ultrawide. ATM-Animation, reale Mapobjekte und ESX-FiveM-Ereignisse müssen zusätzlich im Spiel geprüft werden.
