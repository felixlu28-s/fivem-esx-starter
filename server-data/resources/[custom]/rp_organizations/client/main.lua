local ESX = exports.es_extended:getSharedObject()
local pending = false
local function request(input)
    if not ESX.IsPlayerLoaded() then return { ok = false, error = 'player_unavailable' } end
    local ok, result = pcall(lib.callback.await, 'rp_organizations:request', false, input)
    return ok and type(result) == 'table' and result or { ok = false, error = 'unavailable' }
end
local function open(fromMe)
    if pending or (IsNuiFocused() and not (fromMe and exports.rp_ui:rpGetView() == 'me')) then return { ok = false, error = 'busy' } end
    pending = true
    local result = request({ action = 'view' })
    if result.ok and result.organizations and ESX.IsPlayerLoaded() then
        local view = exports.rp_ui:rpGetView()
        if (not IsNuiFocused() or (fromMe and view == 'me')) then
            exports.rp_ui:rpOpen('organizations', result.organizations, false)
        end
    end
    pending = false
    return result
end
local function register()
    exports.rp_ui:rpRegisterAction('rp_organizations:open', function()
        if exports.rp_ui:rpGetView() ~= 'me' then return { ok = false, error = 'invalid_state' } end
        return open(true)
    end)
    exports.rp_ui:rpRegisterAction('rp_organizations:request', function(input)
        if exports.rp_ui:rpGetView() ~= 'organizations' then return { ok = false, error = 'invalid_state' } end
        return request(input)
    end)
end
RegisterCommand('rp_organizations', function()
    local result = open(false)
    if not result.ok then lib.notify({ title = 'Organisationen', description = 'Die Verwaltung ist gerade nicht verfügbar.', type = 'error' }) end
end, false)
CreateThread(register)
AddEventHandler('onClientResourceStart', function(resource) if resource == 'rp_ui' then register() end end)
AddEventHandler('esx:onPlayerLogout', function()
    if exports.rp_ui:rpGetView() == 'organizations' then exports.rp_ui:rpClose() end
end)
