local C, ESX = Commerce.Config, exports.es_extended:getSharedObject()
local pending, active, blips = false, nil, {}
local animation = 'amb@world_human_hammering@male@base'
local function stopAnimation() StopAnimTask(PlayerPedId(), animation, 'base', 2.0) end
local function registerInput()
    exports.rp_core:rpRegisterInputAction({ id = 'rp_commerce:interact', label = 'Shop / Werkbank öffnen',
        category = 'Interaktionen', defaultKey = 'E', description = 'Einen Laden oder eine Werkbank in deiner Nähe öffnen.' })
end
local function nearest(kind)
    local p, found, closest = GetEntityCoords(PlayerPedId()), nil, C.radius
    for id, venue in pairs(C.venues) do
        local d = #(p - vector3(venue.coords.x, venue.coords.y, venue.coords.z))
        if (not kind or kind == venue.kind) and d <= closest then found, closest = id, d end
    end
    return found, closest
end
local function show(data)
    if not data or not ESX.IsPlayerLoaded() or (IsNuiFocused() and exports.rp_ui:rpGetView() ~= 'commerce') then return end
    if exports.rp_ui:rpOpen('commerce', exports.rp_inventory:rpLocalizeCatalog(data), false, { toggleAction = 'rp_commerce:interact' }) then active = data.session end
end
local function open(kind)
    if pending or Commerce.Weapons.client.dev or IsNuiFocused() or not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId()) then return end
    local id = nearest(kind)
    if not id then return end
    pending = true
    local ok, result = pcall(lib.callback.await, 'rp_commerce:open', false, id)
    pending = false
    if ok and result and result.ok then
        local venue = C.venues[id]
        if venue and venue.clothing then
            if not Commerce.Clothing.open(id, result.commerce) then TriggerServerEvent('rp_commerce:close', result.commerce.session) end
        elseif venue and venue.weaponshop then
            if not Commerce.Weapons.client.openShop(Commerce.Weapons.client.shops[venue.shopId],result.commerce) then TriggerServerEvent('rp_commerce:close',result.commerce.session) end
        else show(result.commerce) end
    else lib.notify({ title = 'Laden & Werkbank', description = 'Hier ist gerade kein Zugriff möglich.', type = 'error' }) end
end
local function registerUi()
    exports.rp_ui:rpRegisterAction('rp_commerce:action', function(data)
        if exports.rp_ui:rpGetView() ~= 'commerce' or type(data) ~= 'table' or data.session ~= active then return { ok = false, error = 'invalid_state' } end
        local ok, result = pcall(lib.callback.await, 'rp_commerce:action', false, data)
        if ok and result and result.ok then
            if data.action == 'craft' then
                local session = active
                RequestAnimDict(animation)
                local deadline = GetGameTimer() + 1000
                while not HasAnimDictLoaded(animation) and GetGameTimer() < deadline do Wait(25) end
                if session == active and exports.rp_ui:rpGetView() == 'commerce' and HasAnimDictLoaded(animation) then
                    TaskPlayAnim(PlayerPedId(), animation, 'base', 2.0, -2.0, -1, 1, 0.0, false, false, false)
                end
            elseif data.action == 'finish' or data.action == 'cancel' then stopAnimation() end
        end
        return ok and exports.rp_inventory:rpLocalizeCatalog(result) or { ok = false, error = 'unavailable' }
    end)
end
CreateThread(function()
    registerInput() registerUi()
    for _, venue in pairs(C.venues) do
        local b, c = venue.blip, venue.coords
        if b and venue.kind~='shop' then
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, b.sprite) SetBlipColour(blip, b.color) SetBlipScale(blip, 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentString(b.label) EndTextCommandSetBlipName(blip)
            blips[#blips+1] = blip
        end
    end
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'rp_ui' then registerUi() elseif resource == 'rp_core' then registerInput() end
end)
AddEventHandler('rp_core:inputPressed', function(action)
    if action == 'rp_commerce:interact' and exports.rp_ui:rpIsInteractionActive(action) then CreateThread(function() open() end) end
end)
RegisterCommand('rp_shop', function() CreateThread(function() open('shop') end) end, false)
RegisterCommand('rp_crafting', function() CreateThread(function() open('crafting') end) end, false)
local function close()
    Commerce.Clothing.close()
    Commerce.Weapons.client.closeShop(true)
    if active then TriggerServerEvent('rp_commerce:close', active) active = nil end
    stopAnimation()
    if exports.rp_ui:rpGetView() == 'commerce' then exports.rp_ui:rpClose() end
end
RegisterNetEvent('rp_commerce:hide', function() if source == 65535 then close() end end)
AddEventHandler('esx:onPlayerLogout', close)
CreateThread(function()
    while true do
        if active and (exports.rp_ui:rpGetView() ~= 'commerce' or not nearest() or IsEntityDead(PlayerPedId())) then close() end
        Wait(250)
    end
end)
CreateThread(function()
    while true do
        local id, distance
        if ESX.IsPlayerLoaded() and not pending and not Commerce.Weapons.client.dev and not IsEntityDead(PlayerPedId()) then id, distance = nearest() end
        if id then
            local venue = C.venues[id]
            exports.rp_ui:rpShowInteraction({ action = 'rp_commerce:interact', label = venue.label,
                verb = venue.kind == 'shop' and 'Einkaufen' or 'Herstellen',
                icon = venue.kind == 'shop' and 'shop' or 'craft', distance = distance })
        elseif not Commerce.Weapons.client.dev then
            exports.rp_ui:rpHideInteraction()
        end
        Wait(200)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        close()
        for _, blip in ipairs(blips) do RemoveBlip(blip) end
        RemoveAnimDict(animation)
    end
end)
