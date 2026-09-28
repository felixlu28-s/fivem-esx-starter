RP = RP or {}
RP.Input = { keys = {}, actions = {} }
local I = RP.Input
local function key(id, label, vk, row, width, reserved)
    I.keys[#I.keys + 1] = { id = id, label = label, vk = vk, row = row, width = width or 1, reserved = reserved or false }
end
key('ESCAPE', 'Esc', 27, 0, 1, true)
for n = 1, 12 do key('F' .. n, 'F' .. n, 111 + n, 0, 1, n == 8) end
key('OEM_5', '^', 220, 1)
for n = 1, 9 do key(tostring(n), tostring(n), 48 + n, 1) end
key('0', '0', 48, 1)
key('OEM_4', 'ß', 219, 1)
key('OEM_6', '´', 221, 1)
key('BACKSPACE', '⌫', 8, 1, 1.8)
key('TAB', 'Tab', 9, 2, 1.5)
for letter in ('QWERTZUIOP'):gmatch('.') do key(letter, letter, string.byte(letter), 2) end
key('OEM_1', 'Ü', 186, 2)
key('OEM_PLUS', '+', 187, 2)
key('CAPITAL', 'Caps', 20, 3, 1.8)
for letter in ('ASDFGHJKL'):gmatch('.') do key(letter, letter, string.byte(letter), 3) end
key('OEM_3', 'Ö', 192, 3)
key('OEM_7', 'Ä', 222, 3)
key('RETURN', 'Enter', 13, 3, 1.8)
key('LSHIFT', 'Shift', 160, 4, 1.6)
key('OEM_102', '<', 226, 4)
for letter in ('YXCVBNM'):gmatch('.') do key(letter, letter, string.byte(letter), 4) end
key('OEM_COMMA', ',', 188, 4)
key('OEM_PERIOD', '.', 190, 4)
key('OEM_MINUS', '-', 189, 4)
key('RSHIFT', 'Shift', 161, 4, 2)
key('LCONTROL', 'Strg', 162, 5, 1.3)
key('LWIN', 'Win', 91, 5, 1, true)
key('LMENU', 'Alt', 164, 5, 1.2)
key('SPACE', 'Leertaste', 32, 5, 6)
key('RMENU', 'Alt Gr', 165, 5, 1.3, true)
key('RCONTROL', 'Strg', 163, 5, 1.3)
for _, k in ipairs({
    {'INSERT', 'Einfg', 45}, {'HOME', 'Pos1', 36}, {'PRIOR', 'Bild ↑', 33},
    {'DELETE', 'Entf', 46}, {'END', 'Ende', 35}, {'NEXT', 'Bild ↓', 34},
    {'LEFT', '←', 37}, {'UP', '↑', 38}, {'DOWN', '↓', 40}, {'RIGHT', '→', 39},
}) do key(k[1], k[2], k[3], 6) end
for n = 0, 9 do key('NUMPAD' .. n, 'Num ' .. n, 96 + n, 7) end
for _, k in ipairs({ {'MULTIPLY','Num *',106}, {'ADD','Num +',107}, {'SUBTRACT','Num -',109}, {'DECIMAL','Num ,',110}, {'DIVIDE','Num /',111} }) do key(k[1], k[2], k[3], 7) end

local function action(id, label, category, default, description)
    I.actions[#I.actions + 1] = { id = id, label = label, category = category, default = default,
        context = 'all', description = description or label }
end
action('rp_player:me', 'Mein Charakter', 'Menüs', 'M', 'Identität, Beruf und deine Fitnessübersicht öffnen.')
action('rp_ui:settings', 'Einstellungen', 'Menüs', 'F12', 'Einstellungen und Tastenbelegung öffnen.')
action('rp_inventory:open', 'Inventar', 'Menüs', 'I', 'Deine Taschen und Behälter in deiner Nähe öffnen.')

for _, mouse in ipairs({ {'MOUSE1', 'Linksklick', 24}, {'MOUSE2', 'Rechtsklick', 25}, {'MOUSE3', 'Mausrad', 348}, {'WHEELUP', 'Rad ↑', 241}, {'WHEELDOWN', 'Rad ↓', 242} }) do
    key(mouse[1], mouse[2], 0, 8)
    I.keys[#I.keys].control = mouse[3]
end

I.byKey, I.byAction = {}, {}
for _, k in ipairs(I.keys) do I.byKey[k.id] = k end
for _, a in ipairs(I.actions) do I.byAction[a.id] = a end
function I.defaults()
    local result = {}
    for _, a in ipairs(I.actions) do result[a.id] = a.default end
    return result
end
function I.validate(input)
    if type(input) ~= 'table' then return nil end
    local result = {}
    for id, value in pairs(input) do
        if not I.byAction[id] or type(value) ~= 'string' or (value ~= '' and (not I.byKey[value] or I.byKey[value].reserved)) then return nil end
        result[id] = value
    end
    for _, a in ipairs(I.actions) do if result[a.id] == nil then result[a.id] = a.default end end
    return result
end
function I.conflicts(bindings, id, keyId)
    local ids = {}
    if keyId == '' then return ids end
    for _, a in ipairs(I.actions) do if a.id ~= id and bindings[a.id] == keyId then ids[#ids + 1] = a.id end end
    table.sort(ids)
    return ids
end
function I.rebind(bindings, id, keyId, confirmed)
    if not I.byAction[id] or type(keyId) ~= 'string' or (keyId ~= '' and (not I.byKey[keyId] or I.byKey[keyId].reserved)) then return nil, 'invalid_binding' end
    if bindings[id] == keyId then return bindings, nil, {} end
    local conflicts = I.conflicts(bindings, id, keyId)
    if #conflicts > 0 and not confirmed then return nil, 'binding_conflict', conflicts end
    local nextBindings = {}
    for k, v in pairs(bindings) do nextBindings[k] = v end
    for _, conflict in ipairs(conflicts) do nextBindings[conflict] = '' end
    nextBindings[id] = keyId
    return nextBindings, nil, conflicts
end
