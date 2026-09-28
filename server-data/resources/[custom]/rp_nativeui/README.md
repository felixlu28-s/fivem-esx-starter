# rp_nativeui

Wiederverwendbare **Client-Lua-API** für kompakte GTA-Interaktionsmenüs. React, CSS und sämtliche NUI-Callbacks bleiben in `rp_ui`. Kein zweites Browserfenster, keine Datenbank und keine eigenen ESX-Spielerdaten.

## Start und Test

`ensure rp_nativeui` nach `ensure rp_ui`, vor konsumierenden Resources. Der Eintrag ist in `server.cfg.example` enthalten. Konsumenten deklarieren `dependency 'rp_nativeui'` in ihrem Manifest. Nach UI-Änderungen im Root `npm run ui:build` ausführen.

- Im Spiel: **`/rp_nativeui_test`**, in F8 ohne `/`.
- Browser: `npm run ui:preview`, links **NativeUI**; direkt `http://127.0.0.1:5173/?view=nativeui`.
- **↑ / ↓** auswählen, **← / →** Listen ändern, **Enter** ausführen/Checkbox umschalten, **Backspace oder Esc** zurück; im Hauptmenü schließen. Maus, Mausrad, Tab und Buchstabensuche bedienen das Menü nicht. Gehaltenes Enter/Zurück löst keine Mehrfachaktionen aus.
- Während das Menü offen ist, bleiben Laufen, Sprinten, Springen, Fahren und Kamerabewegung verfügbar. Die Menüsteuerung wird gegenüber GTA-Telefon/Pause abgefangen; Enter löst nicht gleichzeitig Ein-/Aussteigen aus. Andere Maus-UIs wie das Inventar behalten exklusiven Fokus.
- Demo: Aktion mit Zähler, Werteliste, Checkbox, gesperrter Eintrag, abgelehnte Änderung, verschachtelte Untermenüs, dynamische Liste, leeres Menü, Hauptmenü ersetzen und Schließen. Keine realen Zahlungen oder Änderungen an Spieleinstellungen. Lua-Callbacks schreiben zusätzlich in F8.

## Beispiel in einer Client-Datei

```lua
local ui = exports.rp_nativeui
local details = assert(ui:rpCreateMenu('details', {
    title = 'Los Santos', subtitle = 'FAHRZEUG', theme = 'mint',
    items = {
        { id = 'lights', label = 'Licht', type = 'checkbox', checked = false },
        { id = 'color', label = 'Farbe', type = 'list', index = 1, options = {
            { label = 'Schwarz', value = 'black' },
            { label = 'Weiß', value = 'white' },
        } },
    },
}, {
    onChange = function(id, value, index, handle)
        print(id, value, index, handle)
        -- false lehnt die Änderung ab und stellt den bisherigen Wert wieder her.
    end,
}))

local main = assert(ui:rpCreateMenu('garage', {
    title = 'Los Santos', subtitle = 'GARAGE', visibleRows = 7,
    description = 'Wähle ein Fahrzeug.',
    items = {
        { id = 'options', label = 'Fahrzeugoptionen', type = 'submenu', menu = details },
        { id = 'request', label = 'Fahrzeug anfordern', rightLabel = 'Elegy',
          description = 'Verfügbarkeit und Besitz werden vom Server geprüft.' },
    },
}, {
    onSelect = function(id, item, handle)
        if id ~= 'request' then return end
        -- Hier den vorhandenen, servervalidierten Domain-Callback aufrufen.
        -- Niemals Fahrzeugbesitz, Preise oder Berechtigungen aus der UI übernehmen.
        print('Anfrage', item.id, handle)
    end,
    onClose = function(reason, handle)
        print('Menü geschlossen', reason, handle)
    end,
}))

RegisterCommand('rp_garage_menu', function()
    local ok, reason = ui:rpOpenMenu(main)
    if not ok then print('Menü nicht verfügbar:', reason) end
end, false)
```

Handles sind `aufrufende_resource/id`. Nur dieselbe Resource darf ihre Menüs ändern, öffnen, zerstören oder miteinander verschachteln. Ein geöffnetes fremdes Menü oder eine andere aktive UI führt zu `false, 'ui_busy'`. Erstellen ist auch bei geschlossener UI möglich. Es gibt keine globalen NetEvents zum Öffnen oder Ausführen von Menüs.

