# Architektur

## Grenzen

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
| synchrone Fähigkeit | Export | `exports.rp_inventory:HasItem(...)` |
| Request/Response | ox_lib Callback | Fahrzeugliste laden |
| eingetretenes Ereignis | Event | Charakter wurde geladen |
| UI öffnen/aktualisieren | `rp_ui` Event oder Export | Garage anzeigen |
| UI-Aktion | NUI Callback, danach Server-Validierung | Fahrzeug anfordern |

NetEvents sind keine Berechtigungsgrenze. Jeder vom Client erreichbare Handler validiert seinen gesamten Kontext serverseitig.

## Startreihenfolge

1. `oxmysql`
2. `ox_lib`
3. `es_extended`
4. offizielle beziehungsweise ausgewählte ESX-Resources
5. `rp_core`
6. `rp_ui`
7. weitere `rp_`-Resources

Jede Resource deklariert ihre direkten Abhängigkeiten zusätzlich im `fxmanifest.lua`.

## Datenbank

Jede Domain besitzt ihre Tabellen und Migrationen. Fremdschlüssel werden bewusst eingesetzt, sofern der Lebenszyklus eindeutig ist. Abfragen sind parameterisiert und Datenbankzeilen werden nicht ungefiltert an Clients weitergegeben.
