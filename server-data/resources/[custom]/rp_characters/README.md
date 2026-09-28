# rp_characters — Einreise und Mehrfachcharaktere

Auswahl/Spawn überlagern die ESX-Gesichts-/Identitätsbasis mit dem Outfit aus dem Inventarprovider (`rpResolveClothing`). `rp_inventory` ist eine ausdrückliche Dependency; Kleidung gehört dem vollständigen charN-Identifier. Vertrag, Konfiguration und Grenzen: [Kleidungssystem](../../../../docs/clothing.md).

Eigener Creator in der zentralen React-NUI, mit ESX Legacy 1.15.2 und dem offiziellen `skinchanger`. Freemode-Modelle, Herkunft/Headblend, 20 Gesichtsmerkmale, Augen, Haare, Bart, Hautdetails, Make-up, Kleidung und Props werden am echten Spieler-Ped dargestellt. Kleidung nutzt die im laufenden Game-Build verfügbaren Drawable-/Texture-Grenzen; der Server akzeptiert nur die eigene Schema-Allowlist. Keine frei wählbaren Ped-Modelle und keine Charakterlöschung.

## Join-Regeln

### Abgleich mit dem offiziellen ESX-Multicharacter

Der Ablauf wurde gegen [`esx_multicharacter` aus ESX 1.15.2](https://github.com/esx-framework/esx_core/tree/ddd71a58f1ea6279d68413fb4a44e0ef34ede2fa/%5Bcore%5D/esx_multicharacter) sowie die installierten `es_extended`-Lade-/Speicherfunktionen geprüft. Die Auswahloberfläche und Accountlimits sind eigene Implementierungen; es ist nicht die unverändert gestartete Standard-Multicharacter-Resource. Die Integration erhält den Standardvertrag: `Config.Multichar`, serverseitiger `charN`-Slotpräfix, voller `charN:<account>`-Identifier, separate `users`-Zeilen, `esx:onPlayerJoined`, `esx:playerLoaded`, offizieller Spawnhandshake und normale ESX-Speicherung. Fremdskripte mit privaten Callbacks/Commands des originalen Selektors benötigen gegebenenfalls einen Adapter; der Provider-Alias allein implementiert diese nicht.

Beim Audit wurde die fehlende **Servermeldung `esx:onPlayerSpawn`** ergänzt. Eine Zuweisung an `player.spawned` auf der exportierten Tabelle wurde entfernt: Exporttabellen sind Kopien, daher muss ESX sein eigenes Spawnflag setzen. Die eigene Spawnfreigabe wartet zusätzlich auf dieses ESX-Flag und die serverseitig beobachtete Position. Das Profilmodul vergleicht entsprechend die vollständige Kennung und seine Sitzung statt exportierter Lua-Tabellenidentität.

Tests: `tests/characters.lua` wechselt einen Account zwischen `char1` und `char2` und prüft passende ESX-Kennungen. `tests/character-client.lua` prüft den Server-/Client-Spawnhandshake. `tests/player-profile.lua` prüft Exportkopien und getrennte Fitnessdaten. `tests/esx-character-isolation.py` führt die installierte Standard-`Core.SavePlayer` mit kontrollierten Spielern aus und prüft echtes SQL für getrennte Jobs, Geld, Inventar, Position, Skin und Fraktionsmitgliedschaften in temporären MariaDB-Tabellen. Ein realer Login mit zwei Charakteren bleibt zusätzlich im FiveM-Client zu testen.

- Account ohne Charakter: Creator öffnet automatisch. Nach erfolgreicher Registrierung Spawn am LSIA-Ankunftsausgang.
- Account mit einem erlaubten Platz und vorhandenem Charakter: automatisch diesen Charakter laden.
- Account mit mehreren erlaubten Plätzen: Kamera-Auswahl mit eigenen Charakteren und freien Plätzen. Erstellung nur unterhalb des Accountlimits; danach direkt einreisen.
- Bestehende Charaktere: eigenes ESX-Inventar, Konten, Job, Identität und Aussehen; Spawn am letzten Servercheckpoint. Ohne Checkpoint wird die gespeicherte ESX-Position verwendet.
- Es gibt bewusst keinen Lösch-Endpunkt und keinen Wechselbefehl während des Spiels. Zum Wechseln neu verbinden.

## Installation / Startreihenfolge

1. ESX-Schema und die Migrationen `001_create_characters.sql`, danach `002_account_characters.sql` importieren.
2. `npm run ui:build` aus dem Repository-Root ausführen.
3. Reihenfolge: `spawnmanager`, `baseevents`, `oxmysql`, `ox_lib`, `esx_lib`, `es_extended`, `skinchanger`, `rp_core`, `rp_ui`, `rp_characters`.
4. `npm run check:runtime` ausführen und FXServer vollständig neu starten.

`rp_characters` deklariert `provide 'esx_multicharacter'`. Cfx löst den Alias auch bei `GetResourceState` auf, wodurch ESX seinen vorhandenen Multicharacter-Login nutzt. Es werden keine ESX-Dateien gepatcht. **Nicht gleichzeitig `esx_multicharacter`, `esx_identity` oder `esx_skin` starten**: diese würden einen zweiten Login-/Creator-Ablauf installieren.

Der Core besitzt keine Charakter-Geschäftsregeln. Die Domain hängt von `rp_ui` ab und registriert dort ihre Aktionen über `rpRegisterAction`; `rp_ui` hängt nicht von der Domain ab.

## Plätze verwalten

Standard: **1 Platz**, maximal **8**. Der Accountdatensatz ist `rp_character_accounts`, Feld `slots`. Die Standardzahl gilt beim erstmaligen Anlegen eines Accounts. Höchstzahl und SQL-Constraints müssen bei einer späteren Erweiterung gemeinsam angepasst werden.

In der Serverkonsole:

```text
rp_character_slots 12 2
rp_character_slots license:ROCKSTAR_LICENSE_OHNE_ZUSAETZLICHES_PRAEFIX 3
rp_characters_status
```

Erste Form: Online-Spieler mit Server-ID `12` erhält zwei Plätze. Zweite Form: Offline-Account anhand seiner License; die Platzhalterzeichenfolge durch die tatsächliche License ersetzen. Der Server leitet bei Online-Spielern die Accountidentität selbst ab. Das Limit darf nicht unter einen belegten Slot reduziert werden. Änderungen erscheinen beim nächsten Login bzw. erneuten Listenabruf.

Optional für eine bereits korrekt zugewiesene Admin-Gruppe in `server.cfg`:

```text
add_ace group.admin command.rp_character_slots allow
add_ace group.admin command.rp_characters_status allow
```

Es wird keine Adminberechtigung automatisch vergeben. Keine Zugangsdaten oder Accountkennungen an die NUI weitergeben.

## Datenhaltung und Sicherheit

- `rp_character_accounts`: Account und individuelles Platzlimit.
- `rp_character_slots`: Account/Slot-Zuordnung, eindeutiger ESX-Identifier, letzter Positionscheckpoint. Primärschlüssel und Unique-Key verhindern doppelte Plätze/Zuordnungen.
- `users`: vollständiger ESX-Charakter mit Identifier `charN:<account>`. Der Server legt Startkonten aus der ESX-Konfiguration und einen normalen `user`-Charakter an. Startjob ist `unemployed`, Inventar und Loadout sind leer.
- Slot-Reservierung und ESX-Datensatz werden in einer gemeinsamen oxmysql-Transaktion erstellt. Serverlocks, Sessionzustand und Cooldown verhindern parallele Aktionen. Nach wartenden Operationen wird die ursprüngliche Sitzung erneut geprüft.
- Namen: 2–16 Unicode-Zeichen aus lateinischen Zeichensätzen, Leerzeichen, Bindestrich und Apostroph. Tatsächliche Kalendertage und Alter 18–100 werden serverseitig geprüft. Größe: 120–230 cm; sie ist ein Identitätsfeld, keine Skalierung des GTA-Peds.
- Auswahl akzeptiert nur einen Slot. Accountidentität, Character-Identifier, Startgeld und Spawnkoordinaten kommen ausschließlich vom Server.
- Die Joins zwischen `rp_character_slots` und ESX-`users` vergleichen Identifier explizit mit `utf8mb4_bin`. Damit funktionieren auch Installationen, in denen ESX eine andere utf8mb4-Kollation vom Datenbankstandard geerbt hat; Vendor-Tabellen müssen nicht konvertiert werden.
- Auswahl/Creator laufen in einem privaten Routing-Bucket. Freigabe ins Spiel erfolgt nach ESX-Load und Prüfung der serverseitig beobachteten Spawnposition.

Positionen werden alle **15 Sekunden** aus dem serverseitigen Ped gelesen und zusätzlich beim Disconnect gespeichert, soweit die Entity noch vorhanden ist. Bei einem Client-/Serverabsturz wird der letzte erfolgreiche Checkpoint verwendet; die letzten Sekunden können daher fehlen. ESX besitzt weiterhin das Speichern von Geld, Inventar, Job und Metadaten. Seine Standard-Autosave-Zeit beträgt in der installierten Version zehn Minuten; beim normalen Disconnect speichert ESX zusätzlich.

## Vorhandene Prototyp-Daten

Migration 002 löscht oder überschreibt **keine** alten Daten. `rp_characters` aus dem bisherigen Prototyp und alte unpräfixierte ESX-`users` bleiben erhalten. Sie werden nicht stillschweigend zu echten neuen Charakteren erklärt oder mit kopiertem Geld/Inventar dupliziert. Die neue Auswahl verwendet ausschließlich Zuordnungen in `rp_character_slots`. Eine Übernahme alter produktiver Identitäten müsste sämtliche zugehörigen Fremdtabellen berücksichtigen und ist ein separater Migrationsschritt.

## NUI-Vertrag

### Login-Event und Vorschauplatzierung

`esx:playerLoaded` wird in unserem Client ausdrücklich mit `RegisterNetEvent` registriert und nimmt nur Serverzustellung (`source == 65535`) an. Netzwerkfreigaben gelten pro Resource; ein bloßer lokaler Handler empfängt das Event trotz Registrierung in `es_extended` nicht. Der Client-Logeintrag `event esx:playerLoaded was not safe for net` erklärte den anschließenden 30-Sekunden-Login-Timeout. Doppelte Zustellungen starten keinen zweiten Spawn. Der Ablauf bleibt beim offiziellen ESX-Spawnhandshake und servergeprüften Spawnziel. [Cfx-Registrierungsvertrag](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNetEvent/).

Auch bei automatischer Auswahl wird das gespeicherte Aussehen bereits vor dem Login als Vorschau angewendet. `client/scene.lua` lädt Bodenkollision und ermittelt die Bodenhöhe; `SetEntityCoords` ergänzt beim Platzieren den Ped-Radius auf der Z-Achse. Eine Bodenhöhe direkt an `SetEntityCoordsNoOffset` zu übergeben würde den Körper teilweise im Boden einfrieren. Nach Modellwechsel wird der neue Vorschau-Ped wieder auf diese Bodenhöhe gesetzt; beim Spieleinstieg wird der Vorschauzustand entfernt. Fehlende Kollision/Bodenhöhe führt nach fünf Sekunden zu einer wiederholbaren Fehlermeldung. [Native-Vertrag](https://raw.githubusercontent.com/citizenfx/natives/master/ENTITY/SetEntityCoords.md).

### Creator, Kleidung und Kamera

Der Creator orientiert sich an den GTA-Interaktionsmenüs in `gta/`: schmale, getrennte Kopf-/Inhalts-/Aktionsflächen, helle Auswahlzeilen, dezente Mint-Akzente und eine separate Icon-Leiste. Keine vollflächige Abdunklung über dem Charakter. Der Editor belegt bei Full HD und 4K 25 rem (rund 21 % der Breite, ohne schmale Icon-Leiste); auf kleinen Bildschirmen umbrechend und scrollbar. Kamerapresets verwenden eindeutige SVG-Piktogramme mit Tooltips und zugänglichen Namen. „Freie Vorschau“ blendet den Editor aus, erhält Eingaben und lässt Kamera/Zoom bedienbar. Die Auswahloberfläche außerhalb des Creators behält ihren eigenen Hintergrundstil.

Die Vorschau liegt auf der offenen Vinewood-Terrasse bei `-284.2856, 562.4627, 172.9182`, übernommen aus der [offiziellen ESX-1.15.2-Konfiguration](https://github.com/esx-framework/esx_core/blob/ddd71a58f1ea6279d68413fb4a44e0ef34ede2fa/%5Bcore%5D/esx_multicharacter/config.lua). Nur die Vorschau wird verlegt; die Einreise erfolgt weiterhin am Flughafen, bestehende Charaktere am gespeicherten Standort. `shared/config.lua`: `studio` legt Position/Blickrichtung fest, `studioHour` standardmäßig 12 Uhr (0–23). Vor dem Einblenden wird bis zu fünf Sekunden auf die Umgebungskollision gewartet.

Während der Vorschau gelten lokal klares Wetter und Mittagszeit. Zwei schwache, mit der Kamera umlaufende [Native-Lichtquellen](https://github.com/citizenfx/natives/blob/master/GRAPHICS/DrawLightWithRange.md) machen Haut und Kleidung auch bei Gegenlicht lesbar. Sie werden nur während der Kamerafunktion pro Frame gezeichnet; es entstehen keine persistenten Entities. Einreise und Resource-Cleanup entfernen Kamera sowie lokale Wetter-/Zeit-Overrides. Beim späteren Einbau einer Wetter-Synchronisation deren Override-Verhalten mit dieser Vorschau abstimmen. Die Browserkulisse ist nur ein heller Platzhalter, kein Bild der tatsächlichen Spielszene.

Die neue Oberfläche und Kamera-NUI sind auf sieben Größen einschließlich 4K geprüft, ebenso Transparenz, Iconbeschriftungen und Ein-/Ausblenden ohne Formularverlust. Lua-Tests prüfen Lichtgrenzen und Cleanup. Tatsächliche Ausleuchtung, Kollisionsfreiheit aller Orbitwinkel und Outfitdarstellung auf der Terrasse bleiben im FiveM-Client zu bestätigen.

Der Editor gliedert sich in Identität, Herkunft, Gesicht, Haare, Details, Kleidung und Accessoires. Untergruppen sind aufklappbar und durchsuchbar. Die Tabs lassen sich direkt öffnen; „Weiter“ prüft die Identität. Mutter und Vater besitzen benannte, getrennte Vorlagenlisten. Stärke 0 blendet ein Haut-/Haar-Overlay aus.

Mann/Frau lädt `mp_m_freemode_01` bzw. `mp_f_freemode_01`. Der Modellwechsel setzt Aussehen und Kleidung zurück, erhält jedoch die eingegebene Identität. Der Katalog wird nach dem Modellwechsel neu aus den Ped-Natives aufgebaut: Frisuren, Drawables, Texturen, Props und Overlays. Bart/Brustbehaarung werden nur beim männlichen Modell angeboten; Make-up bleibt für beide verfügbar.

`shared/wardrobe.lua` enthält pro Modell zwölf Oberteile, zwölf Hosen/Unterteile und zwölf Paar Schuhe sowie begrenzte zivile Accessoires. Es werden stabile Basisspiel-IDs verwendet. Oberteile enthalten passende Arm-/Untershirt-Komponenten; diese technischen Komponenten sind nicht einzeln editierbar. Varianten sind auf die vorhandenen Texturen und maximal zwölf pro Artikel begrenzt. Nicht vorhandene Props werden im Spiel herausgefiltert. Masken, Schutzwesten und freies Durchblättern sämtlicher DLC-Kleidung gehören nicht zur Anreise. `validateCreation()` prüft die erlaubten Kombinationen serverseitig. `validate()` lässt bestehende, gespeicherte Kleidung weiterhin zu; es werden keine Bestandsdaten umgeschrieben. Die visuelle Passform jedes Outfits benötigt zusätzlich eine Prüfung im FiveM-Client.

`client/camera.lua` besitzt fünf Ansichten: Ganzkörper, Gesicht, Oberkörper, Unterkörper, Schuhe. Linke Maustaste in der freien Vorschau halten und ziehen dreht horizontal und vertikal; Mausrad bzw. +/− zoomt. Neigung ist auf −25 bis +35 Grad beschränkt; die Entfernung ist je Ansicht begrenzt (insgesamt 0,5–4 Meter). Zentrieren stellt die Frontansicht und den Standardzoom des aktuellen Ausschnitts wieder her. Übergänge werden pro Frame geglättet; Appearance-Änderungen starten die Kamera nicht neu. Die Frame-Schleife existiert nur bei aktiver Kamera und wird bei Cleanup beendet.

Die lokale Kameraaktion akzeptiert `{ view?, rotation?, pitch?, zoom? }`, wobei `view` einer der Werte `body`, `face`, `upper`, `lower`, `shoes`, `rotation` −180…180, `pitch` −25…35 und `zoom` 0…1 sein muss. Nicht endliche Zahlen werden verworfen. Die NUI sendet höchstens alle 33 ms und hält maximal eine Anfrage plus den neuesten ausstehenden Zustand. Formular-Scrollen wird nicht an die Kamera weitergereicht. `fields` ergänzt optionale `section` und `options: [{ value, label }]`; Optionen übertragen tatsächliche IDs, keine Listenindizes.

Quellen: [Cfx Head Blend](https://github.com/citizenfx/natives/blob/master/PED/SetPedHeadBlendData.md), [Cfx Head Overlays](https://github.com/citizenfx/natives/blob/master/PED/SetPedHeadOverlay.md), [Cfx Kleidungs-IDs und Collections](https://docs.fivem.net/docs/scripting-manual/using-new-game-features/collection-based-natives/). Der vorhandene ESX-`skinchanger` bleibt unverändert; Tattoos benötigen ein separates Decoration-System.

View `characters` enthält `mode` (`selection`, `creator`, `loading`, `error`), `slots`, eigene öffentliche `characters`, `skin`, `fields`, Altersgrenzen und optional einen Fehlercode. Der View ist bis zum erfolgreichen Spawn gesperrt; Escape schließt ihn nicht. `ui:ready` spielt den letzten View erneut aus, damit frühe Join-Nachrichten nicht verloren gehen.

Lokale NUI-Aktionen: `rp_characters:refresh`, `preview`, `new`, `back`, `appearance`, `camera`, `select`, `create`. Kamera und Vorschau bleiben clientlokal; Erstellung/Auswahl werden serverseitig geprüft. Servercallbacks: `bootstrap`, `list`, `create`, `select`, `spawnData`, `spawned`, jeweils mit `rp_characters:`-Präfix. Es gibt keine NetEvents zum Löschen oder zum freien Setzen eines Accounts/Spawnpunkts.

Speichern und Login sind getrennte Schritte: Der Servercallback `create` bestätigt eine erfolgreiche Transaktion mit `{ ok = true, slot }`. Erst danach ruft der Client `select` mit diesem Slot auf. Scheitert der Login, bleibt der gespeicherte Slot als Einreiseziel erhalten; „Erneut versuchen“ wiederholt ausschließlich die Auswahl. Ein wiederholtes `create` in derselben Sitzung bestätigt denselben Slot, ohne eine weitere Transaktion auszuführen. Bei verlorener Speicherantwort oder einer veralteten Creator-Ansicht mit inzwischen vollem Limit wird die Charakterliste neu gelesen. Vor dem Speichern und Login wird die aktuelle ESX-Jobtabelle über einen frischen Export-Snapshot geprüft: Das beim Resource-Start übernommene `ESX.Jobs` kann nach `ESX.RefreshJobs()` dauerhaft veraltet sein. Diese Prüfung wartet nicht unbegrenzt auf ESX.

## Prüfung und Betrieb

```text
npm run check
npm run ui:build
npm run check:runtime
lua5.4 tests/characters.lua
lua5.4 tests/character-client.lua
lua5.4 tests/creator.lua
```

Die Lua-Tests laufen unter Lua 5.4 mit Doubles für FiveM/SQL und sind in CI eingebunden. Mit laufender Docker-MariaDB prüft `python tests/character-database.py` die tatsächlichen Auswahl-/Login-Abfragen bei verschiedenen Kollationen. Der Test verwendet ausschließlich verbindungslokale temporäre Tabellen; vorhandene Spielerdaten werden nicht verändert.

Optional: `pip install playwright`, lokales Chrome, Vite auf `127.0.0.1:5173`, dann `python tests/ui-smoke.py`. Browserpreview: `/` für UI Studio, `/?view=characters` für Auswahl, `/?view=creator` für Creator. Der Browser zeigt einen Platzhalter statt eines GTA-Peds.

Bei `rate_limited` liefert der Server die verbleibende Wartezeit zurück. Der Client wartet diese mit kurzem Sicherheitspuffer ab und versucht höchstens dreimal; andere Fehler, insbesondere Datenbankfehler, werden nicht automatisch wiederholt. Dadurch überschreibt ein schneller Wiederholungsversuch nicht sofort die eigentliche Einreisemeldung mit einer Cooldown-Anzeige.

FXServer kann serverseitig gestartet und die Datenbank geprüft werden. Echte Modell-/Kleidungsdarstellung, Kameraposition, erster Spawn, Reconnect und Crash-Rückkehr müssen zusätzlich mit einem FiveM-Client geprüft werden. Das Neustarten von `rp_characters` trennt seine laufenden Sitzungen kontrolliert, damit keine unvollständigen Charakterzustände weiterverwendet werden.
