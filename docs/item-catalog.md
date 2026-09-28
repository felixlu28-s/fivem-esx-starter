# GTA-Gegenstandsbilder und Namen

## Eingebundener Stand

- **110 Waffen-/Ausrüstungseinträge** aus der Cfx-Liste der tragbaren GTA-Waffen, ohne `WEAPON_UNARMED`. Dazu gehören Nahkampf-, Schuss- und Wurfwaffen sowie Kanister, Feuerlöscher und das Hacking-Gerät. Fahrzeuggeschütze, interne Schadensursachen und ausschließlich in GTA Enhanced verfügbare Modelle sind keine Inventarwaffen dieser Liste.
- **1.293 Kleidungsbilder**, passend nach Freemode-Geschlecht, Kategorie, Drawable und Textur. Das Paket deckt alle **167 verkäuflichen Varianten** des bestehenden Sortiments und zahlreiche Farbvarianten der Einreisekleidung ab. Es importiert bewusst nicht sämtliche DLC-Kleidung als Verkaufsangebot.
- Männer-Schuhe Drawable 13/Textur 0 liefert in zwei Bildquellen nur eine transparente, leere Fläche. Dieser bisherige Katalogeintrag bleibt für gespeicherte Items lesbar, ist aber ausgeblendet im Laden. Bestehende Kleidung wird nicht gelöscht oder umgefärbt.
- Alle **1.403 Bilder** liegen lokal unter `rp_ui/web/public/catalog` (rund 32 MB). Keine CDN-Aufrufe beim Spielen. Der Browser erhält nur einen Katalogschlüssel; der Renderer kann keine beliebige Bild-URL aus Metadaten laden. Die SVG-Ansicht verwendet die transparenten Bildgrenzen, ohne die Originaldateien umzucodieren.

## Vollständiger Bildvorrat für weitere Kleidung

Zusätzlich zum aktiven Spielpaket liegt der vollständige gepinnte Reizenkun-Index
mit **38.310 Originaldateien** lokal in [assets/clothing-library](../assets/clothing-library/README.md).
Beide Geschlechter, sämtliche dort vorhandenen Texturen und alle 17 Quellgruppen
sind enthalten. Das Verzeichnis liegt außerhalb der FiveM-Ressourcen: ungenutzte
Bilder vergrößern weder den Join-Download noch den React-/Lua-Katalog.

`python tools/import-item-artwork.py --prefetch-all-clothing` lädt den Vorrat und
prüft Bilddateien sowie Indexabdeckung. `--verify-clothing-library` prüft die
gesamte lokale Sammlung per SHA-256. Nach Ergänzung von Sortiment/Einreisekleidung
übernimmt der normale Import die passenden Bilder bevorzugt aus diesem Vorrat;
mit `--offline` sind Netzwerkzugriffe ausgeschlossen. Anschließend wie üblich
prüfen und NUI bauen. Unveränderte ESX-Legacy-1.15.2-Verträge, keine neuen Items,
Migrationen oder Netzwerk-Events. Der Bestand entspricht dem Quellstand vor
2025-02 und ist keine Behauptung, alle späteren GTA-DLCs abzudecken. Leere
Quelldateien werden im Manifest gekennzeichnet, nicht als Produktbild verwendet.
`tests/clothing-library.py` ergänzt in einem temporären Katalog zwei bisher
ungenutzte Modelle für Mann/Frau und prüft den vollständigen Import bei gesperrtem
Netzwerk, unveränderte Bildbytes, kleinen Laufzeitkatalog und Prüfsummenfehler.

## Namen und Varianten

Waffen verwenden die deutschen GTA-Sprachdaten aus dem DurtyFree-Dump. Bei Kleidung liefert `v-clothingnames` englische Bezeichnungen und GTA-GXT-Schlüssel, **keinen vollständigen deutschen Namensdatensatz**. Der deutsche GTA-Client löst vorhandene Schlüssel über `GetLabelText` auf. Derselbe Helfer wird für Laden, aktuelles Outfit, eigenes Inventar und externe Bestände verwendet. Fehlende/ungeladene Originaltexte verwenden nachvollziehbare deutsche Übersetzungen aus `tools/catalog/clothing-de.json`; unbekannte Varianten behalten Kategorie/Modell/Farbe als Bezeichnung. Diese Ersatznamen sind keine behaupteten Originalübersetzungen. Andere GTA-Sprachen überschreiben die deutschen Ersatznamen nicht.

