# Gemeinsame Interaktionshinweise

Der Hinweis blendet mit einer langsam beginnenden Deckkraftkurve in 480 ms ein; die kurze Aufwärtsbewegung von 0,55 rem läuft über 560 ms. Ausblenden bleibt bei 180 ms. Er startet nahe seiner Endposition, nicht am Bildschirmrand. Ein erneutes Betreten während des Ausblendens kehrt den Übergang um; geänderte Inhalte lösen keine neue Einblendung aus. Bei reduzierter Bewegung entfällt die Animation. Beim Öffnen einer anderen Oberfläche wird der Hinweis sofort entfernt, damit er kein Menü überlagert.

Shops, Werkbänke und aufhebbare Bodenitems verwenden die Client-Exports von `rp_ui`. Bestehende Startfolge: `es_extended` → `rp_core` → `rp_ui` → Fachressourcen. Die Anzeige nimmt keinen Fokus; fachliche Aktionen und Zugriffsprüfungen gehören weiter auf den Server.

Eine Fachressource meldet ihren nächstgelegenen nutzbaren Punkt alle 200 ms:

```lua
exports.rp_ui:rpShowInteraction({
    action = 'rp_commerce:interact', -- bereits bei rp_core registrierte eigene Aktion
    label = '24/7 · Strawberry',
    verb = 'Einkaufen',
    icon = 'shop', -- shop, craft oder bag
    distance = distance,
})
-- Beim Verlassen:
exports.rp_ui:rpHideInteraction()
```

Jeder Aufrufer besitzt nur seinen eigenen Hinweis; die Aktion muss mit seinem Ressourcennamen beginnen. Die Entfernung muss endlich und zwischen 0 und 100 sein. Die Fachressource entscheidet über ihre tatsächliche Reichweite: Shops, Ammu-Nation und Werkbänke 1,25 m, Bodenitems 1,35 m einschließlich Höhenabstand. Dieselben Radien werden serverseitig geprüft. Die Fachressource meldet ausschließlich darstellbare Punkte; Zugangsprüfung und Aktionen bleiben serverseitig abgesichert.

Bei mehreren Hinweisen gewinnt der nächstgelegene. Ohne Erneuerung verfällt ein Hinweis nach 700 ms; beim Ressourcenstopp wird er entfernt. Die Anzeige prüft alle 100 ms, sendet nur Änderungen und nimmt niemals NUI-Fokus. Sie verschwindet bei geöffneten Menüs, Pause, Tod, ausgeloggenen Spielern und ausgeblendetem Spielbild.

`exports.rp_ui:rpIsInteractionActive(action)` prüft dieselbe Auswahl einschließlich aufrufender Resource und Sichtbarkeit. In `rp_core:inputPressed` vor einer Kontextaktion aufrufen: Shop und Aufheben haben beide standardmäßig E, aber nur der sichtbare Hinweis darf reagieren. Beide Aktionen lassen sich einzeln umbelegen; die bestehenden Konfliktregeln gelten beim Umbelegen weiter.

Die Tastenkappe verwendet die aktuelle Belegung aus `rp_core`, einschließlich Mausbelegungen. Bei unbelegter Aktion wird auf die Einstellungen verwiesen. Keine fest eingetragene Ersatz-Taste. Die UI erhält den validierten Nachrichtentyp `ui:interaction` mit `{label, verb, icon, key}` beziehungsweise `false` zum Ausblenden.

Vorschau: `http://127.0.0.1:5173/?preview=interaction`. Lua-Prüfung: `lua5.4 tests/interaction.lua`; Browserprüfung: `python tests/studio-ui.py`. Die tatsächliche Näheerkennung und Darstellung während Spielbewegung zusätzlich im FiveM-Client prüfen.