Optional `rpOpenMenu(handle, { toggleAction = 'rp_admin:open' })`: eine über `rp_core` registrierte eigene Aktion schließt den gesamten Menübaum über dieselbe aktuell belegte Taste. Aktionspräfix muss zur aufrufenden Resource gehören. Untermenüs erben die Belegung, Wiederholung wird ignoriert; Eingaben bleiben an Sitzung/Revision gebunden. Ohne diese Option sind nur die normalen Navigationstasten aktiv. Das Adminmenü nutzt standardmäßig F10. Die Option ändert keine serverseitigen Rechte.

## Exporte und Daten

| Client-Export | Ergebnis / Verhalten |
| --- | --- |
| `rpCreateMenu(id, definition, callbacks?)` | Handle oder `nil, Fehlercode`; doppelte IDs abgelehnt |
| `rpOpenMenu(handle)` | `true` oder `false, Fehlercode`; ersetzt eigenen Menüstapel |
| `rpPushMenu(handle)` | Eigenes Untermenü öffnen, Elternauswahl bleibt erhalten |
| `rpUpdateMenu(handle, patch)` | Titel, Untertitel, Beschreibung, Theme, sichtbare Zeilen oder Items ändern |
| `rpSetItems(handle, items)` | Ganze Zeilenliste ersetzen; Auswahl bleibt anhand der Zeilen-ID erhalten |
| `rpGetMenuState(handle)` | Kopie von `{ definition, selected, open }`, fremdes/unbekanntes Handle: `nil` |
| `rpCloseMenu()` | Eigenen aktiven Menüstapel schließen; ohne eigenes Menü: `false` |
| `rpDestroyMenu(handle)` | Definition löschen; ist sie im Stapel, diesen vorher schließen |

`definition`: `title` erforderlich, `subtitle` optional (Standard `INTERAKTIONSMENÜ`), `description`, `visibleRows` (3–12, Standard 7), `items` (auch leer erlaubt, maximal 200). Das Banner ist immer mintgrün; `theme` kann entfallen oder explizit `mint` sein. Andere Themes werden abgelehnt.

Jede Zeile hat eine eindeutige `id` (Buchstaben/Ziffern/Unterstrich/Bindestrich), `label`, optional `description`, `rightLabel`, `disabled`. `type` ist `action` (Standard), `list`, `checkbox` oder `submenu`. Liste: `options = { { label, value }, ... }`, `index` **1-basiert**; 1–100 Optionen, Werte String/Zahl/Boolean. Checkbox: `checked` Boolean. Untermenü: `menu` mit eigenem vollständigen Handle oder lokaler Menü-ID. Verschachtelung maximal 12 Ebenen; Zyklen werden abgewiesen. Titel/Untertitel/Zeilentext/Beschreibung sind auf 100/120/180/600 UTF-8-Bytes begrenzt. Lange Zeilen werden visuell gekürzt.

`rpUpdateMenu` ersetzt nur übergebene Definitionsfelder. Leere Strings leeren Texte. Eine neue `items`-Liste muss vollständig sein; wegfallende Auswahl wird auf einen gültigen Index begrenzt. Rückgaben sind `true` bzw. `false, Fehlercode`. `rpGetMenuState` ist eine Kopie: Änderungen daran erst mit `rpUpdateMenu` übernehmen.

### Callbacks

Optional pro Zeile: `hint = { keys = {'W','A','S','D'}, label = 'Waffe begutachten', detail = 'Loslassen zum Zurückfedern' }`. Der zentrale Renderer zeigt für die ausgewählte Zeile einen separaten Hinweis unten rechts; ohne `hint` verschwindet er. 1–4 Tastenbeschriftungen mit maximal 8 Zeichen, Label 1–100 und Detail maximal 120 Zeichen. Rein visuell, keine neuen Eingabebindings oder Callbacks. Ammu-Nation nutzt diesen Baustein auch auf den Zeilen seines Waffen-Untermenüs.

