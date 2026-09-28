local N, owner = NativeMenu, GetCurrentResourceName()
local root, created, count = nil, false, 0
local function setup()
    if created then return end
    N.create(owner, 'demo_empty', { title = 'Los Santos', subtitle = 'LEERES MENÜ', description = 'Noch keine Einträge. Mit Zurück kommst du wieder ins Hauptmenü.', items = {} })
    N.create(owner, 'demo_nested', { title = 'Los Santos', subtitle = 'WEITERE OPTIONEN', items = {
        { id = 'info', label = 'Verschachteltes Untermenü', description = 'Zurück behält die vorherige Auswahl bei.' },
        { id = 'empty', label = 'Leeres Menü testen', type = 'submenu', menu = 'demo_empty' },
    } })
    N.create(owner, 'demo_settings', { title = 'Los Santos', subtitle = 'EINSTELLUNGEN', theme = 'mint', items = {
        { id = 'volume', label = 'Lautstärke', type = 'list', options = {
            { label = 'Leise', value = 25 }, { label = 'Normal', value = 50 }, { label = 'Laut', value = 100 },
        }, index = 2, description = 'Beispielauswahl mit Zahlenwerten. Verändert keine Spieleinstellungen.' },
        { id = 'nested', label = 'Weitere Optionen', type = 'submenu', menu = 'demo_nested' },
    } }, { onChange = function(id, value) print(('[rp_nativeui demo] %s = %s'):format(id, tostring(value))) end })
    N.create(owner, 'demo_dynamic', { title = 'Los Santos', subtitle = 'DYNAMISCHE DATEN', items = {} }, {
        onSelect = function(id) print('[rp_nativeui demo] Ausgewählt: ' .. id) end,
    })
    N.create(owner, 'demo_replaced', { title = 'Los Santos', subtitle = 'NEUES HAUPTMENÜ', description = 'Dieses Menü ersetzt den bisherigen Stapel. Zurück schließt es.', items = {
        { id = 'restart', label = 'Zum Testmenü', description = 'Öffnet das ursprüngliche Menü erneut.' },
    } }, { onSelect = function() N.open(root) end })
    root = N.create(owner, 'demo', { title = 'Los Santos', subtitle = 'INTERAKTIONSMENÜ', items = {
        { id = 'action', label = 'Aktion ausführen', description = 'Enter löst einen Callback aus und aktualisiert diese Zeile.', rightLabel = '0' },
        { id = 'gps', label = 'Schnellnavigation', type = 'list', options = {
            { label = 'Keine', value = 'none' }, { label = 'Flughafen', value = 'airport' }, { label = 'Shop', value = 'shop' },
        }, description = 'Mit ← und → auswählen, mit Enter bestätigen. Nur eine Demo, setzt keinen Wegpunkt.' },
        { id = 'notifications', label = 'Benachrichtigungen', type = 'checkbox', checked = true, description = 'Enter schaltet die Checkbox um.' },
        { id = 'settings', label = 'Einstellungen', type = 'submenu', menu = 'demo_settings', description = 'Untermenü mit Mint-Banner und weiterer Ebene.' },
        { id = 'dynamic', label = 'Dynamische Liste', type = 'submenu', menu = 'demo_dynamic', description = 'Der Callback baut die Einträge vor jedem Öffnen neu auf.' },
        { id = 'locked', label = 'Nicht verfügbar', disabled = true, description = 'Gesperrte Zeilen können nicht aktiviert werden.' },
        { id = 'reject', label = 'Abgelehnte Änderung', type = 'checkbox', checked = false, description = 'Dieser Callback gibt false zurück. Der Wert bleibt unverändert.' },
        { id = 'replace', label = 'Neues Hauptmenü öffnen', description = 'Ersetzt das Menü, statt ein Untermenü anzuhängen.' },
        { id = 'empty', label = 'Leeres Menü', type = 'submenu', menu = 'demo_empty' },
        { id = 'close', label = 'Schließen', description = 'Auch über einen Callback schließbar.' },
    } }, {
        onSelect = function(id, _, handle)
            if id == 'action' then
                count = count + 1
                local state = exports.rp_nativeui:rpGetMenuState(handle)
                state.definition.items[1].rightLabel = tostring(count)
                state.definition.items[1].description = ('Callback ausgeführt: %d Mal.'):format(count)
                N.update(owner, handle, { items = state.definition.items })
            elseif id == 'dynamic' then
                local items = {}
                for i = 1, 4 do items[i] = { id = 'entry_' .. i, label = 'Eintrag ' .. i, rightLabel = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) } end
                N.update(owner, owner .. '/demo_dynamic', { items = items })
            elseif id == 'replace' then N.open(owner .. '/demo_replaced')
            elseif id == 'close' then exports.rp_nativeui:rpCloseMenu()
            else print('[rp_nativeui demo] Bestätigt: ' .. id) end
        end,
        onChange = function(id, value)
            print(('[rp_nativeui demo] %s = %s'):format(id, tostring(value)))
            return id ~= 'reject'
        end,
        onClose = function(reason) print('[rp_nativeui demo] Geschlossen: ' .. reason) end,
    })
    created = true
end
RegisterCommand('rp_nativeui_test', function()
    setup()
    local ok, err = N.open(root)
    if not ok then print('[rp_nativeui] Testmenü konnte nicht geöffnet werden: ' .. tostring(err)) end
end, false)
