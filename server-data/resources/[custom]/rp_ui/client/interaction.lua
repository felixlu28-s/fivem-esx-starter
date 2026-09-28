local ESX = exports.es_extended:getSharedObject()
local hints, last = {}, nil
local icons = { shop = true, craft = true, bag = true, bank = true }

-- Presentation only: consumers renew their nearby point; no NUI focus or gameplay event.
exports('rpShowInteraction', function(data)
    local owner = GetInvokingResource()
    if not owner or type(data) ~= 'table' or type(data.action) ~= 'string'
        or data.action:sub(1, #owner + 1) ~= owner .. ':'
        or type(data.label) ~= 'string' or #data.label < 1 or #data.label > 160
        or type(data.verb) ~= 'string' or #data.verb < 1 or #data.verb > 80
        or not icons[data.icon] or type(data.distance) ~= 'number'
        or data.distance ~= data.distance or data.distance < 0 or data.distance > 100 then return false end
    hints[owner] = { action = data.action, label = data.label, verb = data.verb,
        icon = data.icon, distance = data.distance, expires = GetGameTimer() + 700 }
    return true
end)
exports('rpHideInteraction', function()
    local owner = GetInvokingResource()
    if owner then hints[owner] = nil end
end)

local function active()
    local nearest, nearestOwner
    local now = GetGameTimer()
    for owner, hint in pairs(hints) do
        if hint.expires < now then hints[owner] = nil
        elseif not nearest or hint.distance < nearest.distance
            or (hint.distance == nearest.distance and owner < nearestOwner) then nearest, nearestOwner = hint, owner end
    end
    if nearest and ESX.IsPlayerLoaded() and not IsNuiFocused() and not IsPauseMenuActive()
        and not IsScreenFadedOut() and not IsEntityDead(PlayerPedId()) and not exports.rp_ui:rpGetView() then
        return nearest, nearestOwner
    end
end
-- Only the visible contextual action may consume a shared default key (e.g. E).
exports('rpIsInteractionActive', function(action)
    local hint,owner=active()
    return hint ~= nil and owner == GetInvokingResource() and hint.action == action
end)
local function render()
    local nearest = active()
    local payload = false
    if nearest then
        local bindings = exports.rp_core:rpGetBindings()
        for _, action in ipairs(bindings.actions) do
            if action.id == nearest.action then
                local key = action.key
                for _, entry in ipairs(bindings.keys) do if entry.id == key then key = entry.label break end end
                payload = { label = nearest.label, verb = nearest.verb, icon = nearest.icon, key = key }
                break
            end
        end
    end
    local signature = json.encode(payload)
    if signature ~= last then
        last = signature
        SendNUIMessage({ action = 'ui:interaction', data = payload })
    end
end
CreateThread(function() while true do render() Wait(100) end end)
AddEventHandler('rp_ui:ready', function() last = nil end)
AddEventHandler('onResourceStop', function(resource)
    hints[resource] = nil
    if resource == GetCurrentResourceName() then SendNUIMessage({ action = 'ui:interaction', data = false })
    else render() end
end)
