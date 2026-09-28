local current, owner, locked = nil, nil, false
local toggleAction
local routes = {}
local keepGameInput, guardingInput = false, false
local menuControls = { 27, 172, 173, 174, 175, 176, 177, 187, 188, 189, 190, 191, 194, 199, 200, 201, 202 }
local function focus(keyboardOnly)
    keepGameInput = keyboardOnly
    SetNuiFocusKeepInput(keyboardOnly)
    SetNuiFocus(true, not keyboardOnly)
    if not keyboardOnly or guardingInput then return end
    guardingInput = true
    CreateThread(function()
        while keepGameInput do
            -- Consume menu/phone/pause controls, retaining walking, driving and camera input.
            for _, control in ipairs(menuControls) do DisableControlAction(0, control, true) end
            if IsDisabledRawKeyDown(13) then
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 75, true)
            end
            Wait(0)
        end
        guardingInput = false
    end)
end
local function releaseFocus()
    keepGameInput = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end
local function send()
    if current and toggleAction then
        current.toggleKey = nil
        for _, action in ipairs(exports.rp_core:rpGetBindings().actions) do
            if action.id == toggleAction then current.toggleKey = action.key break end
        end
    end
    SendNUIMessage(current and { action = 'ui:open', data = current } or { action = 'ui:close' })
end
local function open(view, payload, lock, invoker, options)
    if locked and invoker ~= owner then return false end
    if type(view) ~= 'string' or type(payload) ~= 'table' then return false end
    owner, locked = invoker, lock == true
    current = { view = view, payload = payload, locked = locked }
    toggleAction = type(options) == 'table' and type(options.toggleAction) == 'string' and options.toggleAction or nil
    focus(type(options) == 'table' and options.keyboardOnly == true)
    send()
    return true
end
local function close(invoker)
    if locked and invoker ~= owner then return false end
    current, owner, locked = nil, nil, false
    toggleAction = nil
    releaseFocus()
    send()
    return true
end

exports('rpOpen', function(view, payload, lock, options) return open(view, payload, lock, GetInvokingResource(), options) end)
exports('rpClose', function() return close(GetInvokingResource()) end)
exports('rpGetView', function() return current and current.view or nil end)
exports('rpSetTextInput',function(active)
    if GetInvokingResource()~=owner or not current or type(active)~='boolean' then return false end
    if active then
        keepGameInput=false SetNuiFocusKeepInput(false) SetNuiFocus(true,false)
    else focus(true) end
    return true
end)
exports('rpRegisterAction', function(name, handler)
    local invoker = GetInvokingResource()
    local callable = type(handler) == 'function' or (type(handler) == 'table' and handler.__cfx_functionReference)
    if not invoker or type(name) ~= 'string' or not name:match('^rp_[%w_:]+$') or not callable then return false end
    if routes[name] and routes[name].owner ~= invoker then return false end
    local firstRegistration = routes[name] == nil
    routes[name] = { owner = invoker, handler = handler }
    if firstRegistration then
        RegisterNUICallback(name, function(data, callback)
            local responded = false
            local function respond(result)
                if responded then return end
                responded = true
                callback(result or { ok = false, error = 'unavailable' })
            end
            SetTimeout(20000, function() respond({ ok = false, error = 'timeout' }) end)
            local route = routes[name]
            if not route or not route.handler then return respond({ ok = false, error = 'unavailable' }) end
            local ok, result = pcall(route.handler, data)
            respond(ok and result or { ok = false, error = 'unavailable' })
        end)
    end
    return true
end)

RegisterNUICallback('ui:ready', function(_, callback) send() TriggerEvent('rp_ui:ready') callback({ ok = true }) end)
AddEventHandler('rp_core:bindingsChanged', function() if current and toggleAction then send() end end)
RegisterNUICallback('ui:close', function(_, callback)
    if locked then callback({ ok = false, error = 'locked' }) return end
    close(nil)
    callback({ ok = true })
end)

-- Compatibility for simple existing project views; locked login cannot be overridden.
AddEventHandler('rp_ui:open', function(view, payload) open(view, payload or {}, false, GetInvokingResource()) end)
AddEventHandler('rp_ui:close', function() close(GetInvokingResource()) end)
exports('Open', function(view, payload) return open(view, payload or {}, false, GetInvokingResource()) end)
exports('Close', function() return close(GetInvokingResource()) end)
RegisterCommand('rp_ui_demo', function()
    open('welcome', { title = 'FiveM ESX Starter', message = 'Die zentrale React-NUI funktioniert.' }, false, nil)
end, false)

AddEventHandler('onResourceStop', function(resource)
    for _, route in pairs(routes) do if route.owner == resource then route.handler = nil end end
    if resource == owner or resource == GetCurrentResourceName() then
        current, owner, locked = nil, nil, false
        releaseFocus()
        send()
    end
end)
