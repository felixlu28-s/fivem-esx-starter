local ESX = exports.es_extended:getSharedObject()
local last
local function number(value, maximum)
    return type(value) == 'number' and value == value and value >= 0 and value <= maximum
end
local function snapshot()
    local view = exports.rp_ui:rpGetView()
    if not ESX.IsPlayerLoaded() or IsPauseMenuActive() or IsScreenFadedOut()
        or (view and view ~= 'nativeui' and view ~= 'phone') or (not view and IsNuiFocused()) then return false end

    -- Read current ESX data, not a startup snapshot or a competing money balance.
    local data, cash = ESX.GetPlayerData(), false
    for _, account in pairs(data.accounts or {}) do
        if account.name == 'money' and number(account.money, 9007199254740991) then
            cash = math.floor(account.money)
            break
        end
    end
    local connected = MumbleIsConnected()
    local range = connected and MumbleGetTalkerProximity() or false
    if connected and GetResourceState('pma-voice') == 'started' then
        local proximity = LocalPlayer.state.proximity
        if type(proximity) == 'table' and number(proximity.distance, 10000) then range = proximity.distance end
    end
    range = number(range, 10000) and range > 0 and math.floor(range * 10 + 0.5) / 10 or false
    local players = GlobalState['rp_core:playerCount']
    local safe = GetSafeZoneSize()
    return {
        cash = cash, id = GetPlayerServerId(PlayerId()),
        players = number(players, 100000) and math.floor(players) or false,
        connected = connected, talking = connected and NetworkIsPlayerTalking(PlayerId()) or false,
        range = range, inset = number(safe, 1) and math.min(0.1, (1 - safe) / 2) or 0,
    }
end
CreateThread(function()
    while true do
        local payload = snapshot()
        local signature = json.encode(payload)
        if signature ~= last then
            last = signature
            SendNUIMessage({ action = 'ui:hud', data = payload })
        end
        Wait(150)
    end
end)
AddEventHandler('rp_ui:ready', function() last = nil end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SendNUIMessage({ action = 'ui:hud', data = false }) end
end)
