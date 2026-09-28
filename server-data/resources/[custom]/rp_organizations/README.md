# rp_organizations — ESX-Berufe und zusätzliche Fraktionen

Verwaltung unter **M → Organisationen**, alternativ `/rp_organizations`. Browser: `npm run ui:preview`, Eintrag **Organisationen**, oder `http://127.0.0.1:5173/?view=organizations`. Der Browser verwendet ausschließlich simulierte Admin-Demodaten.

## Bedienung und Rechte

- Jeder Charakter sieht seinen ESX-Beruf, Ränge, Dienststatus und eigene zusätzliche Fraktionen.
- ESX-Jobleiter (`grade_name == 'boss'`) verwalten ihren Beruf: arbeitslose, verbundene Charaktere im selben Routing-Bucket innerhalb von acht Metern aufnehmen; niedrigere Ränge befördern/entlassen; deren Rangbezeichnung und Gehalt ändern. Keine Selbstbeförderung oder Vergabe gleichrangiger/höherer Rechte.
- Fraktionsleiter verwalten ihre zusätzliche Fraktion mit den festen Rängen Mitglied (0), Stellvertretung (1), Leitung (2). Untergeordnete Mitglieder können auch offline verwaltet werden. Administratoren vergeben Leitungsrechte.
- Administratoren mit ACE `rp.organizations.admin` sehen alle Organisationen, legen Berufe/Fraktionen und weitere Jobränge an, benennen sie um und vergeben Mitgliedschaften. Kein Lösch-Endpunkt für Organisationen oder Charaktere.
- Jobänderungen betreffen ausschließlich geladene Charaktere über `xPlayer.setJob`. Offline-Jobmitglieder sind sichtbar, aber nicht editierbar. Keine direkten `users`-Updates hinter dem Rücken von ESX.
- Bargeld ↔ Gemeinschaftskonto ist nur für den Leiter seines **aktiven eigenen ESX-Jobs** verfügbar. Auch Administratoren erhalten keine beliebige Entnahme aus fremden Konten.

Die UI bestätigt Aufnahme, Rangwechsel, Entfernung und Geldtransfers. Der Server prüft alle Rechte erneut; NUI-Felder verleihen keine Berechtigungen. Mitgliederaktionen verwenden kurzlebige, pro Sitzung/Organisation gebundene Referenzen. Character-Identifier verlassen den Server nicht. Server-IDs in der Aufnahmeliste sind nur Zielhinweise; aktueller Charakter und Entfernung werden serverseitig geprüft.

## ESX-Vertrag und Grenzen

Geprüft gegen **ESX Legacy 1.15.2** und die unten fixierten offiziellen Addons:

| Zustand | Zuständigkeit |
| --- | --- |
| Primärer Beruf, Rang, Gehalt | `jobs`, `job_grades`, `xPlayer.getJob/setJob`, `ESX.RefreshJob` |
| Geladener Job, Konten und Inventar | ESX-xPlayer, reguläre ESX-Events und Speicherung |
| Dienststatus | `xPlayer.setJob(name, grade, onDuty)` und ESX-Metadaten |
| Gemeinschaftsgeld | `esx_society` + `esx_addonaccount`, `society_<job>` |
| Lagerdefinitionen und Zusatzdaten | `esx_addoninventory` registriert Stashes bei `rp_inventory`; `esx_datastore` bleibt für Zusatzdaten |
| Zusätzliche Mitgliedschaften | `rp_factions`, `rp_faction_members`, voller Character-Identifier |
| Verwaltungsprotokoll | `rp_organization_audit`, nur serverseitig |

`esx_society` und Addons bleiben unverändert. Bestehende Jobs werden als Societies registriert, sofern noch keine Registrierung existiert. Standard-Jobnamen und der Leiter-Rangname `boss` bleiben erhalten. Fremdskripte benötigen weiterhin ihre eigenen passenden Job-/Society-Konfigurationen. Im offiziellen Custom-Inventory-Modus verwendet `esx_addoninventory` ausschließlich `RegisterStash`; seine klassischen Item-Cache-Events sind dann nicht aktiv. Lagerstandorte und Öffnen müssen über die dokumentierte `rp_inventory`-Anbindung ergänzt werden.

ESX besitzt einen primären Job. Zusätzliche Fraktionen sind eine Erweiterung, kein konkurrierendes `job2`. Skripte, die ausschließlich `xPlayer.job` prüfen, erkennen zusätzliche Mitgliedschaften nicht automatisch. Für klassische ESX-Polizei-/Mechaniker-/Gangskripte die Organisation als **Beruf / Dienststelle** anlegen. Für sekundäre Gruppen die unten dokumentierten Serverexports verwenden.

Nach Online-Job-/Geldänderungen wird ESXs offizieller Console-Befehl `save <serverId>` aufgerufen. In 1.15.2 ist `Core.SavePlayer` privat; ein erfundenes `ESX.SavePlayer` wird nicht verwendet. Normale ESX-Autosaves und Disconnect-Speicherung bleiben bestehen. Geldbewegungen nutzen Standard-Account-APIs; damit gelten deren asynchrone Persistenzgrenzen bei abruptem Server-/Datenbankausfall.

Neue Jobs/Ränge sind nach `ESX.RefreshJob` sofort verwendbar. **Neue Gemeinschaftskonten und Lager werden beim nächsten vollständigen Serverstart in die offiziellen Addon-Caches geladen.** Vorher bleibt die Kontoaktion deaktiviert. Aktive Kontocaches werden nicht global neu geladen, um laufende Kontobewegungen zu erhalten. Eine Lager-, Garagen- oder Dienstkleidungsoberfläche ist hier nicht enthalten.

