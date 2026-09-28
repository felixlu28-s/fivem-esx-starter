# Administration

**F10** oder **`/rp_admin`** öffnet das mintgrüne NativeUI für ESX **owner/admin**. F10 schließt auch aus Untermenüs; unter F12 → Administration umbelegbar. Pfeile, Enter und Backspace bedienen das Menü. Die Taste ist keine Berechtigung: normale Spieler werden serverseitig abgewiesen. txAdmin-Rechte allein ersetzen keine ESX-Gruppe.

- **Geld vergeben:** Empfänger standardmäßig du selbst; Enter auf Empfänger für eine andere Online-ID. Bargeld/Bankkonto wählen, Betrag mit Enter eingeben, „Geld vergeben“ bestätigen. Ganze Beträge 1–1.000.000, nur `money`/`bank`.
- **Items vergeben:** öffnet das vorhandene `/rp_items`-Menü von `rp_inventory`, inklusive Kategorien, Zielwahl und Mengen. Rückkehr zum Adminmenü über F10 nach Schließen der Itemverwaltung. Es gibt keinen zweiten Item-Vergabeweg.
- **Noclip umschalten:** verwendet das vorhandene ESX-Noclip. Menü erneut öffnen und Eintrag erneut bestätigen zum Ausschalten. ESX besitzt den Zustand; deshalb eine Umschaltaktion, keine möglicherweise falsche Checkbox. Seine Standardsteuerung/Bewegung bleibt unverändert, kein zweiter Noclip-Loop. Externe `/noclip`-/txAdmin-Modi bleiben unter deren eigener Verwaltung; dieses Menü behauptet keinen gemeinsamen Status und übernimmt nicht deren Cleanup.
- **Zum Wegpunkt teleportieren:** setzt einen vorhandenen Karten-Wegpunkt voraus und verwendet ESX `/tpm`. Der vorhandene ESX-Ablauf übernimmt Boden-/Kollisionssuche und Fahrzeuge. Vorher Noclip ausschalten, da dessen Positionsschleife sonst gegen den Teleport arbeitet. Einschränkungen des installierten ESX-Teleports gelten weiterhin.
- **Godmode:** temporäre lokale Unverwundbarkeit nach Serverfreigabe. Kein Heilen/Revive. Beim Tod, Pedwechsel, Logout oder Ressourcenstopp zurückgesetzt. Nur aktive Godmode-Admins erneuern alle zehn Sekunden ihre Berechtigung; ohne gültige Antwort endet sie spätestens nach 30 Sekunden. Keine Abfragen für alle Spieler oder pro Frame. Der vorherige Invincibility-Wert wird wiederhergestellt; parallel laufende Godmode-Tools sollten nicht gleichzeitig umschalten.

Direkt für deinen aktiven Charakter:

```text
/rp_money money 10000
/rp_money bank 50000
```

Der offizielle ESX-Befehl bleibt zusätzlich verfügbar: `/giveaccountmoney <Server-ID> money <Betrag>` bzw. `bank`.

## ESX-Vertrag / Sicherheit

Geprüft gegen installiertes **ESX Legacy 1.15.2**: `server/modules/commands.lua` (`giveaccountmoney`, `noclip`, `tpm`), `client/modules/events.lua` und `Core.IsPlayerAdmin`. Die Oberfläche ruft für Bewegung ausschließlich die vorhandenen ESX-Ereignisse auf; ESX prüft dort zusätzlich selbst die Berechtigung. Geld wird über `xPlayer.addAccountMoney` gebucht, niemals direkt in SQL oder im Inventar. Es gilt ESXs regulärer Speicherzyklus; keine eigene Kontenkopie, neue Migration oder Vendor-Änderung.

Netzwerkaktionen sind fest zugelassen und prüfen `source`, aktuelle Gruppe, Menü-Token, zehnminütige Gültigkeit und Rate-Limits. Zielwahl bindet die Server-ID an vollständige Charakterkennung und Logout-/Disconnect-Generation. Eine wiederverwendete Server-ID oder derselbe neu eingeloggte Charakter erbt keine alte Zielauswahl. Geldvergabe verwendet serverseitige Einmaltickets, identische Wiederholung der letzten Anfrage liefert nur dieselbe Antwort; abweichende Wiederverwendung wird abgelehnt. Online-ESX-Konten werden synchron über die offizielle API geändert. Konsolenlog enthält Akteur, Ziel, Konto und Betrag. Es gibt keine Garantie für sofortige Festplattenspeicherung bei FXServer-Absturz vor ESX-Save; keine automatische Wiederholung nach Ressourcen-/Serverneustart.

## Start / Tests

`ensure rp_admin` nach `rp_core`, `rp_ui`, `rp_nativeui`, `rp_inventory` und ESX/ox_lib. Beide Serverkonfigurationen sind ergänzt. Erstmalig in txAdmin `refresh` und `ensure rp_admin`; nach den gleichzeitigen NativeUI-/Inventaränderungen ist ein vollständiger Serverneustart mit Reconnect empfohlen.

Browser-Studio: **Administration**, direkt `http://127.0.0.1:5173/?view=admin`. Nur Darstellung und Navigation, keine echten Geld-/Spielaktionen. Wiederverwendet den vorhandenen Renderer und die zentrale Tastenzuordnung.

Tests: `tests/admin.lua` (Rechte, ESX-Konten, Replay, alte Ziel-/Charaktersitzungen), `tests/admin-client.lua` (echte NativeUI-Anbindung, Texteingabe, Umschalten, Cleanup), `tests/nativeui.lua` und `tests/admin-ui.py`. ESX-Noclip, Kollisionssuche beim Waypoint, Unverwundbarkeit und reale Schüsse müssen zusätzlich im FiveM-Client geprüft werden.
