# Kleidungsläden und Kleidungsitems

## Benutzung

**Binco · Strawberry** und **Suburban · Hawick** haben Kleiderbügel-Blips, Verkäufer mit gemeinsamer NPC-Begrüßung und Interaktionspunkte. Mit **E** (bzw. deiner Shop-Taste) öffnen. Links Kategorien, rechts Artikelbilder, Namen, Suche und Preise. **Nur Anprobe** blendet das Sortiment aus. Ziehen/Mausrad, Körperansichten und Zentrieren verwenden dieselbe Kamera wie der Charaktereditor.

Die Anprobe friert den Charakter nicht ein. Beim normalen Schließen fährt die gemeinsame Kamera in **400 ms** weich zurück zur Spielkamera; Tod, Logout und Resource-Stop räumen sofort auf. Auslaufende Kameras werden nach der Rückfahrt gelöscht; ein erneutes Öffnen kann nicht durch einen alten Timeout beendet werden. Die Maus bleibt während der Anprobe für Sortiment und Kamera reserviert.

**Outfit zusammenstellen:** Jede Kategorie beginnt mit **Aktuell**, auch bei aktiver Suche. Damit wird nur diese Kategorie auf die tatsächlich getragene Kleidung zurückgesetzt. Andere ausgewählte Kategorien bleiben erhalten; der Kategorienwechsel selbst ändert keine Kleidung. Markierungen links und der Gesamtpreis zeigen die Auswahl.

„Aktuell“ zeigt dasselbe exakte Modell-/Texturbild wie das Inventar. Die Zuordnung
wird beim Öffnen aus dem `skinchanger`-Outfit für alle zwölf Kategorien ermittelt,
auch für Einreisekleidung und Komponenten ohne eigene getragene Itemzeile.
Anprobierte Kleidung ersetzt das Bild nicht. Nach dem Kauf gilt das bestätigte
Provider-Outfit: mit „Direkt anziehen“ wechselt das Bild, ohne Haken bleibt es
unverändert. Leere Kategorien heißen „Nicht angezogen“; nur bei fehlenden
Quellbildern erscheint weiterhin das Kategorie-Symbol.

ESX-Bargeld oder Konto wählen. **Kaufen** kauft ausschließlich die Auswahl der aktuellen Kategorie; **Alles kaufen** kauft alle ausgewählten Kategorien gemeinsam, je ein Item. „Aktuell“ kostet nichts und wird nicht mitgekauft. Gekaufte Auswahlpositionen werden aus der Zusammenstellung entfernt; noch nicht gekaufte bleiben in der Anprobe.

**Direkt anziehen** ist beim Öffnen standardmäßig aus. Ohne Haken landen Käufe im Inventar und ändern das getragene Outfit nicht. Mit Haken werden ausschließlich gekaufte Stücke direkt als angezogen gespeichert; bisher getragene Stücke dieser Kategorien bleiben ungetragen im Inventar. Im Laden ist keine zweite Anziehanimation nötig, da die Kleidung bereits anprobiert wird. „Aktuell“ übernimmt danach die neu gekaufte, tatsächlich angezogene Kleidung. Beim Schließen wird jede nicht gekaufte Anprobe verworfen.

Außerhalb des Ladens spielt Rechtsklick **Anziehen / Ausziehen** eine Animation; das Item bleibt im Slot und wird als **Angezogen** markiert. Pro Kategorie ein Stück. Kleidung des anderen Freemode-Modells kann besessen/weitergegeben, aber nicht angezogen werden.

Sortieren lässt Kleidung an. Bei Weitergabe, Ablegen oder Transfer in fremde Bestände läuft zuerst die Ausziehanimation, danach die atomare Umbuchung. Volles Ziel, Abbruch oder Animationsfehler lassen Item und Outfit beim Besitzer. Aufheben zieht nichts automatisch an.

**I / Escape während der Animation:** Das Inventar darf sofort geschlossen und wieder geöffnet werden. Eine bereits serverseitig angenommene Aktion läuft einschließlich Animation und Speichern weiter. Die alte Ansicht kann keine neuen Aktionen mehr starten; ein neues Fenster kann die laufenden Inventarsperren nicht umgehen. Das gilt ebenso für das Ausziehen vor Geben, Ablegen oder Einlagern.

## Konfiguration

