# Codex-Workflow

## Projekt öffnen

Starte Codex im Repository-Root. Dort wird `AGENTS.md` automatisch geladen. Der zusätzliche Projektagent liegt unter `.codex/agents/fivem-builder.toml` und heißt `fivem_builder`.

Zum Prüfen der geladenen Regeln:

```bash
codex --ask-for-approval never "Fasse die aktiven Projektanweisungen zusammen."
```

## Gute Aufgabenform

Eine gute Aufgabe nennt Domäne, Verhalten, Vertrauensgrenze und Abnahmekriterien:

```text
Nutze den fivem_builder-Agenten und implementiere rp_vehicles.

Spieler sollen ihre eigenen Fahrzeuge in einer Garage sehen und ausparken.
Der Client darf nur die Fahrzeug-ID senden. Der Server prüft Charakter,
Besitz, Garagenzustand und Position. Nutze oxmysql und eine Migration.
Die UI kommt als neue View in rp_ui. Fertig ist die Aufgabe, wenn die
statischen Checks und der NUI-Build erfolgreich sind.
```

Für Diagnose ohne Änderungen:

```text
Untersuche den Ablauf vom NUI-Klick bis zur Datenbank. Ändere keine Dateien.
Liste Sicherheitsprobleme nach Schweregrad mit konkreten Dateiverweisen auf.
```

## Kleine Iterationen

Baue ein System vertikal in kleinen Scheiben:

1. Datenmodell und Migration
2. serverseitiger Use Case
3. Client-Brücke
4. NUI-Ansicht
5. Fehlerfälle, Rate-Limit und Cleanup
6. Live-Test auf dem Entwicklungsserver

So kann Codex jeden Schritt überprüfen, statt gleichzeitig ein riesiges, schwer testbares System zu erzeugen.

## Was du Codex bereitstellen solltest

- aktuelle Fehlermeldung und relevante Server-/Client-Konsole
- erwartetes und tatsächliches Verhalten
- betroffene Resource und Reproduktionsschritte
- verwendete Versionen externer Resources
- bei UI-Problemen einen Screenshot und Browser-/NUI-Konsole

Secrets, Lizenzschlüssel und produktive Datenbank-Dumps gehören nicht in den Chat oder das Repository.
