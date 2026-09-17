# Projektstand und Join-Diagnose — 17.09.2026

## Ziel und aktueller Umfang

Ziel laut `AGENTS.md`: ein produktionsfähiger ESX-Legacy-RP-Server mit serverautoritativem Lua, zentraler React-/TypeScript-NUI und Domain-Resources in einem Monorepo. Der aktuelle Stand ist ein Starter mit drei eigenen Resources:

| Bereich | Vorhanden | Noch offen |
| --- | --- | --- |
| `rp_core` | ESX-Exports, Zeit-Callback, Basiskonfiguration | Weitere gemeinsame Verträge nach Bedarf |
| `rp_ui` | React/TypeScript, Browser-Vorschau, NUI-Brücke, Demo und Charakteransicht | Fehlerbehandlung und verlässliche Antworten in allen Callback-Pfaden |
| `rp_characters` | Tabelle/Migration, Liste, Anlage, Besitzprüfung bei Auswahl, Rate-Limit | Tatsächlicher ESX-Charakterwechsel, Login-Integration, Persistenz der Auswahl, Nebenläufigkeitsschutz |
| Tooling | Resource-Generator, Lua-Syntaxprüfung, TypeScript-Prüfung, CI und UI-Build | Automatisierte Laufzeittests der Spielabläufe |
| Gameplay | ESX-Basis | Eigene Jobs, Fahrzeuge, Inventar, Housing und weitere RP-Systeme sind nicht implementiert |

Die Lua-Prüfung verwendet `luaparse` im Lua-5.3-Modus. Sie prüft Syntax, aber keine FiveM-Natives, Exports, Datenbankzustände oder vollständige Lua-5.4-Kompatibilität. Erfolgreiche statische Checks belegen deshalb keinen erfolgreichen Join.

## Ursache von „Awaiting scripts“

Lokal ist ESX `1.15.2` installiert. In `es_extended/client/functions.lua` wartet `ESX.SpawnPlayer` auf den Callback von `skinchanger:loadSkin`. In `es_extended/client/modules/events.lua` werden erst danach `ShutdownLoadingScreen`, `ShutdownLoadingScreenNui` und der Fade-In erreicht.

`skinchanger` fehlte sowohl im Resource-Verzeichnis als auch in der laufenden Ressourcenliste und der lokalen Startkonfiguration. Die Client-Logs vom 17.09.2026 bestätigen die übrigen gestarteten Resources. Ohne Handler wird das Spawn-Promise nicht aufgelöst; dieser Pfad erklärt den dauerhaften Ladebildschirm auch ohne Lua-Fehlermeldung.

Zusätzlich aktivierte `rp_core` den Auto-Spawn von `spawnmanager`, während ESX diesen beim Login deaktiviert. Dieser konkurrierende Spawn wurde entfernt. ESX lädt nun allein die gespeicherte Position beziehungsweise seinen konfigurierten Standardspawn.

## Änderungen

