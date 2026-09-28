# FiveM ESX Starter

Ein Codex-freundliches Monorepo für einen eigenen FiveM-RP-Server mit:

- ESX Legacy als Framework-Schicht
- Lua für Client-, Server- und Shared-Code
- ox_lib und oxmysql
- zentraler React-/TypeScript-NUI
- größeren Domain-Resources statt Resource-Kleinteiligkeit
- einem projektweiten `AGENTS.md` und dem Codex-Agenten `fivem_builder`
- reproduzierbaren npm-Abhängigkeiten und einer GitHub-Actions-CI

## Voraussetzungen

- aktueller FXServer/txAdmin
- Git
- Node.js 22 oder neuer und npm
- Docker mit Compose oder eine vorhandene MariaDB-Instanz
- ESX Legacy einschließlich `esx_lib` und `skinchanger`, ox_lib und oxmysql
- Cfx-Systemresources `spawnmanager` und `baseevents`

Die Fremd-Ressourcen werden bewusst nicht mitgeliefert. Installiere sie aus ihren offiziellen Repositories beziehungsweise über ein aktuelles txAdmin-Rezept, damit Updates nachvollziehbar bleiben.

Hilfreiche Referenzen: [Cfx Resource Manifests](https://docs.fivem.net/docs/scripting-reference/resource-manifest/), [Fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/) und [NUI Callbacks](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/).

## Schnellstart

```bash
cp .env.example .env
docker compose up -d db
npm install
npm run ui:build
cp server-data/server.cfg.example server-data/server.cfg
```

Danach:

1. Trage Datenbankpasswort, Servername, Lizenzschlüssel und Endpoints in `.env` beziehungsweise `server-data/server.cfg` ein.
2. Lege `es_extended` und `skinchanger` aus derselben ESX-Legacy-Version unter `server-data/resources/[esx]/` ab; `esx_lib` kommt unter `[core]/`.
3. Lege `ox_lib` und `oxmysql` unter `server-data/resources/[core]/` und die Cfx-Systemresources `spawnmanager` und `baseevents` unter `[system]/` ab.
4. Importiere die offiziellen ESX-SQL-Dateien in die Datenbank.
5. Importiere die Migrationen `001_create_characters.sql` und `002_account_characters.sql` unter `server-data/resources/[custom]/rp_characters/migrations/` in dieser Reihenfolge.
6. Importiere `001_player_progress.sql` unter `server-data/resources/[custom]/rp_player/migrations/` für die Fitnesswerte.
7. Installiere die offiziellen Organisations-Addons mit `powershell -ExecutionPolicy Bypass -File tools/install-esx-organizations.ps1` und importiere `rp_organizations/migrations/001_organizations.sql`. [Einrichtung und Berechtigungen](server-data/resources/%5Bcustom%5D/rp_organizations/README.md).
8. Importiere `rp_inventory/migrations/001_inventory.sql`. Die Beispielkonfiguration setzt `inventory:accounts "[]"` vor ESX und startet `rp_inventory` als einzigen Inventarprovider. [Inventar, Testitems und Integrationsgrenzen](server-data/resources/%5Bcustom%5D/rp_inventory/README.md).
9. Importiere `rp_commerce/migrations/001_orders.sql` für Shopbestellungen. `rp_commerce` nach den bisherigen Ressourcen starten und dessen `command.save`-ACE aus der Beispielkonfiguration übernehmen. [Testshop, Werkbank und ESX-Vertrag](server-data/resources/%5Bcustom%5D/rp_commerce/README.md).
10. Prüfe die lokale Installation mit `npm run check:runtime` und starte FXServer mit `+exec server.cfg` aus dem Ordner `server-data`. Ein Providerwechsel benötigt einen vollständigen Neustart.

`server.cfg` ist absichtlich ignoriert, damit Lizenzschlüssel und lokale Zugangsdaten nicht committed werden.

## Projektstruktur

```text
.
├── AGENTS.md                     Codex-Regeln für das gesamte Projekt
├── .codex/
│   ├── config.toml
│   └── agents/fivem-builder.toml spezialisierter Codex-Agent
├── docs/                         Architektur, Sicherheit, Codex-Workflow
├── templates/resource/           Vorlage für neue Lua-Resources
├── tools/                         Generator und statische Prüfungen
└── server-data/
    ├── server.cfg.example
    └── resources/
        ├── [core]/                ox_lib, oxmysql
        ├── [esx]/                 ESX Legacy Resources
        └── [custom]/
            ├── rp_core/
            └── rp_ui/
```

## Häufige Befehle

**Geldautomaten:** An konfigurierten GTA-Automaten **E** drücken; Ein-/Auszahlen, Überweisung an Online-Spieler und dauerhafter Kontoverlauf. Vor dem Start `rp_banking/migrations/001_banking.sql` importieren. Bankabhängige Fleeca-/Maze-/Liberty-Vorschauen im UI Studio. [Installation, Konfiguration und ESX-Vertrag](server-data/resources/%5Bcustom%5D/rp_banking/README.md).

Wiederverwendbare GTA-Interaktionsmenüs: **`/rp_nativeui_test`** im Spiel, **NativeUI** im Browser-Studio. [Client-API, Callbacks und Integrationsbeispiel](server-data/resources/%5Bcustom%5D/rp_nativeui/README.md). Die Resource startet nach `rp_ui`; sie benötigt keine Migration.

```bash
npm run resource:new -- rp_vehicles
npm run ui:dev
npm run ui:preview
npm run ui:build
npm run check
npm run check:runtime
```

Der Resource-Generator akzeptiert ausschließlich Namen im Format `rp_name` und erzeugt ein Manifest sowie getrennte Client-, Server- und Shared-Dateien.

## UI ohne FiveM bearbeiten

Im Projektordner `npm run ui:preview` starten. Der Browser öffnet automatisch [UI Studio](http://127.0.0.1:5173/); FXServer, FiveM und Datenbank müssen dafür nicht laufen. Falls Port 5173 schon vom UI-Devserver verwendet wird, einfach diese Adresse öffnen.

Links lassen sich Charakterauswahl, Creator, Charaktermenü, Einstellungen sowie Lade-/Fehleransichten ein- und ausblenden. Rechts ist die echte React-Oberfläche mit Demodaten bedienbar. Ein weiterer Klick auf den aktiven Eintrag blendet sie aus. Auflösungen, Hintergründe, Demo-Reset und „Einzeln öffnen“ helfen beim Testen. Änderungen an React-/CSS-Dateien erscheinen automatisch; links werden die passenden Quelldateien angezeigt. Beenden mit `Strg+C` im Terminal.

Details und Erweiterung: [UI Studio](docs/ui-studio.md).

## Mit Codex arbeiten

Öffne den Repository-Root in Codex. Codex liest das `AGENTS.md` automatisch. Gute Startaufgaben sind zum Beispiel:

```text
Nutze den fivem_builder-Agenten. Erstelle eine rp_garage-Resource mit
serverseitiger Besitzprüfung, oxmysql-Migration und einer Ansicht in rp_ui.
Führe danach alle Checks aus.
```

```text
Analysiere rp_jobs auf unsichere NetEvents. Ändere noch nichts, sondern
liefere zuerst konkrete Findings mit Dateiverweisen und einem Fixplan.
```

Mehr dazu steht in [`docs/codex-workflow.md`](docs/codex-workflow.md).

Den geprüften Projektstand, offene Anforderungen und die Diagnose zu „Awaiting scripts“ beschreibt [`docs/project-status.md`](docs/project-status.md).

**M** öffnet die Charakter-/Fitnessübersicht, **F12** die Einstellungen mit visueller Tastenbelegung, Konfliktbestätigung und Warnung bei unbelegten Aktionen. NPCs und Ambient-Verkehr sind deaktiviert. Bedienung, Grenzen, Konfiguration und Integration weiterer Spielaktionen: [`docs/player-and-input.md`](docs/player-and-input.md).

Der Charakterablauf unterstützt individuelle Accountlimits, einen Freemode-Creator mit Identität/Aussehen/Kleidung, automatische Einreise am Flughafen und die Rückkehr zum letzten gespeicherten Standort. Standardmäßig hat jeder Account einen Platz; weitere werden über den geschützten Serverbefehl `rp_character_slots` vergeben. Einrichtung und Bedienung: [`rp_characters`](server-data/resources/%5Bcustom%5D/rp_characters/README.md).

## Leitidee

**M → Organisationen** öffnet die ESX-Job-/Fraktionsverwaltung: Mitglieder, Ränge, Gehälter, Dienststatus und Gemeinschaftskonto. Administratoren legen Berufe und zusätzliche Fraktionen an. Vorschau im UI Studio über **Organisationen**. Datenverträge, Berechtigungen und Grenzen: [rp_organizations](server-data/resources/%5Bcustom%5D/rp_organizations/README.md). ESX-Standardkompatibilität ist in `AGENTS.md` als verpflichtende Regel für jede Aufgabe festgehalten.

Das Repository bleibt **ein Projekt**, aber FiveM startet mehrere **deploybare Domain-Module**. Damit kannst du einzelne Systeme neu starten und sauber testen, ohne in 100 Mini-Resources oder einem unwartbaren Monolithen zu enden.


## Server starten

```bash
docker compose up -d db

Set-Location C:\Users\HighEndGamingPCUkrai\Desktop\fivem-esx-starter\server-data
..\server\FXServer.exe +exec server.cfg
```
