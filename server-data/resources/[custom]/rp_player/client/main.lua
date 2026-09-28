local ESX = exports.es_extended:getSharedObject()
local pending = false
local stamina = 1
local function profile()
    if not ESX.IsPlayerLoaded() then return { ok = false, error = 'player_unavailable' } end
    local ok, result = pcall(lib.callback.await, 'rp_player:profile', false)
    if not ok or type(result) ~= 'table' then return { ok = false, error = 'unavailable' } end
    if result.ok then result.profile.stamina = math.floor(GetPlayerSprintStaminaRemaining(PlayerId())) end
    return result
end
local function open()
    if pending or IsNuiFocused() then return end
    pending = true
    local result = profile()
    if result.ok and not IsNuiFocused() and ESX.IsPlayerLoaded() then
        exports.rp_ui:rpOpen('me', result.profile, false, { toggleAction = 'rp_player:me' })
    elseif not result.ok then
        lib.notify({ title = 'Mein Charakter', description = 'Deine Daten sind gerade nicht verfügbar. Versuche es gleich erneut.', type = 'error' })
    end
    pending = false
end
local function register()
    exports.rp_ui:rpRegisterAction('rp_player:refresh', function()
        if exports.rp_ui:rpGetView() ~= 'me' then return { ok = false, error = 'invalid_state' } end
        return profile()
    end)
end
AddEventHandler('rp_core:inputPressed', function(action)
    if action == 'rp_player:me' then CreateThread(open) end
end)
RegisterCommand('rp_me', function() CreateThread(open) end, false)
RegisterNetEvent('rp_player:fitnessChanged', function(value)
    if source ~= 65535 or type(value) ~= 'number' or value % 1 ~= 0 or value < 1 or value > PlayerConfig.maxLevel then return end
    stamina = value
    -- GTA's stamina stat affects endurance; server-observed distance owns progression.
    StatSetInt(joaat('MP0_STAMINA'), math.min(100, 20 + math.floor(value * 0.8)), false)
end)
CreateThread(register)
AddEventHandler('onClientResourceStart', function(resource) if resource == 'rp_ui' then register() end end)
AddEventHandler('esx:onPlayerSpawn', function()
    StatSetInt(joaat('MP0_STAMINA'), math.min(100, 20 + math.floor(stamina * 0.8)), false)
end)
