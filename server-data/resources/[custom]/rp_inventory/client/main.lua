local ESX = exports.es_extended:getSharedObject()
local pending, opened = false, false
local function show(payload)
    if not ESX.IsPlayerLoaded() or not payload then return end
    if IsNuiFocused() and exports.rp_ui:rpGetView() ~= 'inventory' then return end
    opened = exports.rp_ui:rpOpen('inventory', Inventory.localizeCatalog(payload), false, { toggleAction = 'rp_inventory:open' })
end
local function open()
    if pending or Inventory.attachmentBusy or IsNuiFocused() or not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId()) then return end
    pending = true
    local ok, result = pcall(lib.callback.await, 'rp_inventory:open', false)
    if ok and result and result.ok then show(result.inventory)
    else lib.notify({ title = 'Inventar', description = 'Dein Inventar ist gerade nicht verfügbar.', type = 'error' }) end
    pending = false
end
local function register()
    exports.rp_ui:rpRegisterAction('rp_inventory:recipients', function(data)
        if exports.rp_ui:rpGetView() ~= 'inventory' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        local ok, result = pcall(lib.callback.await, 'rp_inventory:recipients', false, data.session)
        return ok and Inventory.localizeCatalog(result) or { ok = false, error = 'unavailable' }
    end)
    exports.rp_ui:rpRegisterAction('rp_inventory:action', function(data)
        if exports.rp_ui:rpGetView() ~= 'inventory' then return { ok = false, error = 'invalid_state' } end
        local ok, result = pcall(lib.callback.await, 'rp_inventory:action', false, data)
        return ok and Inventory.localizeCatalog(result) or { ok = false, error = 'unavailable' }
    end)
    exports.rp_ui:rpRegisterAction('rp_inventory:refresh', function()
        if exports.rp_ui:rpGetView() ~= 'inventory' then return { ok = false, error = 'invalid_state' } end
        local ok, result = pcall(lib.callback.await, 'rp_inventory:refresh', false)
        return ok and Inventory.localizeCatalog(result) or { ok = false, error = 'unavailable' }
    end)
end
CreateThread(register)
AddEventHandler('onClientResourceStart', function(resource) if resource == 'rp_ui' then register() end end)
AddEventHandler('rp_core:inputPressed', function(action) if action == 'rp_inventory:open' then CreateThread(open) end end)
RegisterCommand('rp_inventory', function() CreateThread(open) end, false)
RegisterNetEvent('rp_inventory:show', function(payload) if source == 65535 then show(payload) end end)
RegisterNetEvent('rp_inventory:refresh', function(payload)
    if source == 65535 and exports.rp_ui:rpGetView() == 'inventory' then show(payload) end
end)
RegisterNetEvent('rp_inventory:hide', function()
    if source == 65535 and exports.rp_ui:rpGetView() == 'inventory' then exports.rp_ui:rpClose() end
end)
RegisterNetEvent('rp_inventory:effect', function(effect)
    if source ~= 65535 or type(effect) ~= 'table' then return end
    if effect.kind == 'drop' then return end -- Ground prop owns the synchronized hand release.
    if effect.kind == 'weapon' then
        Inventory.selectWeapon(effect)
        return
    end
    if effect.kind == 'attachment' then
        Inventory.animateAttachment(effect)
        return
    end
    CreateThread(function()
        local ped = PlayerPedId()
        local dict, clip = 'pickup_object', 'pickup_low'
        if effect.kind == 'drink' then dict, clip = 'mp_player_intdrink', 'loop_bottle'
        elseif effect.kind == 'eat' then dict, clip = 'mp_player_inteat@burger', 'mp_player_int_eat_burger'
        elseif effect.kind == 'heal' then dict, clip = 'amb@world_human_clipboard@male@idle_a', 'idle_c' end
        RequestAnimDict(dict)
        local deadline = GetGameTimer() + 2500
        while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(25) end
        if HasAnimDictLoaded(dict) then TaskPlayAnim(ped, dict, clip, 4.0, -4.0, 1600, 49, 0.0, false, false, false) end
        if effect.kind == 'heal' then SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + 15)) end
        -- Compatible with standard esx_status when installed; no hunger system is silently added.
        if GetResourceState('esx_status') == 'started' then
            if effect.kind == 'drink' then TriggerEvent('esx_status:add', 'thirst', 200000)
            elseif effect.kind == 'eat' then TriggerEvent('esx_status:add', 'hunger', 200000) end
        end
        Wait(1700)
        StopAnimTask(ped, dict, clip, 1.0)
        RemoveAnimDict(dict)
    end)
end)
CreateThread(function()
    while true do
        if opened and exports.rp_ui:rpGetView() ~= 'inventory' then opened = false TriggerServerEvent('rp_inventory:close') end
        Wait(250)
    end
end)
AddEventHandler('esx:onPlayerLogout', function() opened = false if exports.rp_ui:rpGetView() == 'inventory' then exports.rp_ui:rpClose() end end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TriggerServerEvent('rp_inventory:close') end
end)
