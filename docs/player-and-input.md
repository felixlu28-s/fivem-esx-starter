# Charakterübersicht, Eingaben und leere Spielwelt

## Bedienung

- **Menütasten sind Umschalter:** M schließt das offene Charaktermenü, I das Inventar, E Shop/Werkbank und die aktuelle Einstellungstaste schließt die Einstellungen. Nach Neubelegung gilt die neue Taste. Gedrückthalten löst kein mehrfaches Umschalten aus. Während Texteingaben bleiben die Zeichen im Eingabefeld; Escape bzw. Schließen bleiben verfügbar. Bei Einstellungen bricht die Menütaste zuerst eine aktive Neubelegung ab; Warnungen zu unbelegten Aktionen müssen weiterhin bestätigt werden. Linke/rechte Maustaste und Mausrad als Menübelegung schließen nur auf freier Hintergrundfläche, damit Buttons, Drag-and-drop und Scrollen nutzbar bleiben.

- Das [Ingame-HUD](hud.md) zeigt oben rechts Bargeld, Spielerzahl, deine Server-ID und Sprachstatus/Reichweite. Es erscheint automatisch nach dem Charakterlogin.

- **M** öffnet „Mein Charakter“ mit Identität, Beruf, Geld, Ausdauerlevel, gelaufener Strecke und Trainingszeit. **Escape** schließt das Menü. `rp_me` in der F8-Konsole bleibt als Zugriff ohne Tastaturbelegung verfügbar.
- **I** öffnet das Slotinventar einschließlich zugänglicher echter Behälter in der Nähe. Bodenitems werden mit **E** direkt aufgehoben: Hinweis mit Itemname, Menge und Aufhebetaste. Nur der sichtbare Kontext (Shop oder Bodenitem) reagiert. „Gegenstand aufheben“ ist separat unter F12 belegbar. `rp_inventory` öffnet das Inventar auch ohne belegte Taste. [Inventar](../server-data/resources/%5Bcustom%5D/rp_inventory/README.md).
- **F12** öffnet die Einstellungen. Dort sind ausschließlich eigene Systeme hinterlegt: „Mein Charakter“ (M), „Einstellungen“ (F12), „Inventar“ (I) und bei gestarteter `rp_commerce` „Shop / Werkbank öffnen“ (E). `rp_settings` in der F8-Konsole funktioniert auch bei entfernter Menütaste.
- Links stehen Aktionen samt Taste und Kontext, rechts eine deutsche Tastatur mit Navigation, Nummernblock und Maus. Ein Tastenklick wählt die zugehörige Aktion; weitere Klicks wechseln bei gemeinsam belegten Tasten durch deren Aktionen.
- „Neu belegen“ markiert freie Tasten grün und belegte orange. Eine freie Taste wird sofort gespeichert. Die Bestätigung für eine belegte Taste nennt **alle** bisherigen Aktionen, die dadurch unbelegt werden. Ein Klick auf die bereits zugewiesene Taste verändert gemeinsam genutzte Standardbelegungen nicht.
- Schließen über Escape, F12 oder das Kreuz verlangt bei unbelegten Aktionen eine Bestätigung. Im Neubelegungsmodus bricht Escape zuerst die Neubelegung ab. „Standard wiederherstellen“ setzt auch gemeinsam genutzte Tasten zurück.

## Speicherung und Grenzen

Belegungen liegen lokal im FiveM-KVP von `rp_core`, getrennt durch `setr rp_input_profile "fivem-esx-starter"`. Für unterschiedliche Serverprojekte unterschiedliche stabile Profilnamen verwenden. Die Belegung gilt für alle Charaktere auf diesem Client; sie wird nicht zwischen PCs synchronisiert. Bestätigungen tragen eine Revision; veraltete Änderungen werden mit der aktuellen Belegung abgewiesen.

Die Liste und die Belegungsfarben beziehen sich ausschließlich auf registrierte eigene Systeme. GTA-Funktionen wie Laufen, Springen, Fahren oder Schießen bleiben vollständig in den GTA-Einstellungen. Eine hier freie Taste kann deshalb weiterhin eine GTA-Funktion auslösen; die eigene Belegung verändert diese nicht. Escape, F8, Windows und AltGr sind reserviert. Nicht registrierte Fremdresource-Commands werden nicht automatisch umgeschrieben. Neue Projektinteraktionen werden über die folgende Registry angeschlossen.

