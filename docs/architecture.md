# Architektur

## Grenzen

Alle eigenen Oberflächen folgen dem [verbindlichen UI-Standard](ui-design.md), zentral definiert in `rp_ui/web/src/design.css`. Layouts bleiben bei ihrer jeweiligen Ansicht; gemeinsame Icons und visuelle Zustände werden wiederverwendet.

Das Git-Repository ist ein Monorepo. Die Laufzeitgrenzen bleiben FiveM-Resources.

```text
ESX Legacy + ox_lib + oxmysql
              |
           rp_core
              |
    +---------+---------+
    |         |         |
  jobs     vehicles   housing    weitere Domains
    |         |         |
    +---------+---------+
              |
            rp_ui
              |
       React + TypeScript
```

`rp_core` besitzt technische, domain-unabhängige Primitive. Eine fachliche Regel wie Fahrzeugbesitz gehört dagegen in `rp_vehicles`, nicht in den Core.

## Resource-Größe

Eine Resource entspricht einer stabilen fachlichen Domäne. Gute Beispiele sind:

- `rp_characters`
- `rp_jobs`
- `rp_factions`
- `rp_vehicles`
- `rp_housing`
- `rp_businesses`
- `rp_crime`
- `rp_admin`

Unterfunktionen bleiben Dateien oder Module innerhalb der Resource. Police-Handschellen, Asservaten und Dienstgarage müssen nicht jeweils eigene Resources werden.

## Kommunikation

| Bedarf | Mechanismus | Beispiel |
| --- | --- | --- |
| synchrone Fähigkeit | Export / ESX API | `xPlayer.getInventoryItem(name)` |
| Request/Response | ox_lib Callback | Fahrzeugliste laden |
| eingetretenes Ereignis | Event | Charakter wurde geladen |
| UI öffnen/aktualisieren | `rp_ui` Event oder Export | Garage anzeigen |
| UI-Aktion | NUI Callback, danach Server-Validierung | Fahrzeug anfordern |

NetEvents sind keine Berechtigungsgrenze. Jeder vom Client erreichbare Handler validiert seinen gesamten Kontext serverseitig.

## Startreihenfolge

1. `spawnmanager`, `baseevents`
2. `oxmysql`, `ox_lib`
3. `esx_lib`, `es_extended`, `skinchanger` (zusammenpassende ESX-Version)
4. `rp_core`
5. `rp_ui`, danach `rp_nativeui` (wiederverwendbare Client-Menü-API)
6. `rp_inventory`
7. `cron`, `esx_addonaccount`, `esx_addoninventory`, `esx_datastore`, `esx_society`
8. `rp_characters`
9. `rp_player`
10. `rp_organizations`
11. `rp_commerce`
12. weitere `rp_`-Resources in Abhängigkeitsreihenfolge

Jede Resource deklariert ihre direkten Abhängigkeiten zusätzlich im `fxmanifest.lua`.

`rp_inventory` muss vor `esx_addoninventory` starten: Das unveränderte ESX-Addon ruft beim Start `exports.ox_inventory:RegisterStash` auf. Unser Provider registriert diese Lagerdefinitionen; die jeweilige Serverdomain muss vor dem Öffnen einen festen Standort anbinden. Ohne Standort bleibt der Zugriff gesperrt.

`rp_characters` ersetzt den Multicharacter-Einstieg über `provide 'esx_multicharacter'`. Ablauf: Account laden → automatische Auswahl oder Creator/Kameraauswahl → serverseitig besessenen Slot bestimmen → lokales `esx:onPlayerJoined` → ESX-Datenbank-Load → `esx:playerLoaded` → `skinchanger:loadSkin`/Spawn → serverseitige Spawnprüfung → private Dimension verlassen. `rp_core` aktiviert keinen eigenen Auto-Spawn. Die Fremdresources werden nicht gepatcht.

`rp_ui` stellt die generischen lokalen Exporte `rpOpen`, `rpClose` und `rpRegisterAction` bereit. Domain-Resources registrieren ihre Aktionen selbst; die UI hängt nicht von ihnen ab. Registrierungen sind an die aufrufende Resource gebunden und werden beim Stop deaktiviert. Jede NUI-Aktion antwortet auch bei Fehlern oder Timeout. Eine gesperrte Login-Ansicht kann nur ihre besitzende Domain schließen. `ui:ready` stellt frühe Nachrichten nach Browserinitialisierung erneut zu.

