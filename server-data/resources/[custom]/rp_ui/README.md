# rp_ui

Gegenstandsansichten verwenden den lokalen gemeinsamen `CatalogImage`-Renderer für Kleidungs- und Waffenbilder. Datenquellen, deutsche Bezeichnungen, sichere Bildschlüssel und Browserprüfungen: [GTA-Gegenstandskatalog](../../../../docs/item-catalog.md). ESX-/Inventarzustand bleibt in den jeweiligen Domain-Ressourcen; die NUI entscheidet keine Artikelzuordnung, Preise oder Bestände.

Zentrale React-/TypeScript-NUI und eigener FiveM-Ladebildschirm. Abhängigkeit: `rp_core`; Start vor den fachlichen Ressourcen, insbesondere `rp_characters`.

- Spieloberflächen: `web/dist/index.html`, `rpOpen` / `rpClose`, typisierte Nachrichten aus `web/src/lib/nui.ts`.
- Verbindungsbildschirm: `web/dist/loading.html`, eigener schlanker Vite-Einstieg. [Konfiguration, Übergabe, Tests und Artwork](../../../../docs/loading-screen.md).
- [Verbindlicher UI-Standard](../../../../docs/ui-design.md) und [Browser-Studio](../../../../docs/ui-studio.md).

ESX Legacy **1.15.2** bleibt für Charakterladen, Spawn und Spielzustand zuständig. Der Ladebildschirm nutzt die native FiveM-Loading-Screen-Schnittstelle; kein zweites Login, keine Änderung an Vendor-Ressourcen, keine Datenbank oder neuen Serveraktionen. `rp_characters` schließt die Darstellung über `exports.rp_ui:rpFinishLoading()`, sobald die Vorschau bereitsteht bzw. bei einem Fehler oder abgeschlossenem Spawn. Der normale ESX-Multicharakter-/Spawnvertrag bleibt erhalten.

Lokale Exports für den Ladebildschirm:

```lua
exports.rp_ui:rpLoadingPhase('session') -- alternativ 'scene'; nur Anzeige
exports.rp_ui:rpFinishLoading()         -- idempotent, 600 ms Ausblenden, Freigabe nach 650 ms
```

`SendLoadingScreenMessage` bedient einen separaten FiveM-Frame. Seine eigenen Nachrichten folgen dem Typ `LoadingScreenMessage` (`action = 'ui:loading'`); FiveMs `eventName = 'loadProgress'` wird separat validiert. Die Gameplay-NUI nimmt diese Nachrichten nicht als Menübefehle an.

Build und Vorschau: im Projektroot `npm run check`, `npm run ui:build`, `npm run ui:preview`. Der Build erzeugt **beide** HTML-Einstiege. Keine zusätzliche `ensure`-Zeile nötig.