`rp_core` löst ausschließlich lokale `inputPressed`-/`inputReleased`-Ereignisse für eigene Aktionen aus. Tastatureingaben verwenden die offizielle Ressourcen-API [RegisterKeyMapping](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/RegisterKeyMapping.md). Konsolenbefehle wie `rbind` sind im normalen FiveM-Produktionsmodus gesperrt und dürfen nicht als Script-API verwendet werden. Es ist kein Entwicklermodus nötig. Die bisherige Raw-Key-Abfrage wird ebenfalls nicht verwendet.

Beim Laden gespeicherter Belegungen, Neubelegen und Registrieren einer Aktion werden die benötigten `+rp_core_mapped_v3_*`-/`-rp_core_mapped_v3_*`-Handler angebunden. Pro verwendeter Tastaturtaste gibt es eine stabile native Zuordnung; die Zuordnung Taste → Projektaktion liegt weiterhin im F12-Menü/KVP. Das ist nötig, weil `RegisterKeyMapping` nur einen Standard setzt und bestehende native Spielerbelegungen nicht überschreibt. Neue Tasten bekommen ihre eigene Registrierung, vorhandene werden wiederverwendet. Alte Tasten führen nach Neubelegung nur noch Aktionen aus, die ihnen aktuell zugewiesen sind. Nach Reconnect bleiben die Zuordnungen erhalten. Die neue Command-Namensgebung trennt diese Registrierungen von früheren fehlerhaften Bindings; ein Löschen der FiveM-Konfiguration ist nicht nötig.

FiveM zeigt diese technischen Zuordnungen unter **Einstellungen → Tastenbelegung → FiveM → RP Eingabe: …** an und erlaubt dort eigene Änderungen. Projektaktionen bitte in unserem F12-Menü belegen: Ein zusätzliches Umbelegen der technischen Tasteneingänge im FiveM-Menü verändert die darunterliegende Taste und kann deshalb von unserer Tastaturanzeige abweichen. Dann dort den betroffenen Eingang wieder auf seine benannte Taste setzen. GTA-Einstellungen und fremde Bindings werden durch unser Script nicht verändert; `bind`, `rbind`, `unbind` und `unbindall` werden nie ausgeführt.

Maus/Mausrad behalten ihre Control-Abfrage. Im NUI, im tatsächlich geöffneten Pausemenü, ohne geladenen ESX-Charakter und bei ausgeblendetem Bildschirm werden keine Aktionen gestartet. Bereits gehaltene Aktionen werden bei Fokusverlust oder Neubelegung freigegeben. GTA-Bewegung und Controller-Eingaben werden nicht simuliert oder überschrieben. Neue Dependencies oder Änderungen an ESX sind nicht erforderlich.

Wenn Commands funktionieren, Tasten aber nicht: `rp_input_status` in F8 zeigt **`backend=keymapping-v3`**, empfangene Tastendrücke (`received`), ausgelöste Aktionen (`dispatched`), letzte Taste und gespeicherte Belegungen sowie ESX-Ladestatus, NUI-Fokus, Pause und Bildschirmblende. `rbind-v2` bedeutet, dass noch der vorherige fehlerhafte Stand geladen ist. F8 schließen, M/F12/I beziehungsweise E an einem Shop testen, dann F8 wieder öffnen und den Status prüfen. `rp_settings` öffnet weiterhin die Einstellungen zum Prüfen oder Zurücksetzen der Belegung. Nach dem Gameserver-Neustart erneut verbinden; Dateispeichern allein ersetzt kein bereits laufendes Clientscript.

## Neue Aktionen integrieren

Die Resource benötigt eine Abhängigkeit von `rp_core`. Keine zusätzliche feste Tastenabfrage für dieselbe Aktion anlegen:

Beim Öffnen eines eigenen Menüs dessen registrierte Aktion mitgeben: `exports.rp_ui:rpOpen('my_view', payload, false, { toggleAction = 'rp_jobs:menu' })`. `rp_ui` löst daraus die aktuelle Taste auf und sendet sie als `toggleKey` an NUI; bei Belegungsänderungen wird sie aktualisiert. Während NUI den Fokus besitzt, verarbeitet die gemeinsame Browser-Anbindung nur das Schließen dieses Menüs. Sie aktiviert keine Gameplay-Eingaben. Ungesperrte Ansichten nutzen den normalen bestätigten `ui:close`-Callback. Gesperrte Ansichten müssen ihre vorhandene fachliche Schließroutine verwenden (wie Einstellungen mit Warnung); der Charakterlogin darf nicht per Hotkey übersprungen werden. Für Ansichten ohne registrierte Öffnungstaste bleiben Escape und ihre vorhandene Zurück-/Schließen-Bedienung bestehen.

