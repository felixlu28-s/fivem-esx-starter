local I = RP.Input
local ESX = exports.es_extended:getSharedObject()
local storageKey = 'rp_bindings_v1:' .. GetConvar('rp_input_profile', 'fivem-esx-starter')
local bindings, revision, previous, owners = I.defaults(), 1, {}, {}
local stored = GetResourceKvpString(storageKey)
if stored then
    local ok, decoded = pcall(json.decode, stored)
    if ok and type(decoded) == 'table' then
        -- Keep valid resource actions before their owner registers after rp_core.
        for id, key in pairs(decoded) do
            if type(id) == 'string' and id:match('^rp_[%w_]+:[%w_]+$') and type(key) == 'string'
                and (key == '' or (I.byKey[key] and not I.byKey[key].reserved)) then bindings[id] = key end
        end
    end
end
local heldKeys, installedKeys = {}, {}
local received, dispatched, lastKey = 0, 0, '-'
local mapperNames = { BACKSPACE = 'BACK', OEM_PLUS = 'EQUALS', OEM_COMMA = 'COMMA', OEM_MINUS = 'MINUS', OEM_PERIOD = 'PERIOD' }
local function ready()
    return ESX.IsPlayerLoaded() and not IsNuiFocused() and not IsPauseMenuActive() and not IsScreenFadedOut()
end
local function releaseActions()
    for id, held in pairs(previous) do
        if held then TriggerEvent('rp_core:inputReleased', id) end
    end
    previous = {}
end
local function press(id)
    if previous[id] then return end
    previous[id] = true
    dispatched = dispatched + 1
    TriggerEvent('rp_core:inputPressed', id)
end
local function keyDown(key)
    received, lastKey = received + 1, key
    if heldKeys[key] then return end
    heldKeys[key] = true
    if not ready() then return end
    for _, action in ipairs(I.actions) do
        if bindings[action.id] == key then press(action.id) end
    end
end
local function keyUp(key)
    heldKeys[key] = nil
    for _, action in ipairs(I.actions) do
        if bindings[action.id] == key and previous[action.id] then
            previous[action.id] = nil
            TriggerEvent('rp_core:inputReleased', action.id)
        end
    end
end
local function installBindings()
    for _, action in ipairs(I.actions) do
        local key = I.byKey[bindings[action.id]]
        if key and not key.reserved and not key.control and not installedKeys[key.id] then
            local id = key.id
            -- New namespace isolates these mappings from earlier console-bind experiments.
            local command = 'rp_core_mapped_v3_' .. id
            RegisterCommand('+' .. command, function() keyDown(id) end, false)
            RegisterCommand('-' .. command, function() keyUp(id) end, false)
            -- RegisterKeyMapping is the supported resource API in production clients.
            -- One stable mapping per used key lets F12 change actions immediately without
            -- attempting to overwrite a user's persisted native mapping or running rbind.
            RegisterKeyMapping('+' .. command, 'RP Eingabe: ' .. key.label .. ' (Aktionen unter F12)',
                'keyboard', mapperNames[id] or id)
            installedKeys[id] = true
        end
    end
end
local function snapshot()
    local actions, keys = {}, {}
    for _, a in ipairs(I.actions) do
        actions[#actions + 1] = { id = a.id, label = a.label, category = a.category, description = a.description,
            defaultKey = a.default, key = bindings[a.id] or '', context = a.context }
    end
    for _, k in ipairs(I.keys) do keys[#keys + 1] = { id = k.id, label = k.label, row = k.row, width = k.width, reserved = k.reserved } end
    return { actions = actions, keys = keys, revision = revision }
end
exports('rpGetBindings', snapshot)
exports('rpSetBinding', function(id, keyId, confirmed, expectedRevision)
    if expectedRevision ~= revision then return { ok = false, error = 'stale_bindings', bindings = snapshot() } end
    local nextBindings, err = I.rebind(bindings, id, keyId, confirmed == true)
    if not nextBindings then return { ok = false, error = err, bindings = snapshot() } end
    releaseActions()
    bindings, revision = nextBindings, revision + 1
    installBindings()
    SetResourceKvp(storageKey, json.encode(bindings))
    TriggerEvent('rp_core:bindingsChanged')
    return { ok = true, bindings = snapshot() }
end)
exports('rpResetBindings', function(expectedRevision)
    if expectedRevision ~= revision then return { ok = false, error = 'stale_bindings', bindings = snapshot() } end
    releaseActions()
    bindings, revision = I.defaults(), revision + 1
    installBindings()
    SetResourceKvp(storageKey, json.encode(bindings))
    TriggerEvent('rp_core:bindingsChanged')
    return { ok = true, bindings = snapshot() }
end)
exports('rpRegisterInputAction', function(data)
    local owner = GetInvokingResource()
    if not owner or type(data) ~= 'table' or type(data.id) ~= 'string'
        or data.id:sub(1, #owner + 1) ~= owner .. ':' or not data.id:match('^rp_[%w_]+:[%w_]+$') or I.byAction[data.id]
        or type(data.label) ~= 'string' or #data.label < 1 or #data.label > 80
        or not I.byKey[data.defaultKey] or I.byKey[data.defaultKey].reserved then return false end
    local a = { id = data.id, label = data.label, category = type(data.category) == 'string' and data.category or 'Weitere',
        description = type(data.description) == 'string' and data.description or data.label,
        default = data.defaultKey, context = 'all' }
    I.actions[#I.actions + 1], I.byAction[a.id], owners[a.id] = a, a, owner
    bindings[a.id], revision = bindings[a.id] or a.default, revision + 1
    installBindings()
    TriggerEvent('rp_core:bindingsChanged')
    return true
end)

installBindings()

-- Keyboard input comes from FiveM's mapper, not the build-dependent raw-key buffer.
-- Mouse controls retain their existing polling path; focus changes release held actions.
CreateThread(function()
    while true do
        if ready() then
            for _, a in ipairs(I.actions) do
                local key = I.byKey[bindings[a.id]]
                if key and key.control then
                    local held = IsDisabledControlPressed(0, key.control)
                    if held then press(a.id)
                    elseif previous[a.id] then
                        previous[a.id] = nil
                        TriggerEvent('rp_core:inputReleased', a.id)
                    end
                end
            end
        else releaseActions() end
        Wait(0)
    end
end)

RegisterCommand('rp_input_status', function()
    print(('[rp_core] Input backend=keymapping-v3 received=%d dispatched=%d lastKey=%s'):format(received, dispatched, lastKey))
    print(('[rp_core] Input: loaded=%s nui=%s pause=%s faded=%s'):format(
        tostring(ESX.IsPlayerLoaded()), tostring(IsNuiFocused()), tostring(IsPauseMenuActive()), tostring(IsScreenFadedOut())))
    for _, action in ipairs(snapshot().actions) do
        print(('[rp_core] %s = %s'):format(action.id, action.key ~= '' and action.key or '(unbelegt)'))
    end
end, false)

AddEventHandler('onResourceStop', function(resource)
    for index = #I.actions, 1, -1 do
        local a = I.actions[index]
        if owners[a.id] == resource then
            if previous[a.id] then TriggerEvent('rp_core:inputReleased', a.id) end
            I.byAction[a.id], owners[a.id], previous[a.id] = nil, nil, nil
            table.remove(I.actions, index)
            revision = revision + 1
        end
    end
end)
