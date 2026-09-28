# Gemeinsame Projektfunktionen

`lib/portrait_camera.lua` ist die gemeinsame Factory `RpPortraitCamera()` für Creator und Anprobe: `update(input)`/`close()`. Ressourcen laden sie als Client-Script und besitzen ihre Kamera selbst; Cleanup bei Schließen/Resource-Stop bleibt Pflicht. Vertrag, Konfiguration und Grenzen: [Kleidungssystem](../../../../docs/clothing.md).

## Vernetzte Szenen-NPCs

`rpProtectNetworkPed(entity)` und `rpReleaseNetworkPed(entity)` sind **Server-Exports** für vernetzte Aufgaben-NPCs, z. B. den Garagenfahrer. Nur die registrierende Server-Resource darf übernehmen/freigeben; Spieler-Peds und andere Entity-Typen werden abgelehnt. Die servergeschriebene `GlobalState['rp_core:networkPeds']`-Liste schützt Modell/Net-ID vor der Ambient-Bereinigung. Kein Client-NetEvent registriert solche NPCs. Resource-Stop entfernt die eigenen Fahrer und ihren Schutz. Der Besitzer muss nach erfolgreichem Ende ebenfalls löschen/freigeben. Diese aktiv geführten Szenen erhalten keine konkurrierenden lokalen Ambient-Gesten; normale Empfangs-/Shop-NPCs verwenden weiterhin `rpProtectPed` und `rpConfigureNpc`. Siehe [Garagenvertrag](../rp_vehicles/README.md).

`rp_core` besitzt unter anderem Eingaben, Weltzeit, NPC-Unterdrückung und die gemeinsame NPC-Interaktion. Die vorhandenen Manifest-Abhängigkeiten (`es_extended`, `skinchanger`, `ox_lib`, `oxmysql`) bleiben unverändert. Domains starten nach `rp_core`; kein zusätzliches NPC-Script notwendig.

## Lebendige Projekt-NPCs

Jeder lokale Nichtspieler-Ped, den eine Projektresource über `rpProtectPed` registriert, erhält automatisch das Profil `generic`: kurzes Hinschauen, Begrüßung und gelegentliche freundliche Gesten/Sprachzeilen. Normale Shops nutzen `shop`, Ammu-Nation mit verschränkten Armen `ammunation`. Die bestehenden Grundhaltungen werden von der erzeugenden Resource verwaltet; soziale Gesten liegen zeitlich begrenzt als Oberkörper-/Sekundäranimation darüber. Keine Positionskorrektur, kein Drehen des ganzen NPCs, kein Ersetzen der gespeicherten Bodenanker.

```lua
-- Nach dem Erzeugen eines lokalen NPCs; die Resource bleibt Eigentümerin.
exports.rp_core:rpProtectPed(ped)
exports.rp_core:rpConfigureNpc(ped, {
    profile = 'shop',                 -- generic / shop / ammunation
    key = 'reception:cityhall',        -- stabiler lokaler Schlüssel, maximal 100 Zeichen
    paused = false,
})

-- Beim Platzieren oder während eigener Dialog-/Missionsanimationen:
exports.rp_core:rpConfigureNpc(ped, { paused = true })
-- Danach wieder aktivieren:
exports.rp_core:rpConfigureNpc(ped, { paused = false })

-- Nach bestätigten Service-Aktionen: gemeinsame Geste/Sprachzeile vormerken.
exports.rp_core:rpReactNpc(ped, 'acknowledge') -- Nicken / Danke
exports.rp_core:rpReactNpc(ped, 'farewell')    -- Verabschiedung

-- Vor DeleteEntity; bei Resource-Stop erfolgt das Cleanup ebenfalls.
exports.rp_core:rpReleasePed(ped)
DeleteEntity(ped)
```

Alle Exports liefern einen Boolean. Nur die registrierende Resource darf konfigurieren/freigeben; fremde Übernahme, Spieler-Peds und vernetzte Peds werden abgelehnt. `key` wird mit der Resource-Namespace kombiniert und erhält die Begrüßungssperre über Stream-/Modellwechsel. Ohne eigenen Schlüssel gilt der lokale Ped-Handle. Neue NPCs müssen diese bestehenden APIs verwenden, damit sowohl Ambient-Schutz als auch gemeinsame Interaktion greifen. Für eigene Szenen rechtzeitig pausieren; keine zweite Begrüßungssteuerung parallel betreiben.

