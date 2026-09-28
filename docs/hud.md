# Ingame-HUD

Dezente GTA-nahe Anzeige oben rechts: kompakte Bargeldanzeige mit Geldbörsensymbol, darunter getrennte transparente Flächen für Spielerzahl/Server-ID und Sprachreichweite/Sprechstatus. Kein äußerer Gesamtkasten. Der gemeinsame Farbtoken `--ui-hud-surface` erhält die Lesbarkeit auch vor hellen Straßen. Kleine Schrift, sparsame Mint-Akzente und weiche Farbwechsel beim Sprechen. Beim Erscheinen blendet das HUD in 380 ms sanft ein; reduzierte Bewegung deaktiviert die Animation. GTA-Safe-Zone und gemeinsame Skalierung bis 4K bleiben erhalten. Kein Eingabefokus. Bei Pause, ausgeblendetem Spielbild, Logout, Charaktererstellung und großen Menüs bleibt es verborgen. Mit NativeUI und dem Interaktionshinweis kann es gleichzeitig sichtbar sein.

## Datenquellen

- **Bargeld:** installierte ESX Legacy 1.15.2, `ESX.GetPlayerData().accounts`, Konto `money`. ESX aktualisiert dieses Konto über seinen normalen `esx:setAccountMoney`-Vertrag. Die Anzeige liest jeweils aktuelle Daten; keine eigene Geldverwaltung, Datenbankabfragen oder Änderungen an Vendor-Code. Fehlendes Konto wird als „—“ angezeigt, ein echter Nullsaldo als `$ 0`.
- **Spielerzahl:** `rp_core/server/presence.lua` zählt alle mit dem Server verbundenen Spieler per `GetPlayers()` alle zwei Sekunden und publiziert nur Änderungen als `GlobalState['rp_core:playerCount']`. Einschließlich Spielern in anderen Routing-Buckets und der Charakterauswahl; nicht die Zahl lokal gestreamter Peds. Keine Identifikatoren werden übertragen.
- **ID:** temporäre FiveM-Server-ID über `GetPlayerServerId(PlayerId())`, kein Account- oder Charakteridentifier.
- **Sprache:** FiveMs [Mumble-Verbindung](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/MumbleIsConnected.md), [Talker-Proximity](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/MumbleGetTalkerProximity.md) und [Sprechstatus](https://github.com/citizenfx/natives/blob/master/NETWORK/NetworkIsPlayerTalking.md). „Bereit“ bedeutet verbunden, aktuell nicht sprechend; „Spricht“ ist zusätzlich mint hervorgehoben. „Offline“ bedeutet nicht mit Mumble verbunden, beispielsweise bei deaktiviertem Sprachchat. Das ist keine Prüfung der Mikrofonhardware oder Lautstärkemessung.
- **Optional pma-voice:** Wenn gestartet, wird dessen [proximity.distance](https://github.com/AvarianKnight/pma-voice/blob/main/docs/state-getters/stateBagGetters.md) genutzt. Andernfalls gilt die native Reichweite. Nicht konfigurierte/ungültige Reichweiten erscheinen als „—“, ohne erfundene Standardmeter. Kein Voice-System wird installiert oder konfiguriert. SaltyChat/TeamSpeak braucht später einen separaten Adapter; Radio und Telefon werden nicht als räumliche Hörweite dargestellt.

## Einbindung

Darstellung und lesende Client-Anbindung liegen in `rp_ui/client/hud.lua`, `web/src/components/GameHud.tsx`, `web/src/hud.css` und `web/src/lib/hud.ts`. Der Client prüft alle 150 ms, sendet nur geänderte Daten über den validierten NUI-Typ `ui:hud`. `false` blendet aus. Browser-Reload und Ressourcenstopp werden berücksichtigt. Keine neuen Netzwerk-Endpunkte, persistenten Daten oder Ressourcen. Die vorhandene Startreihenfolge `es_extended` → `rp_core` → `rp_ui` bleibt bestehen.

Vorschau: `npm run ui:preview`, links **HUD**, optional **GTA · Straßenszene** als Hintergrund. Direkt: `http://127.0.0.1:5173/?preview=hud`.

Prüfungen: `npm run check`, `npm run ui:build`, `lua5.4 tests/hud.lua` sowie `python tests/hud-ui.py` bei laufendem Vite/Chrome/Playwright. Live noch prüfen: Kontobewegung durch Einkauf, echte Mikrofoneingabe, Voice-Verbindungswechsel, Join/Disconnect eines zweiten Spielers und Darstellung bei eigenen GTA-Safe-Zone-Einstellungen.
