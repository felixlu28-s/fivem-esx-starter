-- Server-only protection for networked mission actors. No client event can register one.
local actors = {}
local function publish()
    local public = {}
    for entity, record in pairs(actors) do
        if DoesEntityExist(entity) and GetEntityModel(entity) == record.model then
            public[tostring(NetworkGetNetworkIdFromEntity(entity))] = record.model
        else actors[entity] = nil end
    end
    GlobalState['rp_core:networkPeds'] = public
end
exports('rpProtectNetworkPed', function(entity)
    local owner = GetInvokingResource()
    if not owner or type(entity) ~= 'number' or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return false end
    for _, id in ipairs(GetPlayers()) do if GetPlayerPed(id) == entity then return false end end
    if actors[entity] and actors[entity].owner ~= owner then return false end
    actors[entity] = { owner = owner, model = GetEntityModel(entity) }
    publish()
    return true
end)
exports('rpReleaseNetworkPed', function(entity)
    if not actors[entity] or actors[entity].owner ~= GetInvokingResource() then return false end
    actors[entity] = nil
    publish()
    return true
end)
AddEventHandler('onResourceStop', function(name)
    for entity, record in pairs(actors) do
        if name == record.owner or name == GetCurrentResourceName() then
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            actors[entity] = nil
        end
    end
    publish()
end)
GlobalState['rp_core:networkPeds'] = {}