Explizite Reaktionen über `rpReactNpc` bleiben ebenfalls an Resource-Besitz, Nähe, Sicht, Pause und die gemeinsamen Sprach-/Gestenabstände gebunden. Pro NPC höchstens eine vorgemerkte Aktion, Verfall nach zwölf Sekunden; kein Netzwerkereignis und keine zusätzliche Polling-Schleife. Pausieren/Logout entfernt ausstehende Reaktionen. Vernetzte aktiv geführte Fahrer spielen ihre kurzen Übergabegesten innerhalb ihrer bereits geprüften Scene-Schritte, ohne die lokale Ambient-Steuerung parallel auf diesen Ped anzuwenden.

Konfiguration: `shared/npcs.lua`. Standardwerte:

- Näher als 6 m, gleicher Innenraum und freie Sicht; Besuch endet außerhalb 8 m oder nach fünf Sekunden ohne Sichtkontakt. Nur der nächste sichtbare NPC spricht den Spieler an.
- Kurze Reaktionsverzögerung beim Eintreten; maximal eine Begrüßung pro Besuch und frühestens nach 60 Sekunden erneut. Streamwechsel umgehen diesen Timer bei stabilem Schlüssel nicht.
- Alle 35–65 Sekunden eine kleine Geste, davon etwa jede dritte zusätzlich mit einer Sprachzeile. Zufällige Intervalle und wechselnde Gesten; kurze Blicke alle 8–14 Sekunden.
- Mindestens 6,5 Sekunden zwischen Sprachstarts und vier Sekunden zwischen Gestenstarts über alle registrierten NPCs dieses Clients. Laufende NPC-Sprache wird nicht unterbrochen. Grundhaltung bleibt beim Ende der Sekundäranimation bestehen.
- Weibliche/männliche NPCs verwenden passende generische Gesten-Dictionaries. Ammu-Nation behält seine Gunstore-Animationen. GTA-Sprachausgabe stammt aus dem jeweiligen Ped-Modell; nicht jedes Fremdmodell unterstützt jeden Sprachkontext. Es werden keine erfundenen Sprachdateien oder externen Libraries benötigt.

Eine gemeinsame Client-Prüfung alle 750 ms, nur registrierte/gestreamte NPCs, keine neue Ped-Pool-Abfrage, keine Server-RPCs und keine dauerhaften Frame-Schleifen. Animation-Dictionaries laden höchstens zwei Sekunden mit 50-ms-Wartezeit. Ausstreamen, Modellwechsel, Tod, Logout, Pausieren und Resource-Stop brechen laufende/ausstehende Gesten ab. Die Besitzerresource bleibt für Entities und deren eigene Idle-/Scenario-Aufgaben verantwortlich.

ESX-Integration: Installierte Legacy-Version **1.15.2** und der vorhandene `rp_commerce`-/ESX-Shopadapter geprüft. Die installierten ESX-Funktionen stellen keinen gemeinsamen Verkäufer-Begrüßungsdienst bereit. Die Erweiterung ist rein lokale Darstellung und nutzt `ESX.IsPlayerLoaded()`; ESX-Charakter-/Geld-/Inventarverträge und Vendor-Dateien bleiben unverändert. Keine neuen Events für Clients zum Server, keine Datenbankänderung.

Native-Referenzen: [GTA-Sprachausgabe](https://raw.githubusercontent.com/citizenfx/natives/master/AUDIO/PlayPedAmbientSpeechNative.md), [Blickkontakt](https://raw.githubusercontent.com/citizenfx/natives/master/TASK/TaskLookAtEntity.md), [Animationsflags](https://raw.githubusercontent.com/citizenfx/natives/master/TASK/TaskPlayAnim.md). Tests: `tests/npc-social.lua` (gemeinsame Logik und echte Schutz-Exports), `tests/weaponshop-client.lua` (Shop-/Editorintegration), `tests/input-player.lua` (Ambient-Cleanup). Native-Stubs ersetzen keine FiveM-Prüfung: Stimmen, Animationsübergänge und Kombinationen mit Clipboard-/anderen Scenarios noch mit den konkreten männlichen/weiblichen Modellen ingame ansehen.
