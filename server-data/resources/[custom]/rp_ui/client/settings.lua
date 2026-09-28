local ESX = exports.es_extended:getSharedObject()
local function snapshot() return exports.rp_core:rpGetBindings() end
local function open()
    if not ESX.IsPlayerLoaded() or IsNuiFocused() then return end
    exports.rp_ui:rpOpen('settings', snapshot(), true, { toggleAction = 'rp_ui:settings' })
end
RegisterCommand('rp_settings', open, false)
AddEventHandler('rp_core:inputPressed', function(action) if action == 'rp_ui:settings' then open() end end)
CreateThread(function()
    exports.rp_ui:rpRegisterAction('rp_ui:bind', function(data)
        if exports.rp_ui:rpGetView() ~= 'settings' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        return exports.rp_core:rpSetBinding(data.action, data.key, data.confirmed, data.revision)
    end)
    exports.rp_ui:rpRegisterAction('rp_ui:resetBindings', function(data)
        if exports.rp_ui:rpGetView() ~= 'settings' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        return exports.rp_core:rpResetBindings(data.revision)
    end)
    exports.rp_ui:rpRegisterAction('rp_ui:closeSettings', function(data)
        if exports.rp_ui:rpGetView() ~= 'settings' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        local current = snapshot()
        if data.revision ~= current.revision then return { ok = false, error = 'stale_bindings', bindings = current } end
        local missing = false
        for _, action in ipairs(current.actions) do if action.key == '' then missing = true break end end
        if missing and data.confirmed ~= true then return { ok = false, error = 'unbound_actions', bindings = current } end
        exports.rp_ui:rpClose()
        return { ok = true }
    end)
end)