## Installation

1. ESX Legacy 1.15.2 mit zugehörigem `esx_lib` installieren.
2. `powershell -ExecutionPolicy Bypass -File tools/install-esx-organizations.ps1` aus dem Repository-Root ausführen. Bestehende Ressourcen werden nicht überschrieben. Ignorierte Git-Checkouts dienen als Installationscache.
3. `migrations/001_organizations.sql` nach dem ESX-Schema importieren. Sie legt Standard-Addon- und eigene Tabellen additiv an und provisioniert fehlende Gesellschaftskonten. Vorhandenes Geld und Mitgliedschaften bleiben erhalten. Wiederholbar; vorhandene inkompatible Fremdschemata benötigen separate Prüfung.
4. Startreihenfolge/ACL aus `server.cfg.example` übernehmen, NUI bauen und FXServer vollständig neu starten.

Reihenfolge: `oxmysql`, `ox_lib`, `esx_lib`, `es_extended`, `skinchanger`, `rp_core`, `rp_ui`, `rp_inventory`; danach `cron`, `esx_addonaccount`, `esx_addoninventory`, `esx_datastore`, `esx_society`, `rp_characters`, `rp_player`, `rp_organizations`. Der Inventarprovider muss vor der Lagerregistrierung des Addons starten. Die vollständige Reihenfolge steht in der Root-Konfiguration.

```cfg
add_ace resource.rp_organizations command.save allow
add_ace group.admin rp.organizations.admin allow
ensure rp_organizations
```

Die ACL verleiht bereits zugewiesenen ESX-/ACE-Administratoren Zugriff; sie macht keinen normalen Spieler zum Administrator. Ein zusätzlicher Betreiberzugriff kann gezielt über eine bekannte ACE-Principal vergeben werden. Account-Lizenzen und Secrets gehören nicht ins Repository.

Pins: [`ESX-Legacy-Addons` ccda737](https://github.com/esx-framework/ESX-Legacy-Addons/tree/ccda737f7d4f73d224fab2097bee5083afd4dd4e) für `esx_society`, `esx_addonaccount`, `esx_addoninventory`, `esx_datastore`; [`esx_core` 1.15.2 / ddd71a5](https://github.com/esx-framework/esx_core/tree/ddd71a58f1ea6279d68413fb4a44e0ef34ede2fa) für `cron`. Keine Vendor-Dateien werden durch die eigene Resource gepatcht.

## Konfiguration und Schnittstellen

`shared/config.lua`: maximal drei zusätzliche Fraktionen je Charakter; acht Meter Aufnahmeentfernung; 750 ms Mutations-Cooldown; Gehalt bis 3.500 $; Einzeltransfer bis 100.000 $; bis zu 200 gespeicherte Mitglieder zuzüglich ggf. weiterer geladener Mitglieder. Für höhere Gehaltsgrenzen zusätzlich Oberfläche und Standard-Society-Konfiguration abstimmen. Views: 200 ms Cooldown; pro Spieler eine Anfrage gleichzeitig; Mutationen innerhalb dieser Resource serialisiert. Andere ESX-Skripte bleiben eigenständige Schreiber.

Servercallback `rp_organizations:request`: `view`, `create`, `rename`, `addGrade`, `hire`, `promote`, `fire`, `grade`, `duty`, `deposit`, `withdraw`. Auswahl über `kind: job|faction` und interne `name`; keine frei wählbare Actor-ID. Lokale NUI-Aktionen `rp_organizations:open` aus M sowie `rp_organizations:request` aus der Organisationsansicht werden über `rp_ui:rpRegisterAction` registriert. Payloadvalidierung: `rp_ui/web/src/lib/organizations.ts`, Routing/Antworten im zentralen `lib/nui.ts`.

Server-only:

```lua
local player = ESX.GetPlayerFromId(source)
if not player then return end
local memberships = exports.rp_organizations:rpGetMemberships(player.identifier)
local isLeader = exports.rp_organizations:rpHasFaction(player.identifier, 'lost', 2)
```

Die Exporte warten auf die Datenbank. Niemals clientgelieferte Identifier als Identitätsbeweis verwenden. Serverlokales Ereignis `rp_organizations:membershipChanged(identifier, faction, gradeOrNil)` meldet abgeschlossene Änderungen; `nil` bedeutet Entfernung. Kein Netzwerk-Endpunkt.

## Verifikation

```text
npm run check
npm run ui:build
npm run check:runtime
lua5.4 tests/organizations.lua
lua5.4 tests/characters.lua
lua5.4 tests/player-profile.lua
python tests/esx-character-isolation.py
python tests/organizations-ui.py
```

Lua-Tests simulieren FiveM/SQL und prüfen Rollen, Zielbesitz, Rangregeln, Abstände/Buckets, Beträge, Sperren, Rechteentzug, Disconnects und Charaktertrennung. Der SQL-Test führt die **installierte originale `Core.SavePlayer`-Funktion** mit kontrollierten Spielern aus und prüft deren Abfrage in temporären MariaDB-Tabellen; ebenso die echten Fraktionsabfragen und Limits. Benötigt Python/lupa, lokale ESX-Dateien und Docker-MariaDB. Browserprüfung: Playwright/Chrome und Vite, HD/4K, M-Menü, Rang-/Mitgliedsänderungen, Bestätigungen und Rechteanzeige.

Noch im FiveM-Client prüfen: kompletter Neustart mit Addons, Leiter-/Adminzugriff, zwei reale Spieler für Aufnahme/Rangwechsel, Kontoübertragungen/Reconnect und zwei nacheinander gespielte Charaktere eines Accounts. Automatisierte Doubles ersetzen diese Laufzeitprüfung nicht.