Eine Farbe wird niemals vom Produktnamen oder einer veralteten `garment.product`-Referenz abgeleitet: Entscheidend sind **`metadata.garment.sex` und `metadata.garment.skin`**. Shop und Inventar verwenden denselben Bildschlüssel. Bestehende Metadaten bleiben erhalten; nur ihre Darstellung wird ergänzt. Neue/custom Kleidung ohne importierten Bildschlüssel erhält ein Kategorie-Symbol, kein Bild einer anderen Variante.

Es bleiben **zwölf generische ESX-Kleidungsitems** (`clothing_top`, `clothing_pants` usw.). Zusätzliche Bild-/Namensdaten erzeugen keine zusätzlichen ESX-Items und keine Datenbankzeilen je Modell/Farbe. Das Studio verwendet automatisch exportierte echte Produkte und Preise.

## ESX, Waffen und Shops

Geprüfte Basis: installiertes **ESX Legacy 1.15.2**, dessen `shared/config/weapons.lua` und offizieller Custom-Inventory-Bridge. Vendor-Ressourcen bleiben unverändert. `rp_inventory` bleibt alleiniger Provider; `xPlayer.addInventoryItem` / bestehende atomare Inventaroperationen bleiben der Zugang. Keine neue SQL-Migration und kein zweites Loadout. Der Renderer ist weiterhin zentral in `rp_ui`.

`shared/weapon_catalog.lua` enthält importierte Bezeichnungen/Modelle, `shared/weapons.lua` die eigenen Gewichte, Munitionstypen und Verbrauchsregeln. Die zwei bestehenden Waffen und Munitionsitems behalten ihre IDs/Gewichte/Stapel. Neue Munitionsfamilien ergänzen MPs, MGs, Schrot, Scharfschützen, Minigun, Raketen, Granatwerfer, Railgun, EMP, Leucht- und Schneeballwerfer. Gemeinsame Munition verwendet weiterhin einen Familien-Stapel; unterschiedliche Waffen dieser Familie können unterschiedliche native Magazingrößen haben. Preise und Gewichte sind konfigurierbare RP-Werte, keine aus GTA übernommenen Wirtschaftsregeln.

Das bestehende Magazin-Vorauszahlungsmodell bleibt bestehen: kein neuer Serveraufruf pro Kugel. Nahkampf/Ausrüstung benötigt keine Munition; Elektroschocker und Up-n-Atomisierer nutzen ihre native Wiederaufladung mit Besitzprüfung. Eine Wurfwaffe ist selbst das Verbrauchsitem und wird **vor dem Wurf atomar entnommen**. Eine bezahlte Freigabe überlebt die Zustandsmeldung, die das letzte lose Item entfernt. Kanister/Feuerlöscher werden beim ersten Gebrauch als gefüllte Verbrauchseinheit entnommen und geben ein begrenztes Kontingent von 4.500 nativen Einheiten frei. Vorbezahlte Restmengen werden nicht als Items erstattet und sind nicht übertragbar; kein leerer/nachfüllbarer Kanister wird hier zusätzlich erfunden. Absturz/Logout verliert ungenutzte Kontingente wie bei bisherigen Munitionsvorauszahlungen.

Die vorhandenen periodischen Munitionsprüfungen bleiben RAM-basiert. Schadensereignisse prüfen Besitz und bezahlte Kontingente; Schrot/Explosivwaffen erhalten begrenzte Mehrtreffer-Toleranz. Bezahlte Projektile behalten ihre Freigabe auch während Flug/Zündverzögerung und nach späteren Inventaränderungen: maximal zehn Minuten und 64 zurückliegende Kontingente je Sitzung. Sehr spät gezündete Sprengladungen außerhalb dieses Fensters benötigen eine gesonderte Projektilverwaltung. Das ist **kein vollständiges Anti-Cheat**: verfehlte Schüsse, Explosionen außerhalb von `weaponDamageEvent` und manipulierte Clientmeldungen beweisen nicht den tatsächlichen Verbrauch. Es gibt keine neue automatische Bannentscheidung.