- Offiziellen `skinchanger` aus [ESX 1.15.2](https://github.com/esx-framework/esx_core/releases/tag/1.15.2) lokal unter `[esx]/skinchanger` installiert. Quelle: Commit `ddd71a58f1ea6279d68413fb4a44e0ef34ede2fa`, Unterordner `[core]/skinchanger`; alle 20 Dateien gegen die Git-Blob-Hashes geprüft. Die Fremdresource bleibt wie die anderen Dependencies git-ignoriert.
- Lokale `server.cfg` und Beispielkonfiguration um die notwendigen Starts ergänzt; `rp_core` deklariert `skinchanger` als Abhängigkeit.
- `@oxmysql/lib/MySQL.lua` im Manifest von `rp_characters` ergänzt. Eine Abhängigkeit auf `oxmysql` allein erzeugt keine `MySQL`-Variable im Lua-Kontext einer anderen Resource.
- Statische Resource-Prüfung erkennt die fehlende MySQL-Einbindung künftig. `npm run check:runtime` prüft lokale Pflichtresources, die explizite Reihenfolge aus `server.cfg` und den gebauten NUI-Einstieg. Es liest keine Datenbankdaten und zeigt keine Zugangsdaten an. Der Check ist für die direkte Starter-Konfiguration gedacht; ausgelagerte `exec`-Dateien werden nicht aufgelöst.

## Weitere Findings, noch nicht behoben

1. **Charakterauswahl ist keine ESX-Multicharacter-Lösung.** Die API benötigt bereits einen geladenen ESX-Spieler. `select` schreibt nur in `selectedCharacters`; Identität, Konten und Inventar bleiben beim bestehenden ESX-Spieler. Kein automatischer Auswahlbildschirm beim Join. Vor einer Login-Integration muss der gewünschte Single-/Multicharacter-Lebenszyklus implementiert werden.
2. **Nebenläufigkeit bei Charakteranlage:** `COUNT` und `INSERT` laufen getrennt, ohne Sperre oder transaktionale Slotvergabe. Ein Zeitlimit ersetzt keinen Schutz vor überlappenden Requests. Nach Datenbank-Wartezeiten fehlt außerdem eine Prüfung, ob dieselbe Spielersitzung noch existiert.
3. **Feldvalidierung:** Datumsprüfung akzeptiert unmögliche Kalendertage; Namen verwenden eine ASCII-orientierte Prüfung. Das SQL-`DATE` wird ohne explizites Ausgabeformat gelesen, während TypeScript eine Zeichenkette erwartet. Die Namenslängen der eigenen Tabelle (32) und der lokalen ESX-`users`-Tabelle (16) unterscheiden sich und müssen vor einer Integration abgestimmt werden.
4. **UI-Fehlerpfade:** Export-/Callback-Fehler können NUI-Antworten verhindern. React fängt Fehler bei Anlage/Auswahl nicht ab; `event.currentTarget.reset()` wird nach einem `await` aufgerufen und sollte das Formular vorher sichern. Serverantworten werden außerhalb der Message-Validierung nur typisiert, nicht vollständig zur Laufzeit geprüft.
5. **Architektur und öffentliche APIs:** `rp_ui` hängt für die Callback-Brücke noch von `rp_characters` ab. `/characters` und generische Exportnamen entsprechen noch nicht durchgängig der geforderten Namenskonvention. Kein Zyklus vorhanden, aber die Brücke sollte vor dem Ausbau korrigiert werden.

## Verifikation und nächster Live-Test

FXServer läuft lokal; MariaDB im Docker-Compose-Dienst ist gesund. Lesend geprüft: ESX-Tabellen einschließlich `users`, `jobs`, `job_grades` sowie `rp_characters` existieren, der Standardjob `unemployed` mit Grade `0` ist vorhanden. Keine Datenbankdaten wurden geändert.

Nach den Änderungen erfolgreich ausgeführt: `npm run check`, `npm run ui:build` und `npm run check:runtime`; `web/dist/index.html` ist vorhanden. `git diff --check` meldet keine Whitespace-Fehler. Die HTTP-Ressourcenliste des noch laufenden FXServers enthält `skinchanger` weiterhin nicht: geänderte Lua-Dateien und `server.cfg` werden nicht automatisch übernommen. Für den Join-Test den Server geordnet neu starten und neu verbinden; ein bereits wartender ESX-Spawn wird durch die spätere Installation von `skinchanger` nicht nachträglich fortgesetzt.

Abnahme im FiveM-Client: Ladebildschirm verschwindet, Spieler erscheint an der gespeicherten beziehungsweise ESX-Standardposition und ist steuerbar, F8 zeigt keine Spawn-/Skin-Fehler. Anschließend `/rp_ui_demo` und nach dem Login `/characters` prüfen. Ein erfolgreicher echter Client-Join nach dem Neustart bleibt noch zu verifizieren.