## Datenbank

`rp_commerce` besitzt Shopangebote, Rezepte, Standort-/Jobrechte und das Bestelljournal. Shopdefinitionen unterstützen das offizielle `esx_shops`-Zonenformat; Konten bleiben bei ESX. Der Inventarprovider ergänzt `rpExchange` für atomare Material-/Ergebnisbuchungen. Unklare Zahlungszustände werden zur Prüfung gehalten; bestätigte Zahlungen sind über dauerhafte Belege ohne doppelte Lieferung fortsetzbar. UI bleibt in `rp_ui`, E im eigenen Inputkatalog. [Vertrag und Wiederherstellung](../server-data/resources/%5Bcustom%5D/rp_commerce/README.md).

Ammu-Nation erweitert dieselbe Commerce-Domain um persistente, revisionsgeschützte Shopdefinitionen, einen servervalidierten Admin-Editor und lokale gestreamte NPC-/Waffenszenen. Die Kamera reagiert auf den `onHighlight`-Callback von `rp_nativeui`; Käufe nutzen unverändert das vorhandene Bestelljournal. Der optionale Lizenzadapter verwendet `esx_license:checkLicense`. Zubehör gehört als Item und danach als atomar montierte Waffenmetadaten in den Inventarprovider. `rp_core` schützt ausdrücklich registrierte lokale Verkäufer vor Ambient-Cleanup, ohne von Commerce abhängig zu werden. [Bedienung, Konfiguration und Grenzen](weaponshops.md).

`rp_inventory` implementiert die offizielle ESX-Custom-Inventory-Brücke über `provide 'ox_inventory'`, ohne die Vendor-Resource zu ändern. Dauerhafte Spieler-/Containerbestände liegen in `rp_inventory_stores`; ESXs `users.inventory` ist der Save-Mirror. Änderungen verwenden SQL-Revisionen und Replay-Belege. Bodenitems sind ausschließlich RAM-Zustand mit exklusiven Aufhebereservierungen und 30 Minuten Lebensdauer; sie werden nicht als Container gespeichert. Munition ist regulärer Inventarbestand und wird automatisch in magazingroßen Paketen vorgebucht; innerhalb eines Pakets keine Schuss-RPCs/SQL-Buchungen. Zeitversetzte RAM-Audits und begrenzte bezahlte Schadensbudgets ergänzen die Synchronisierung. Kein zweiter Inventarprovider, keine Mengenänderung außerhalb der API. Geld bleibt mit `set inventory:accounts "[]"` bei ESX. [Vertrag, Grenzen und Migration](../server-data/resources/%5Bcustom%5D/rp_inventory/README.md).

`rp_organizations` erweitert offizielle ESX-Jobs und Societies um die zentrale React-Verwaltung. ESX bleibt Eigentümer des primären Jobs und der Konten; zusätzliche Fraktionen verwenden den vollen Character-Identifier. Keine eigenen parallelen Geld- oder Jobkopien. Integrationsgrenzen und Installationspins: [Organisationen](../server-data/resources/%5Bcustom%5D/rp_organizations/README.md). Die verbindlichen ESX-Kompatibilitätsregeln im Root-`AGENTS.md` gelten für jede Aufgabe.

`rp_core` verwaltet zusätzlich den zentralen Eingabekatalog mit Client-KVP und unterdrückt NPC-/Verkehrspopulation. `rp_ui` besitzt das Settings-Menü; `rp_player` besitzt Profilabfragen und serverseitige Fitnessprogression. Das persönliche Menü bleibt eine React-Ansicht in `rp_ui`; es erzeugt keine Abhängigkeit von UI zu Domain. Verträge und Erweiterungsbeispiel: [Spieler und Eingaben](player-and-input.md).

Jede Domain besitzt ihre Tabellen und Migrationen. Fremdschlüssel werden bewusst eingesetzt, sofern der Lebenszyklus eindeutig ist. Abfragen sind parameterisiert und Datenbankzeilen werden nicht ungefiltert an Clients weitergegeben.