Alle Einträge sind unter **`/rp_items` → Waffen** verfügbar und im vorhandenen **`/rp_weaponshop`**-Editor platzierbar. Die Commerce-Ressource lädt dieselben schreibgeschützten Itemdefinitionen für ihren Angebotskatalog. Bestehende Ladenpositionen, Auslagen, Preise und Lizenzprüfungen werden nicht überschrieben. Neue Waffen werden erst durch bewusstes Platzieren zu einem Verkaufsangebot. Aufsätze bleiben die bisher konfigurierten kompatiblen Aufsatzitems; dieser Import erfindet nicht automatisch sämtliche GTA-Komponentenitems.

Startreihenfolge bleibt ESX → `rp_core` / `rp_ui` / `rp_nativeui` → `rp_inventory` → `esx_addoninventory` und `rp_commerce`. Nach Installation einmal vollständig neu starten und neu verbinden. Ein älterer GTA-Build kann neuere Modelle nicht enthalten; der Client prüft `IsWeaponValid` vor dem Eintrag ins Waffenrad und meldet dies beim Benutzen. Der Import erzwingt keinen neuen Gamebuild.

## Quellen, Reimport und Prüfung

- [Reizenkun/gtav-fivem-clothes](https://github.com/Reizenkun/gtav-fivem-clothes): 1.270 unveränderte Kleidungsrender.
- [Colbss/FiveM-ClothingData](https://github.com/Colbss/FiveM-ClothingData): 23 ergänzende Render der Base-Collection.
- [root-cause/v-clothingnames](https://github.com/root-cause/v-clothingnames): GXT-Zuordnungen/englische Namen; bekannte Lücken bleiben kenntlich.
- [DurtyFree/gta-v-data-dumps](https://github.com/DurtyFree/gta-v-data-dumps): Waffennamen auf Deutsch, Modell- und Munitionstypen.
- [overextended/ox_inventory](https://github.com/overextended/ox_inventory): 104 unveränderte Waffenbilder; Repository-Lizenz liegt als `catalog/ox-inventory-LICENSE.txt` bei. Es wird kein ox_inventory-Code oder zweiter Provider installiert.
- [Cfx Weapon Models](https://docs.fivem.net/docs/game-references/weapon-models/): Liste der aufgenommenen Handwaffen und sechs ergänzende Waffenbilder.

Die Spielmodelle/GTA-Marken stammen von Rockstar Games. Die Render wurden von den genannten Projekten bereitgestellt. `catalog/sources.json` enthält pro Datei URL und SHA-256 sowie die gepinnten Git-Revisionen. Rechte an diesen Fremdassets werden durch unseren Code nicht neu lizenziert.

Reimport: `python tools/import-item-artwork.py` in einer Entwickler-Python-Umgebung mit `lupa` und `Pillow`. Pillow liest ausschließlich Bildgröße/Alphagrenzen; die Bilddateien bleiben bytegleich. Downloads werden in der ignorierten `.codex-log/catalog-sources` zwischengespeichert. Nach neuem Sortiment zuerst Bildabdeckung prüfen, danach `npm run check` und `npm run ui:build` ausführen. Generierte Lua-/JSON-Dateien nicht von Hand pflegen. Die manuelle deutsche Ersatzübersetzung liegt separat und bleibt beim Import erhalten.

Tests: `tests/item-catalog.lua`, `tests/item-catalog-client.lua`, `tests/item-labels.lua` (Lua 5.4/Lupa), `tests/item-artwork-ui.py` (Playwright, Vite auf 5173). Sie prüfen alle Waffenfamilien, letzte Verbrauchsitems, Wiederholungen, Bildintegrität, Varianten/Metadaten, deutsche Namensauflösung, beide Geschlechter und 720p/1080p/4K/Ultrawide sowie Bilder beim Ziehen. Die bestehenden Inventar-, Commerce- und Kleidungsregressionen bleiben zusätzlich maßgeblich. Native Modellverfügbarkeit, echte GTA-Schuss-/Wurfmechanik und die geladenen GXT-Texte benötigen den abschließenden FiveM-Livetest.