- Orte/NPCs: `rp_commerce/shared/clothing.lua`. `coords` ist der servergeprüfte Interaktionspunkt; `npc.pos` der **Boden-/Sohlenanker**, `heading` die Drehung. Keine zusätzliche +0,5-Höhe. Vorhandenes Shop-Streaming/Fußausrichtung/`rpProtectPed`/`rpConfigureNpc`.
- Sortiment: `rp_inventory/shared/clothing_catalog.lua`. Feste Produkt-ID, Modell, Kategorie, Name, Preis und Standard-`skinchanger`-Patch. Aktuell **84 Artikel je Freemode-Modell** in zwölf Kategorien einschließlich Brillen, Ketten, Ohrringen und Uhren. Dekorative Taschen geben keine Slots; hierfür bleibt das Rucksack-System zuständig.
- Basis-Drawables/Textur 0. Einreisekleidung behält vorhandene Texturen. DLC/EUP und zusätzliche Texturen benötigen konfigurierte und live geprüfte Drawables/Oberteil-Arme-Paare; beliebige Kombinationen werden nicht automatisch passend gemacht.
- Bilder sind lokale freigestellte GTA-Render, exakt zu Geschlecht/Drawable/Textur zugeordnet und gemeinsam mit dem Inventar verwendet. 167 verkäufliche Produkte und weitere Farbvarianten sind abgedeckt; Kategorie-SVGs bleiben nur als Ersatz bei unbekannter Kleidung. Originalnamen, deutsche Ersatznamen, Quellen und Reimport: [Gegenstandskatalog](item-catalog.md). Die Live-Anprobe bleibt für Passform/Kombinationen maßgeblich.
- Bodenobjekte: Kategoriezuordnung in `rp_inventory/shared/clothing.lua`. Oberteil/Shirt, Jeans, Schuh, Hut, Brille, Ohrringe, Uhr, Bandana und Tasche erhalten passende GTA-Props. Ketten/Armbänder verwenden einen kleinen Beutel (`prop_paper_bag_small`). Fehlt ein Modell oder lädt es nicht innerhalb der begrenzten Wartezeit, dient derselbe Beutel als Ersatz. Modellnamen sind gegen die [ausgelesene GTA-Objektliste](https://github.com/DurtyFree/gta-v-data-dumps/blob/master/ObjectList.ini) geprüft. Die Props stellen die Kategorie dar, nicht das exakte Freemode-Drawable mit seiner Farbe. Alle ursprünglichen Kleidungs-/Itemmetadaten bleiben beim Ablegen und Aufheben erhalten.
- Die Boden-Lebensdauer und das frische Loslassen beginnen erst nach dem Inventarcommit: Eine vorherige Ausziehanimation verbraucht nicht mehr das Zeitfenster für die Wegwerfanimation. Bestehende Handbefestigung, Physik, Kollision, synchronisierte Ruheposition sowie Ablauf nach 30 Minuten bzw. Neustart bleiben erhalten.

## ESX-Vertrag

Geprüft: installierte **ESX Legacy 1.15.2**, `skinchanger`, offizielles [`esx_clotheshop`](https://github.com/esx-framework/ESX-Legacy-Addons/tree/main/%5Besx_addons%5D/esx_clotheshop) und [`esx_skin`](https://github.com/esx-framework/esx_core/tree/main/%5Bcore%5D/esx_skin). Der Standardladen kauft Skin-/Outfitänderungen, verwaltet aber keine einzeln handelbaren Kleidungsitems. Daher Erweiterung von **rp_commerce + rp_inventory**, ohne zweiten Provider, Library oder Vendor-Patch.

- Geld bleibt in ESX: `xPlayer.getAccount/removeAccountMoney`, vorhandener dauerhafter Bestellbeleg und Wiederherstellung. Keine direkten Online-Schreibzugriffe auf `users`.
- Darstellung: `skinchanger:getSkin/loadClothes`. Gesicht/Haare/Identität bleiben erhalten. Kein Modellwechsel und kein `esx_skin:save` in der Anprobe.
- `rp_inventory_stores.payload.items[slot].metadata.garment`: serverseitig eindeutige `id`, `sex`, `product`, `label`, `skin`. Andere Metadaten bleiben erhalten. Stacklimit 1.
- `payload.clothing = {version=1, sex, worn={category=garmentId}}` gehört zum **vollen charN-Identifier**. Angezogen-Zuordnung gehört dem Spielerbestand, nicht dem weitergegebenen Item. Beide Bestände und Outfit werden in derselben bestehenden SQL-Transaktion geschrieben.
- Einmalige Übernahme der Einreisekleidung aus `users.skin` beim Provider-Laden. Ohne genug Platz/Gewicht keine Teilübernahme: altes Aussehen bleibt, Taschen freimachen und neu verbinden. Der dauerhafte Versionsmarker verhindert wiederholte Starter-Geschenke.
- `users.skin` bleibt Gesichts-/Identitätsbasis, keine zweite Kleiderautorität. Auswahl und Spawn ergänzen das gespeicherte Outfit über `exports.rp_inventory:rpResolveClothing(characterIdentifier, baseSkin)`, auch bei ausgeloggten Charakteren.
- Fremdskripte, die Kleidung direkt aus `users.skin` lesen, benötigen diesen Overlay-Export. Freie Skin-/Uniform-Skripte sind **nicht automatisch mit Item-Eigentum kompatibel**: dauerhafte Kleidung als Items; temporäre Dienstkleidung braucht einen ausdrücklichen Adapter. Keinen zweiten Clotheshop-/Skin-Speicherkreis parallel aktivieren.
- Standard-`xPlayer.addInventoryItem('clothing_top', 1)` gibt ein katalogbasiertes Standardstück. Konkrete Varianten können vertrauenswürdige Serverressourcen als Metadaten vergeben. `rpExchange` bewahrt optionale, begrenzte Metadaten; Übergaben weiter atomar per `rpTransfer`/Inventaraktion, niemals remove-then-add.
- Outfitkäufe verwenden denselben `rp_commerce_orders`-Beleg und `rpExchange`, keine neue Shop-/Geldautorität. Serverprüfungen: erlaubter Laden, Modell, maximal zwölf verschiedene Kategorien, Katalogpreise, vollständige Slot-/Gewichtskapazität und ESX-Kontostand. Kein Teilkauf bei Platz-/Geldmangel. Metadaten und Angezogen-IDs werden zusammen in einer Inventartransaktion geschrieben. Die Option zum Anziehen ist Teil des dauerhaften Kaufbelegs und bleibt bei Wiederholung/Abholung unverändert. Die bestehende dokumentierte Grenze zwischen ESX-Geldpersistenz und Inventarcommit gilt weiter.

## Sicherheit und Betrieb

`S.mutate` normalisiert das Outfit nach jeder Änderung. Verlässt ein getragenes Item den Bestand, bleiben beide Store-Locks bis zum Animationsende bestehen. Mindestdauer, Session, Gesundheit, Entfernung und vorhandene Aktionsprüfungen bleiben maßgeblich. Fehlende/falsche Bestätigung, Disconnect, Tod, Charakterwechsel oder verlorener Containerzugriff brechen ab. Schließen/Wechseln der Ansicht allein beendet keine bereits angenommene Operation. Ihr ursprünglicher Ansichtstoken wird nur beim Eingang geprüft; Ablaufzeit, Charaktergeneration, Empfängerentfernung und Containerrechte werden weiterhin vor dem Commit geprüft. Neue Aktionen benötigen immer den aktuellen Ansichtstoken. Datenbankfehler laden den tatsächlichen SQL-Zustand nach. Eine manipulierte Clientbestätigung beweist keine sichtbare Animation; Eigentum/Geld bleiben serverseitig geprüft.

Kleidungssync nur bei Änderung plus Spawn-/Abschlussabgleich. Keine Idle-0ms-Schleife; nur aktive Kamera pro Frame. Begrenzte Animations-Wartezeit, Cleanup stellt Kamera und besessene Kleidung wieder her. Der Freeze-Zustand des Spielers wird vom Kleidungsladen nicht verändert.

Start: ESX/ox_lib/oxmysql/skinchanger vor `rp_core → rp_ui → rp_nativeui → rp_inventory → rp_characters / rp_commerce`. `rp_characters` nennt den Provider ausdrücklich als Dependency. **Vollständiger Serverneustart und Reconnect**, Inventarprovider nicht einzeln bei verbundenen Spielern neu starten. Keine neue SQL-Migration: versionierte Erweiterung des bestehenden JSON, keine Datenlöschung.

Browser: `npm run ui:preview`, **Kleidungsladen**, oder `http://127.0.0.1:5173/?preview=clothing`. Kamera-Steuerung und Demokäufe ohne FiveM, echte Peds nur im Spiel.

Tests: `tests/clothing.lua`, `tests/clothing-client.lua`, `tests/clothing-ui.py`, erweiterte Commerce-Tests, Inventar-/Creator-Regressionen sowie `npm run check` und `npm run ui:build`. Live noch prüfen: NPC-Fußhöhe/Interiors, Kleidungs-/Animationsdarstellung beider Modelle, Kamera an den Standorten, Mehrspielerübergabe und Reconnect zweier echter Charaktere.
