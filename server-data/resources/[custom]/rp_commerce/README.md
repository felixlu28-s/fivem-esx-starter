# Shops und Werkbänke

**„Aktuell“ im Kleiderladen:** Die Kachel zeigt das lokale GTA-Bild des beim Öffnen
getragenen Kleidungsstücks, genau nach Freemode-Modell, Drawable und Textur.
Grundlage ist das vorhandene `skinchanger:getSkin` (ESX Legacy 1.15.2), auch wenn
keine eigene Inventarzeile für eine Outfit-Komponente vorliegt. Anprobieren ändert
diese Kachel nicht; nach einem Kauf wird sie aus dem bestätigten Provider-Outfit
aktualisiert. Leere Kategorien zeigen „Nicht angezogen“, unbekannte Bilder bleiben
beim Kategorie-Symbol. Reine Darstellung, keine Änderung an Besitz, Preisen oder
Persistenz. Browser-Studio zeigt passende Beispielbilder in allen zwölf Kategorien.

**Echte Produktbilder / vollständiger Handwaffenkatalog:** Kleidungsangebote und das Inventar verwenden dieselben GTA-Bilder und Namenszuordnungen. Der bestehende Ammu-Nation-Editor kann alle 110 importierten Waffen-/Ausrüstungseinträge platzieren. Er liest dieselben Itemdefinitionen wie der alleinige Inventarprovider; bestehende Auslagen und Preise bleiben erhalten. ESX Legacy 1.15.2, Bestell-/Geldpfad und Lizenzprüfungen bleiben unverändert. Quellen, Abdeckung, neue Munitionsfamilien und Grenzen: [Gegenstandskatalog](../../../../docs/item-catalog.md).

Binco Strawberry und Suburban Hawick verwenden die vorhandene ESX-Zahlungs-/Bestellabwicklung mit Anprobe und Kleidungsitems; kein zweiter Clotheshop erforderlich. Vertrag, Konfiguration und Grenzen: [Kleidungssystem](../../../../docs/clothing.md).

Eigene Resource `rp_commerce`, zentrale React-Ansicht in `rp_ui`. **E** öffnet den nächsten Laden oder die nächste Werkbank innerhalb von 1,25 m. Unter **F12 → Shop / Werkbank öffnen** frei umbelegbar. Alternativ `/rp_shop` bzw. `/rp_crafting` am jeweiligen Ort. Ammu-Nation nutzt dieselben Käufe mit NativeMenu, Kamera, Auslagen und optionalem Verkäufer: [Waffenläden und Ingame-Editor](../../../../docs/weaponshops.md).

## Direkt ausprobieren

**Gemeinsames NPC-Verhalten:** Alle gesetzten Verkäufer begrüßen nahe Spieler bei Sichtkontakt, schauen gelegentlich zu ihnen und spielen zurückhaltende Gesten/Sprachzeilen. Das gilt auch für normale Läden und andere gewählte Grundhaltungen. Ammu-Nation nutzt seine speziellen Gunstore-Gesten, übrige Verkäufer geschlechtsspezifische allgemeine Gesten. Geste und Sprache pausieren im Shop-Dev-Modus. Registrierung erfolgt automatisch über den bestehenden `rp_core:rpProtectPed`-Pfad; [API, Konfiguration und Grenzen](../rp_core/README.md). Keine neuen Shopfelder, Migrationen oder Kaufereignisse.

**Normalen Laden ingame bearbeiten:** `/rp_shopdev` (F8: `rp_shopdev`). Berechtigt sind ESX `admin`, `superadmin` und `owner`. Nutzt denselben mintgrünen NativeUI-Editor, dieselbe NPC-Platzierung und denselben dauerhaften Speicherdienst wie `/rp_weaponshop`.