```lua
local function registerInputs()
    exports.rp_core:rpRegisterInputAction({
        id = 'rp_jobs:menu', -- muss zur aufrufenden Resource gehören
        label = 'Berufsmenü',
        category = 'Beruf',
        description = 'Deinen aktuellen Beruf verwalten.',
        defaultKey = 'J',
    })
end
CreateThread(registerInputs)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'rp_core' then registerInputs() end
end)
AddEventHandler('rp_core:inputPressed', function(action)
    if action ~= 'rp_jobs:menu' then return end
    -- Menü öffnen; Berechtigungen/Gameplay danach immer serverseitig prüfen.
end)
-- Für Halteaktionen: rp_core:inputReleased.
```

`rpGetBindings()` liefert öffentliche Aktionen, Tasten und Revision. `rpSetBinding(id, key, confirmed, revision)` und `rpResetBindings(revision)` liefern `{ ok, error?, bindings }`. `key = ''` entfernt eine Belegung. Bei Ressourcenende werden dynamische Aktionen aus der Liste entfernt; gespeicherte Präferenzen bleiben für einen erneuten Start erhalten. `rp_core:bindingsChanged` ist ein lokales Änderungsereignis, keine Gameplay-Berechtigung. Server-Events müssen weiterhin jede Aktion autorisieren.

`rp_ui` besitzt die Ansichten `settings` und `me`. Settings verwendet eine gesperrte Ansicht, damit der generische Schließcallback die Warnung nicht umgehen kann. NUI-Routen: `rp_ui:bind`, `rp_ui:resetBindings`, `rp_ui:closeSettings`, `rp_player:refresh`. Jede Route antwortet auch bei Fehlern; die gemeinsame Bridge begrenzt die Wartezeit auf 20 Sekunden. Profile werden ausschließlich für den tatsächlichen Callback-`source` geladen.

## Fitness

`rp_player` speichert `running_meters` und `training_seconds` unter der ESX-Charakterkennung in `rp_player_progress`. Import: `server-data/resources/[custom]/rp_player/migrations/001_player_progress.sql`. Die Migration ergänzt eine Tabelle und löscht keine Daten.

Standard: serverseitige Positionsprobe alle 5 Sekunden; 1 Level pro 1.000 Meter, maximal Level 100. Ein Segment zählt nur lebend, zu Fuß, im normalen Routing-Bucket, zwischen 2,2 und 9 m/s, bei weniger als 4 Metern Höhenunterschied und höchstens 10 Sekunden Abstand. Stillstand, Fahrt, große Teleports und alte Proben ergeben keinen Fortschritt. Es gibt keinen Client-Endpunkt zum Vergeben von Erfahrung. Die Distanz ist eine Schätzung zwischen Positionsproben, keine Anti-Cheat-Garantie oder exakte Laufwegvermessung.

Speichern alle 60 Sekunden, bei Disconnect und Resource-Stopp. Ein Clientabsturz löst normalerweise `playerDropped` aus; bei hartem Serverabsturz kann bis zum letzten Speicherintervall Fortschritt verloren gehen. Upserts verwenden monotone Maximalwerte, damit eine ältere asynchrone Speicherung keine neueren Werte zurücksetzt. Konfiguration: `rp_player/shared/config.lua`. Das Level setzt den GTA-Ausdauerstat auf 20–100; das Profil zeigt zusätzlich die aktuell verbleibende Sprintenergie als Momentaufnahme.

## NPCs und Startreihenfolge

`set onesync_population false` vor dem Start der Resources setzen. `rp_core` schaltet Population im normalen Bucket, Dispatch, zufällige Polizei, Boote, Züge, Müllwagen sowie Fußgänger- und Verkehrsdichte aus. Ambient-Population wird beim Erzeugen abgewiesen. Ein Cleanup alle 5 Sekunden entfernt kontrollierbare Nichtspieler-Peds und unbesetzte Ambient-Fahrzeuge. Spieler, Fahrzeuge mit Spielerinsassen und als Mission/Script erzeugte Projektfahrzeuge bleiben bestehen. Künftig absichtlich erstellte NPC-Peds benötigen eine Ausnahme im Cleanup, da derzeit alle NPCs entfernt werden sollen.

Startreihenfolge: `spawnmanager`, `baseevents`, `oxmysql`, `ox_lib`, `esx_lib`, `es_extended`, `skinchanger`, `rp_core`, `rp_ui`, `rp_characters`, **`rp_player`**. `rp_core` hängt nicht von `rp_player` oder `rp_ui` ab.

## Spielzeit und GTA-Geldanzeige

