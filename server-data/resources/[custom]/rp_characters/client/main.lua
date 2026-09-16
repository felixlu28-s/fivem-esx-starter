local function request(callbackName, payload)
    return lib.callback.await(callbackName, false, payload)
end

exports('List', function()
    return request('rp_characters:list')
end)

exports('Create', function(payload)
    return request('rp_characters:create', payload)
end)

exports('Select', function(characterId)
    return request('rp_characters:select', characterId)
end)

RegisterCommand('characters', function()
    TriggerEvent('rp_characters:open')
end, false)

RegisterNetEvent('rp_characters:open', function()
    local result = request('rp_characters:list')
    if not result or not result.ok then return end

    TriggerEvent('rp_ui:open', 'characters', { characters = result.characters })
end)