- Bestehenden Laden wählen oder an der aktuellen Position erstellen; entfernte Läden setzen zunächst einen Wegpunkt. Bearbeiten/Speichern erfordert dieselbe Instanz und höchstens 75 m Abstand, Neuanlegen höchstens 10 m.
- Name/Beschreibung, Interaktionspunkt und dessen Feinposition ändern.
- Verkäufer aktivieren, Modell/Haltung wählen, per Bodentest, Raycast oder Feinjustierung platzieren und drehen. „An meine Position stellen“ speichert den Boden unter den Spielerfüßen; +0,5 m gilt nur für den Start des Bodentests. Der zusätzliche Höhenversatz ist jetzt standardmäßig 0, da +0,5 m zu schwebenden NPCs führte. Theken oberhalb der Füße werden übersprungen; die NPC-Höhe wird aus den Fußknochen statt aus der Modell-Bounding-Box bestimmt. Begrenzte Nachausrichtung nach Modellwechsel, kein dauerhaftes Snapping. Manuelle Werte bleiben erhalten. Bereits falsch gespeicherte Verkäufer einmal neu setzen und speichern. Entwürfe bleiben bis zum Speichern lokal. ESX Legacy 1.15.2 und der vorhandene `esx_shops`-Adapter bleiben unverändert; keine neue Persistenz oder Migration. Details: [NPC-Platzierung](../../../../docs/weaponshops.md).
- Sortiment aus dem aktuellen ESX-Inventarkatalog wählen: Suche, Seiten mit je 20 Artikeln, Preise, Stückzahl pro Kauf, frei benannte Kategorien, Reihenfolge und Entfernen. Maximal 96 Angebote pro Laden. Waffen, Munition, Waffenkomponenten und Geldkonten bleiben außerhalb dieses normalen Katalogs; Waffenhandel läuft weiter über Ammu-Nation und dessen Lizenzprüfung.
- Kartenmarkierung ein-/ausschalten; Namen, GTA-Symbol-ID, Farbe und Größe bearbeiten. Blip und Interaktionspunkt teilen dieselbe Position.
- Speichern veröffentlicht NPC, Blip und Kaufangebote; Löschen verlangt eine Bestätigung und archiviert den Datensatz. Offene bezahlte/ungeklärte Bestellungen verhindern Löschen.

Migration **`migrations/003_shops.sql`** zusätzlich zu 001/002 anwenden. Beim ersten Start werden konfigurierte normale `esx_shops`-Zonen mit `INSERT IGNORE` in `rp_commerce_shops` übernommen. Die ursprünglichen Venue-IDs bleiben bestehen, damit alte Bestellungen weiter am richtigen Laden wiederhergestellt werden können. Danach sind diese gespeicherten Definitionen maßgeblich; spätere Config-Änderungen überschreiben sie nicht. Gelöschte Config-Läden werden nicht neu angelegt. Neue Config-IDs werden weiterhin einmalig importiert. Bestehende Jobbeschränkungen werden übernommen und erhalten; der Editor ändert diese nicht. Crafting bleibt unverändert in der Konfiguration. Maximal 128 aktive normale Läden.

`server/shop_editor_store.lua` ist der gemeinsame Berechtigungs-/Persistenzpfad für beide Editoren: charaktergebundene, befristete Admin-Sitzungen, erneute Rechte-/Entfernungsprüfung, Rate-Limits, Versionsvergleich beim SQL-Update, Sperre gegen laufende Käufe und Wiederherstellung nach verlorener SQL-Antwort. Änderungen schließen ältere Kaufmenüs. SQL-Bezeichner stammen ausschließlich aus festen Serverdefinitionen; Werte sind parametrisiert. Der ESX-Kaufpfad und `rp_inventory:rpExchange` bleiben die einzigen Geld-/Bestandswege. Keine zusätzliche Resource oder Library.

Normale NPCs verwenden denselben lokalen Schutz und dieselbe korrigierte Fußpositionierung wie Ammu-Nation. Stream-in 45 m / Stream-out 60 m, Wartung alle 750 ms, Standortabgleich alle 15 Sekunden plus verzögerter Änderungsbenachrichtigung. Modelle und Blips werden bei Änderungen/Stop bereinigt; es gibt keine zusätzlichen Frame-Loops. Startreihenfolge bleibt `es_extended` → `rp_core`/`rp_ui` → `rp_inventory`/`rp_nativeui` → `rp_commerce`.

Prüfungen: `tests/commerce.lua` deckt beide Editoren, ESX-Import, Revisionen, Kauf-Replay, gefälschte Artikel/Preise, Rechte, Entfernung/Instanz, verlorene SQL-Antwort und Löschsperren ab. `tests/weaponshop-client.lua` führt beide echten NativeUI-Editoren inklusive Artikelwahl, Preisen, Packgröße, NPC-Vorschau, Blip und Cleanup aus. Native Modelle, tatsächliche Blips und die komplette Bedienung müssen zusätzlich ingame geprüft werden.

| Ort | Position | Kartenname |
| --- | --- | --- |
| 24/7 in Strawberry, am Tresen | `25.7, -1347.3, 29.5` | **24/7 · Testshop** |
| Testwerkbank neben dem Laden | `28.4, -1339.0, 29.5` | **Werkbank · Testrezepte** |