`rp_core` unterdrückt die originalen GTA-HUD-Komponenten CASH, MP_CASH und CASH_CHANGE ab seinem ersten Client-Frame, einschließlich Multiplayer-Bargeldanzeige. ESX-Konten bleiben unverändert; Radar und Waffenrad bleiben verfügbar.

Die Spieluhr läuft in Echtzeit mit deutscher Ortszeit. Der Server veröffentlicht einmal pro Sekunde die aus UTC berechnete MEZ/MESZ über den globalen Statebag `rp_core:worldClock`. Die Uhr des Spielers und die eingestellte Zeitzone des Hosts beeinflussen die Berechnung nicht; die Systemuhr des Servers muss korrekt sein. Netzwerklatenz und das Aktualisierungsintervall können eine kleine Abweichung verursachen. Aktuelle [Sommerzeitregeln](https://www.gesetze-im-internet.de/sozv/__2.html): letzter Sonntag im März/Oktober, Wechsel jeweils um 01:00 UTC. Bei einer gesetzlichen Änderung muss `rp_core/shared/clock.lua` angepasst werden.

Clientseitig setzt ausschließlich `rp_core` die laufende Uhr. Eine Resource kann mit `exports.rp_core:rpSetClockPreview(hour)` vorübergehend eine feste lokale Vorschauzeit von 0 bis 23 übernehmen und mit `rpSetClockPreview(nil)` wieder freigeben. Nur der Besitzer kann die Vorschau ändern/freigeben; Resource-Stopp gibt sie ebenfalls frei. `rp_characters` verwendet das für seine helle Studioansicht, danach gilt sofort wieder die aktuelle Serverzeit. Keine zweite Zeit-/Wetterresource starten, die ebenfalls `NetworkOverrideClockTime` setzt. Keine neuen Dependencies; `rp_core` startet weiterhin vor `rp_characters`.

## Admin: Fahrzeug, Noclip und Waypoint

Das bereits installierte txAdmin besitzt diese Funktionen. In der F8-Konsole `tx` eingeben oder im Chat `/tx`:

- Fahrzeugbereich → Fahrzeug spawnen; als Modell beispielsweise `sultan` oder `adder` eingeben.
- Spielermodus → Noclip zum freien Fliegen.
- Zuerst einen Wegpunkt auf der Karte setzen, dann Teleport zum Wegpunkt wählen.

Der txAdmin-Account muss im Webpanel unter **Admin Manager** mit deiner Cfx.re- oder Discord-Kennung verbunden sein und die jeweiligen Menüberechtigungen besitzen. Das Ingame-Menü muss in den txAdmin-Einstellungen aktiviert sein. Nach einer Accountzuordnung kann `txAdmin-reauth` in F8 die Anmeldung erneuern. Unter GTA-Einstellungen → Tastenbelegung → FiveM → **(txAdmin) Menu: Open Main Page** lässt sich eine eigene Menütaste setzen. [Offizielle Anleitung](https://github.com/citizenfx/txAdmin/blob/master/docs/menu.md).

Zusätzlich enthält das installierte ESX die Commands `/car sultan`, `/noclip` und `/tpm`. Sie benötigen die jeweils berechtigte ESX-Gruppe; txAdmin-Administratorrechte vergeben nicht automatisch ESX-Gruppenrechte. In F8 jeweils ohne `/` eingeben. Es werden keine ungeschützten Parallelcommands angelegt.

## Prüfen

```text
npm run check
npm run ui:build
npm run check:runtime
lua5.4 tests/characters.lua
lua5.4 tests/input-player.lua
lua5.4 tests/world-clock.lua
```

Optional mit Python, Playwright und Chrome sowie laufendem `npm run ui:dev`: `python tests/menus-ui.py` und `python tests/ui-smoke.py`. `npm run ui:preview` öffnet das [UI Studio](ui-studio.md) mit linker Ansichtenauswahl; direkte Vorschauen bleiben über `?view=settings` und `?view=me` verfügbar. Nur im Browser werden Beispieldaten und Browser-LocalStorage verwendet. `input-preview.json` ist eine Browser-Fixture des Lua-Katalogs und muss bei Katalogänderungen mitgeführt werden.

Im echten FiveM-Client noch prüfen: NPC-/Verkehrsfreiheit nach Join und Gebietwechsel, M/F12/I und deren Neubelegung, Controller-Wechsel, Wiederherstellung nach Reconnect, fehlende GTA-Geldanzeige beim Spawn, deutsche Uhrzeit nach Verlassen des hellen Editors und Fitnessanstieg nach tatsächlichem Laufen. Browser- und Lua-Mocks führen keine GTA-Physik aus.