- `onSelect(itemId, itemCopy, handle)`: Enter auf Aktion, Liste oder Untermenü; vor dem automatischen Öffnen eines Untermenüs. Gut geeignet, dessen Daten vorher per `rpSetItems` aufzubauen. `false` verhindert das Öffnen. Wer selbst ein anderes Menü öffnet, erhält kein zusätzliches automatisches Untermenü.
- `onChange(itemId, value, index, handle)`: Pfeile auf einer Liste bzw. Enter auf Checkbox. Bei Checkbox ist `index = nil`. Enter auf einer Liste bestätigt zusätzlich über `onSelect`.
- `onHighlight(itemId, itemCopy, handle)`: Nach Auswahlwechsel mit ↑/↓, beispielsweise für die Ammu-Nation-Kamera. Nur eine Kopie des Eintrags; Rückgabewert steuert keine Menüaktion. Die erste Auswahl beim Öffnen und die Rückkehr aus Untermenüs steuert der Konsument ausdrücklich selbst. Lange/ladende Arbeit in einen eigenen Thread legen.
- `onClose(reason, handle)`: Beim Zurückgehen aus dieser Ebene oder beim vollständigen Schließen. Gründe: `back`, `api`, `replaced`, `destroyed`, `logout`. Bei Resource-Stop wird still aufgeräumt, ohne gestoppte Callbacks aufzurufen.

Callbacks werden mit `pcall` geschützt. Fehler bzw. `false` lehnen eine Auswahländerung ab; explizite spätere `rpUpdateMenu`-Änderungen haben Vorrang. Während ein Callback läuft, werden weitere Tasteneingaben verworfen. Callbacks daher kurz halten: länger dauernde Datenabfragen in einem eigenen Thread durchführen, die betreffende Zeile vorher deaktivieren und nach der Antwort aktualisieren. **Nicht** in einem Callback auf eine weitere Menüeingabe warten. Die zentrale NUI-Brücke antwortet nach spätestens 20 Sekunden mit Timeout; sie kann eine bereits laufende fachliche Aktion nicht rückgängig machen.

Beim Stop des Besitzers oder UI-Neustart wird die Ansicht freigegeben. Menüdefinitionen bleiben beim UI-Neustart in `rp_nativeui` erhalten und können wieder geöffnet werden; bei Neustart von `rp_nativeui` müssen Konsumenten ihre Handles neu erstellen. Keine Polling-Threads nötig. NUI akzeptiert nur bekannte Tasten für die aktuelle Sitzung und Revision; alte Antworten lösen keine zweite Aktion aus. Das ist Schutz vor veralteter UI-Bedienung, **keine Berechtigungsprüfung für Gameplay**.

## ESX-Vertrag und Grenzen

Geprüft gegen die installierte **ESX Legacy 1.15.2**: `ESX.UI.Menu.RegisterType` / `ESX.UI.Menu.Open` liegen im offiziellen `es_extended/client/functions.lua`; ESX bietet außerdem [esx_context](https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/esx_context/main.lua). Diese APIs und Vendor-Dateien bleiben unverändert. Unsere Resource ist eine Präsentations-API für neue eigene Menüs, **kein Drop-in-Ersatz** für `ESX.UI.Menu.Open('default', ...)` oder fremde NativeUI-Bibliotheken. Solche Scripts benötigen einen expliziten Aufrufadapter oder weiterhin ihren bisherigen Renderer.

ESX besitzt weiterhin Charakter, Job, Konten und Inventar. Diese Resource speichert nichts davon. Für Spielaktionen bleiben Servercallbacks der zuständigen Domain erforderlich: `source`, Besitz, Rechte, Abstand, Zustand und Rate-Limit dort prüfen. `disabled` im Menü ersetzt diese Prüfung nicht. Datenbankänderungen sind für diese Resource nicht nötig.

`rp_ui:rpOpen(view, payload, locked, { keyboardOnly = true })` fokussiert nur die Tastatur, ohne Cursor, und aktiviert `SetNuiFocusKeepInput(true)` für gleichzeitige Spielbewegung. Ein nur währenddessen laufender Control-Guard fängt Menü-/Telefon-/Pausensteuerung ab. Schließen, Wechsel zu einer Mausansicht und Resource-Stopp setzen die Eingabeweitergabe zurück. Grundlage: [Cfx Fullscreen NUI](https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/). Die Renderdateien sind `rp_ui/web/src/views/NativeMenu.tsx` und `nativeui.css`; die validierte Typdefinition ist `lib/nativeui.ts`. Der Browser verwendet dieselbe Ansicht, simuliert aber die Lua-Callbacks lokal.

## Prüfungen

Im Root: `npm run check`, `npm run ui:build`, `npm run check:runtime`, `lua5.4 tests/nativeui.lua`. Mit laufendem Vite und Python/Playwright/Chrome: `python tests/nativeui-ui.py`. Native Fokus, Sounds und Zusammenspiel mit anderen laufenden FiveM-Resources zusätzlich im Spiel mit dem Testbefehl prüfen.