Der Shop verkauft Mineralwasser ($12), Sandwich ($25), Verband ($45), Tagesrucksack ($350), Stoff ($8), Nähgarn ($5) und Kunststoff ($6). Bezahlung mit ESX-Bargeld oder Bankkonto; kein eigener Geldbestand. Mengen 1–20, Kategorien, Suche, Preis-/Gewichtsübersicht und aktueller Besitz. Die Standard-Testshops haben unbegrenzten Vorrat; Verkauf an Shops ist nicht enthalten.

Rezepte (je Durchgang, maximal fünf gleichzeitig):

| Ergebnis | Materialien | Dauer |
| --- | --- | --- |
| 1 Verband | 2 Stoff + 1 Wasser | 3 s |
| 1 Tagesrucksack | 6 Stoff + 2 Nähgarn + 2 Kunststoff | 6 s |
| 1 Reiserucksack | 1 Tagesrucksack + 8 Stoff + 4 Nähgarn | 10 s |

Die Werkbank zeigt Besitz/Bedarf, Ausgabemenge und Fortschritt. Abbrechen/Schließen vor Abschluss verbraucht keine Materialien. Die Herstellung muss serverseitig vollständig abgelaufen sein; erst dann tauscht der Inventarprovider sämtliche Zutaten und Ergebnisse in einer gemeinsamen Transaktion aus. Nach bereits erfolgtem Commit setzt ein Schließen die Buchung nicht zurück. Angelegte Rucksäcke zuerst abnehmen, um sie als Material zu verwenden.

Testgeld über den vorhandenen ESX-Konsolenbefehl `setaccountmoney <Server-ID> money 1000` (setzt den Kontostand, addiert nicht). Keine neue Geld-Cheat-API. Browser: `npm run ui:preview`, links **Shop** oder **Werkbank**. Direkt `http://127.0.0.1:5173/?view=shop` bzw. `/?view=crafting`; interaktive, separate Demodaten ohne Serverzugriff.

## ESX-Standard und gewählte Integration

