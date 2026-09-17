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
5. Importiere `server-data/resources/[custom]/rp_characters/migrations/001_create_characters.sql`.
6. Prüfe die lokale Installation mit `npm run check:runtime` und starte FXServer mit `+exec server.cfg` aus dem Ordner `server-data`.

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

```bash
npm run resource:new -- rp_vehicles
npm run ui:dev
npm run ui:build
npm run check
npm run check:runtime
```

Der Resource-Generator akzeptiert ausschließlich Namen im Format `rp_name` und erzeugt ein Manifest sowie getrennte Client-, Server- und Shared-Dateien.

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

## Leitidee

Das Repository bleibt **ein Projekt**, aber FiveM startet mehrere **deploybare Domain-Module**. Damit kannst du einzelne Systeme neu starten und sauber testen, ohne in 100 Mini-Resources oder einem unwartbaren Monolithen zu enden.


## Server starten

```bash
docker compose up -d db

Set-Location C:\Users\HighEndGamingPCUkrai\Desktop\fivem-esx-starter\server-data
..\server\FXServer.exe +exec server.cfg
```
