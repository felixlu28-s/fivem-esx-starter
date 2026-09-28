local function ambient(entity)
    local population = GetEntityPopulationType(entity)
    return population >= 1 and population <= 5
end

-- Local scripted peds stay owned by their creating resource, never by a net event.
local protectedPeds = {}
local function protectedNetworkPed(ped)
    if not NetworkGetEntityIsNetworked(ped) then return false end
    local registry = GlobalState['rp_core:networkPeds'] or {}
    return registry[tostring(NetworkGetNetworkIdFromEntity(ped))] == GetEntityModel(ped)
end
exports('rpProtectPed', function(ped)
    local owner = GetInvokingResource()
    if not owner or not DoesEntityExist(ped) or not IsEntityAPed(ped) or IsPedAPlayer(ped)
        or NetworkGetEntityIsNetworked(ped) then return false end
    if protectedPeds[ped] and protectedPeds[ped] ~= owner then return false end
    if not RP.NpcPresentation.register(ped, owner) then return false end
    protectedPeds[ped] = owner
    return true
end)
exports('rpReleasePed', function(ped)
    if protectedPeds[ped] ~= GetInvokingResource() then return false end
    RP.NpcPresentation.release(ped, GetInvokingResource())
    protectedPeds[ped] = nil
    return true
end)
AddEventHandler('onResourceStop', function(resource)
    for ped, owner in pairs(protectedPeds) do
        if owner == resource then
            protectedPeds[ped] = nil
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end
    end
end)

AddEventHandler('populationPedCreating', function() CancelEvent() end)

CreateThread(function()
    for dispatch = 1, 15 do EnableDispatchService(dispatch, false) end
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetRandomBoats(false)
    SetRandomTrains(false)
    SetGarbageTrucks(false)
    SetMaxWantedLevel(0)
    while true do
        -- Suppress GTA cash/bank flashes from the first resource frame, including login.
        DisplayCash(false)
        RemoveMultiplayerHudCash()
        HideHudComponentThisFrame(3)
        HideHudComponentThisFrame(4)
        HideHudComponentThisFrame(13)
        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        Wait(0)
    end
end)

-- Clean up existing population without deleting players or project-owned vehicles.
CreateThread(function()
    while true do
        Wait(5000)
        for _, ped in ipairs(GetGamePool('CPed')) do
            if not protectedPeds[ped] and not protectedNetworkPed(ped) and not IsPedAPlayer(ped) and (not NetworkGetEntityIsNetworked(ped) or NetworkHasControlOfEntity(ped)) then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
        for ped in pairs(protectedPeds) do if not DoesEntityExist(ped) then protectedPeds[ped] = nil end end
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if ambient(vehicle) and (not NetworkGetEntityIsNetworked(vehicle) or NetworkHasControlOfEntity(vehicle)) then
                local occupied = false
                for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
                    if IsPedAPlayer(GetPedInVehicleSeat(vehicle, seat)) then occupied = true break end
                end
                if not occupied then SetEntityAsMissionEntity(vehicle, true, true) DeleteEntity(vehicle) end
            end
        end
    end
end)
