# Server-Ladebildschirm

Beim Verbinden zeigt `rp_ui` eine eigenständige GTA-inspirierte Los-Santos-Illustration mit langsamer Kamerabewegung, Mint-/Offwhite-Typografie, wechselnden Hinweisen und dezenter Ladezeile. Alle Bilder, Schriften und Skripte werden lokal mitgeliefert. Kein Videostream, keine externen Dienste, keine neue Library, keine zusätzliche Serverlast pro Spieler.

## Vorschau und Anpassungen

- `npm run ui:preview` → **Server-Ladebildschirm** unter Einreise.
- Direktstart: `npm run ui:loading`. Läuft der Vite-Server bereits, direkt `http://127.0.0.1:5173/loading.html?preview=1` öffnen.
- Studio-Direktlink: `http://127.0.0.1:5173/?preview=loadscreen`.
- Die explizite lokale Vorschau simuliert Fortschritt und wiederholt ihn. `/loading.html` ohne Parameter verarbeitet ausschließlich echte Events und wartet ansonsten.
- Name, Überschrift, Hinweise, Bildpfad und Wechselintervall: `server-data/resources/[custom]/rp_ui/web/src/loading/config.ts`.
- Layout: `web/src/loading/loading.css`; Farben und Schriften stammen aus dem gemeinsamen UI-Standard. Anpassungen anschließend mit `npm run ui:build` bauen.
- Artwork: `server-data/resources/[custom]/rp_ui/web/public/loading/los-santos-arrival.png` (1672 × 941, ca. 2,27 MB). Das UI skaliert bis 4K; das Bild wird passend flächig skaliert und zugeschnitten.

Nach Installation Manifest/Clientskripte über einen Serverneustart übernehmen und neu verbinden. Bereits verbundene Spieler erhalten keinen nachträglich eingeblendeten Ladebildschirm. `rp_ui` ist bereits in der Startreihenfolge vorhanden. Kein zweites Loadscreen-Resource parallel aktivieren. Die vorhandene `server.cfg` und ihre Vorlage deaktivieren mit `setr sv_showBusySpinnerOnLoadingScreen false` den zusätzlichen GTA-Busy-Spinner.

## Lebenszyklus und ESX-Kompatibilität

Geprüfte Basis: installierte ESX Legacy **1.15.2**, `es_extended/client/modules/events.lua`, eigener Multicharakter-Einstieg in `rp_characters/client/main.lua`. ESX lädt/speichert den aktiven Charakter weiterhin selbst. Standardereignisse `esx:onPlayerSpawn`, `esx:restoreLoadout` und `esx:loadingScreenOff` bleiben erhalten. Keine Accounts, Slotlimits, Skin-/Inventardaten oder Datenbanktabellen werden verändert.

Der [offizielle FiveM-Ladebildschirm](https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/) verwendet einen eigenen Browserframe und `loadscreen_manual_shutdown 'yes'`. Der zweite Vite-Einstieg lädt nur die Ladeansicht und gemeinsame Basiskomponenten, kein Handy/Inventar/Creator.

Der Balken folgt dem [nativen `loadProgress`-Event](https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/loadProgress/), begrenzt auf 0–1 und ohne Rücksprünge. Er zeigt den Spieldatenfortschritt, keine erfundene Restzeit und keinen prozentualen Charakter-Login. 100 % kann daher bereits erreicht sein, während die Einreise vorbereitet wird. Frühe Nachrichten werden noch vor React in einem einzigen Snapshot gepuffert. Es werden keine Logzeilen, Dateinamen, Spieler-IDs oder Serveradressen eingeblendet.

Sobald die Clientscripts laufen, meldet `rp_characters` die Phasen `session` und `scene`. Wenn die Charaktervorschau vorbereitet ist, bei Fehlern, bei bereits geladenem Charakter und nach dem Spawn ruft es `rpFinishLoading` auf. Das beendet den GTA-Ladezustand, blendet den Frame 600 ms aus und entfernt ihn nach 650 ms, unabhängig von Browserantworten. Wiederholte Aufrufe sind wirkungslos. Fokus und Loginberechtigung bleiben beim bestehenden Charakter-/UI-System.

Ein einmaliger Watchdog entfernt den Frame spätestens 120 Sekunden **nach Clientskriptstart** auch bei fehlendem Abschlusssignal. Er beendet ausschließlich die Darstellung und erklärt keinen Charakter für geladen. Er kann Fehler während Downloads, vor dem Start der Clientscripts oder im ESX-Login nicht reparieren. Beim Stop von `rp_ui` erfolgt sofortiges Cleanup. Keine permanenten Client- oder Serverloops; die laufenden CSS-Animationen verschwinden mit dem Frame. Reduzierte Bewegung wird respektiert.

## Prüfung

```text
npm run check
npm run ui:build
lua5.4 tests/loading-client.lua
lua5.4 tests/character-client.lua
python tests/loading-ui.py
```

Browserprüfung benötigt Playwright, Chrome und Vite auf Port 5173. Abgedeckt: echte/frühe Fortschrittsmeldungen, ungültige Werte, monotone Phasen, keine künstliche Live-Steigerung, transparenter Abschluss, sechs Auflösungen von schmaler Vorschau bis 4K/Ultrawide, reduzierte Bewegung und Studio. Lua-Prüfung deckt doppelte Übergaben, fehlende Browserantwort, Watchdog, Ressourcenstop und Fokusverträglichkeit ab.

Noch im FiveM-Client prüfen: vollständiger Erstdownload, Join mit leerem Account bis Creator, Auswahl mehrerer Charaktere, direkter Login und tatsächliches Überblenden ohne Fokusverlust. Browser-/Lua-Tests ersetzen diesen Live-Test nicht.

## Herkunft des Bildes

Neu erstellt mit dem eingebauten **Imagegen-Tool**, ohne extern heruntergeladenes Rockstar-Artwork. Das Original bleibt im Codex-Ausgabeordner; die oben angegebene Projektkopie wird im Build ausgeliefert. Verwendeter Prompt:

```text
Use case: stylized-concept. Asset type: full-screen FiveM roleplay loading-screen background, landscape 16:9, ideally 3840x2160. Create an ORIGINAL high-end Grand Theft Auto V loading-screen style illustration of Los Santos at golden hour. Hand-painted digital promotional art, confident fine dark outlines, sharp shapes with smooth painterly shading, realistic cinematic proportions, sun-bleached cream, warm peach sky, deep sage palm shadows, restrained mint accents. Scene: a beautiful panoramic Los Santos city street with a classic muted sage-green coupe parked prominently in the right foreground facing left, palm trees framing the boulevard and recognisable downtown towers receding in atmospheric haze in the center-right distance, sun low to the upper right. Car seen three-quarter side, beautiful chrome and believable wheels. A single casually dressed adult traveler with a small duffel stands by the car, on the right half, looking toward the city, not toward camera. Layout requirement: reserve leftmost 38 percent as visually quiet deep green foliage/building shadows suitable for large white headline overlay added separately by code; keep bottom 18 percent dark and uncluttered to support loading status overlay; make the city and car richly detailed in the right two thirds. Entire artwork edge to edge, no panels, no borders. Feels like an authentic polished GTA loading illustration, welcoming city arrival and grounded roleplay, no weapons or police. Absolutely NO text, NO letters, NO logos, NO watermarks, NO progress bars or UI. Keep image crisp and vibrant, no blur, no photorealistic screenshot, no cartoon caricatures.
```