Vor Implementierung geprüft: installierte **ESX Legacy 1.15.2**; offizielles **esx_shops 2.0.0**, Commit `ccda737f7d4f73d224fab2097bee5083afd4dd4e`, insbesondere Konfiguration, Inventory- und Transaction-Module. In diesem offiziellen ESX-Addon-Baum existiert kein eigenständiges Crafting-Addon. Quellen: [ESX Shops](https://github.com/esx-framework/ESX-Legacy-Addons/tree/ccda737f7d4f73d224fab2097bee5083afd4dd4e/%5Besx_addons%5D/esx_shops), [offizielle Addons](https://github.com/esx-framework/ESX-Legacy-Addons/tree/ccda737f7d4f73d224fab2097bee5083afd4dd4e/%5Besx_addons%5D).

`shared/esx_shops.lua` übernimmt den offiziellen **Config.Zones**-Konfigurationsvertrag: `Items` mit `name/price/category`, `Categories`, `Pos`, `Type`, `Color`, `ShowBlip` (`ShowMarker` wird f?r unsere Darstellung ignoriert). Der Testshop benutzt dieses Format bereits. Vorhandene Zonendefinitionen können unter `Commerce.Config.esxZones` eingetragen werden. Optional eigene `Label`, `Subtitle`, `BlipLabel`, `Jobs`, `Bucket`; ohne `id` verwendet ein Angebot den Itemnamen. Mehrere Positionen erzeugen `<zone>_1`, `<zone>_2` usw. Itemnamen müssen im Providerkatalog/ESX bekannt sein, unbekannte Namen werden nicht still ersetzt. Bezeichnungen und Gewichte kommen aus dem Itemkatalog. FontAwesome-Kategorien werden durch unsere gemeinsamen Icons dargestellt; fremde Steuer-, Lizenz-, Target- und Shopbesitz-Module werden nicht implizit übernommen.

ESX bleibt Eigentümer von Charakter, Job und Konten. Online-Zahlungen benutzen `xPlayer.getAccount/removeAccountMoney`, Speichern den offiziellen `save`-Befehl plus `esx:playerSaved`. `users` wird ausschließlich zur Zahlungsbestätigung gelesen, niemals durch unsere Resource beschrieben. Items kommen aus ESXs vorhandenem Custom-Inventory-Provider. Crafting erweitert dessen Transaktionsweg; es gibt keine zweite Bestandsverwaltung.

Das originale `esx_shops` wird **nicht zusätzlich gestartet**: Es bringt eine eigene NUI und einen Kaufhandler mit Einzelbuchungen mit, während unser UI zentral bleibt und unsere Slots eine gemeinsame Kapazitäts-/Commitprüfung brauchen. Seine Clientcallbacks und die komplette `ox_inventory`-Shop-/Crafting-API werden nicht vorgetäuscht. Fremdscripts über die ESX-Item-/Konto-APIs oder einen expliziten Adapter anschließen. Keine Vendor-Datei verändert.

## Konfiguration und Erweiterung

- `shared/config.lua`: ESX-Shopzonen und eigene Werkbänke; Preise, Materialien, Ergebnisse, Dauer, Blips und Standorte. Änderungen durch Resource-/Serverneustart aktivieren; keine Preise/Zutaten aus NUI-Payloads übernehmen.
- `Jobs = { police = 2 }` bei ESX-Zonen bzw. `jobs = { police = 2 }` bei Werkbänken begrenzt den Zugriff auf primäre ESX-Jobs/Mindestränge. Mehrere Einträge bedeuten einen passenden Job; zusätzliche Fraktionsmitgliedschaften benötigen eine fachliche Erweiterung.
- Items in `rp_inventory/shared/items.lua` oder im vorhandenen ESX-`items`-Katalog definieren. Die neuen Materialien `rp_fabric`, `rp_thread`, `rp_plastic` wiegen 150/50/100 g, Stapelgrenze jeweils 20.
- Standarddimension ist Bucket 0. Blips sind kurzreichweitig auf der Minimap und auf der Karte sichtbar. In Reichweite erscheint der gemeinsame `rp_ui`-Interaktionshinweis mit der aktuellen Taste; es gibt keine 3D-Pfeile. Die Anzeige erteilt keine Serverberechtigung.
- Neue Rezepte unter einer Werkbank in `venues`: `id`, `item`, `count`, `seconds`, `category`, `ingredients = { {name='rp_fabric',count=2} }`. Zutaten werden beim Start und nochmals beim Commit geprüft. Fortschritt bleibt sitzungsgebunden, kein Offline-Crafting.

Inventar-Serverexport für andere vertrauenswürdige Domains:

```lua
local ok, reason = exports.rp_inventory:rpExchange(source, requestId,
    { { name = 'rp_fabric', count = 2 }, { name = 'rp_water', count = 1 } },
    { { name = 'rp_bandage', count = 1 } },
    function() return serverSessionStillValidAndPlayerAtWorkbench() end)
```

`requestId`: 8–55 Zeichen, alphanumerisch/`_`/`-`; bei Wiederholung beibehalten. Der Provider ergänzt die aufrufende Resource im dauerhaften Beleg. Die Domain besitzt Rezepte, Zeit und Fachrechte; der Provider sperrt den Bestand, prüft Slots/Gewicht, bucht atomar und synchronisiert ESX. Der optionale sechste Callback läuft nach erfolgreicher vollständiger Inventarvorprüfung und vor dem Commit unter derselben Sperre. Nur für journalisierte Nebenwirkungen wie unsere Zahlung verwenden: Ein Inventarfehler nach diesem Callback rollt externe Kontoänderungen nicht automatisch zurück. Niemals aus Clientdaten freie Rezepte, Hooks oder Preise konstruieren.

## Zahlungen und Wiederherstellung

Kleidungsläden verwenden denselben Kaufpfad für Einzelstücke und komplette Outfits. `buyOutfit` akzeptiert nur serverbekannte Produkt-IDs (maximal eine je Kategorie) und die boolesche Anziehoption. Die vollständige Lieferung wird vor der Abbuchung geprüft. „Direkt anziehen“ bleibt im dauerhaften Auftrag erhalten, einschließlich Abholung nach einer Unterbrechung; Items und getragene Zuordnung werden gemeinsam gebucht. UI, Kameraverhalten und ESX-Kompatibilität: [Kleidungssystem](../../../../docs/clothing.md).

Ein Kauf prüft zunächst die vollständige Lieferung auf einer Inventarkopie. Danach wird eine Bestellabsicht in `rp_commerce_orders` gespeichert, ESX-Geld abgezogen, das Speichern angefordert und eine erfolgreiche ESX-Speichermeldung samt Datenbankkontostand bestätigt. Erst der Zustand `paid` erlaubt die Itembuchung. Wiederholungen derselben Anfrage erzeugen weder eine zweite Abbuchung noch zusätzliche Items. Fremde/abgelaufene Sitzung, Distanz, Bucket, Job, Mengen und Rate-Limit werden serverseitig geprüft. Während der Zahlung bleibt das Spielerinventar gesperrt; Fremdscript-Aufrufer müssen mögliche `busy`-Rückgaben behandeln.

Bei bestätigter Zahlung und unterbrochener Lieferung bietet das UI **Bestellung abholen** im ursprünglichen Shop an. Das gilt auch nach Reconnect/Resource-Neustart und bei verlorener SQL-Commitantwort: Der dauerhafte Inventarbeleg entscheidet, ob bereits geliefert wurde. Eine offene Bestellung blockiert weitere Käufe dieses Charakters. Andere Charaktere desselben Accounts haben eigene Bestände und Bestellungen.

**ESX-Konten und unser Inventar haben keine gemeinsame SQL-Transaktion.** Ein Prozessabbruch zwischen Kontobelastung und Zahlungsbestätigung lässt deshalb bewusst `intent` zur Prüfung stehen. Auch ein fehlendes Save-ACE, Datenbankfehler oder ein zwischenzeitlich geänderter Kontostand kann diese Sperre auslösen. Keine automatische Rückzahlung/erneute Abbuchung bei unklarem Ergebnis. Änderungen durch fremde Kontoscripts und ESX-Autosaves haben weiterhin ihre eigenen Persistenzgrenzen; dies ist keine Zusage eines universellen ACID-Geldsystems.

Nur in der Server-/txAdmin-Konsole:

```text
rp_commerce_orders <online-player-id>
rp_commerce_resolve <online-player-id> <request-id> paid <Prüfnotiz mit mindestens 8 Zeichen>
rp_commerce_resolve <online-player-id> <request-id> cancelled <Prüfnotiz mit mindestens 8 Zeichen>
```

`orders` zeigt offene Vorgänge, Waren, Betrag und vorher/nachher erwarteten Kontostand. `paid` nur nach belegter Abbuchung setzen; danach kann der Spieler abholen. `cancelled` nur, wenn keine Abbuchung stattfand oder eine nötige Korrektur über ESX bereits erledigt ist. Die Befehle ändern selbst keinen Kontostand, funktionieren nicht als Spielerkommando und protokollieren die Entscheidung in `review_note`. Bestell-/Inventarbelege nicht löschen, um Sperren zu umgehen.

## Installation und Prüfung

1. Zuerst `rp_inventory/migrations/001_inventory.sql`, dann `migrations/001_orders.sql` und `migrations/002_weaponshops.sql` in derselben MariaDB wie ESX einspielen. Additiv; keine Bestandslöschung. Lokal bereits angewendet.
2. `rp_commerce` nach `rp_inventory`, `rp_nativeui`, `rp_ui`, `rp_core` starten; die Projektkonfiguration startet es nach `rp_organizations`. `add_ace resource.rp_commerce command.save allow` ist für bestätigte ESX-Zahlungen erforderlich und lokal sowie im Beispiel gesetzt.
3. `npm run check`, `npm run ui:build`, `npm run check:runtime`. Nach dieser Erweiterung vollständiger Spielserverneustart, damit neue Providerexports, Items und NUI zusammen geladen werden.

`tests/commerce.lua` führt echte Provider-/Domainlogik aus und prüft in 54 Assertions Kaufmanipulation, Distanz/Dimension/Sitzung, Konten/Charaktertrennung, Replay, volles Inventar, SQL-Ausfälle und verlorene Antworten, Zahlungsprüfung, Recovery, serverseitige Craftingzeit, Abbruch und fehlende Zutaten. `tests/commerce-database.py` prüft das echte MariaDB-Journal mit fünf konkurrierenden Schreibern, Charaktertrennung, Statuswechsel und JSON-Constraint in einer eigenen temporär angelegten Testtabelle. `tests/commerce-ui.py` prüft echte React-Bedienung, 14 Layouts bis 4K, validierte NUI-Antworten, Doppelklicks und verspätete Antworten. Browser und Lua-Testhost ersetzen keinen FiveM-Client.

Noch live prüfen: Interaktionshinweis-/Blipposition am 24/7, Werkbankanimation, E und F12-Umbelegung, echte ESX-Save-Bestätigung, Einkauf/Herstellung mit vollem Inventar, Disconnect/Neustart während einer Zahlung. Der laufende Spielserver wurde während der Implementierung nicht neugestartet.
