local isOpen = false

local function setOpen(nextOpen, view, payload)
    isOpen = nextOpen
    SetNuiFocus(nextOpen, nextOpen)

    SendNUIMessage({
        action = nextOpen and 'ui:open' or 'ui:close',
        data = {
            view = view,
            payload = payload or {},
        },
    })
end

RegisterNetEvent('rp_ui:open', function(view, payload)
    if type(view) ~= 'string' or #view == 0 or #view > 64 then
        return
    end

    if payload ~= nil and type(payload) ~= 'table' then
        return
    end

    setOpen(true, view, payload)
end)

RegisterNetEvent('rp_ui:close', function()
    setOpen(false)
end)

RegisterNUICallback('ui:close', function(_, callback)
    setOpen(false)
    callback({ ok = true })
end)

RegisterNUICallback('rp_characters:list', function(_, callback)
    local result = exports.rp_characters:List()
    callback(result or { ok = false, error = 'unavailable' })
end)

RegisterNUICallback('rp_characters:create', function(data, callback)
    local result = exports.rp_characters:Create(data)
    callback(result or { ok = false, error = 'unavailable' })
end)

RegisterNUICallback('rp_characters:select', function(data, callback)
    local result = exports.rp_characters:Select(data and data.id)
    callback(result or { ok = false, error = 'unavailable' })
end)

exports('Open', function(view, payload)
    TriggerEvent('rp_ui:open', view, payload)
end)

exports('Close', function()
    TriggerEvent('rp_ui:close')
end)

RegisterCommand('rp_ui_demo', function()
    setOpen(true, 'welcome', {
        title = 'FiveM ESX Starter',
        message = 'Die zentrale React-NUI funktioniert.',
    })
end, false)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= GetCurrentResourceName() or not isOpen then
        return
    end

    SetNuiFocus(false, false)
end)
