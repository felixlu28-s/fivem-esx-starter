local state, active, preview = nil, nil, false
local function correctModel()
    return state and GetEntityModel(PlayerPedId()) == (state.sex == 1 and joaat('mp_f_freemode_01') or joaat('mp_m_freemode_01'))
end
local function apply()
    if not state or preview or not correctModel() then return end
    TriggerEvent('skinchanger:getSkin', function(skin)
        if state and not preview and correctModel() then TriggerEvent('skinchanger:loadClothes', skin, state.skin) end
    end)
end
RegisterNetEvent('rp_inventory:clothingState', function(value)
    if type(value) ~= 'table' or type(value.skin) ~= 'table' or (value.sex ~= 0 and value.sex ~= 1) then return end
    state = value
    apply()
end)
exports('rpClothingPreview', function(enabled)
    preview = enabled == true
    if not preview then apply() end
end)
exports('rpClothingBusy', function() return active ~= nil end)
RegisterNetEvent('rp_inventory:clothingAnimate', function(token, category, generation)
    if active or not state or state.generation ~= generation or preview then
        TriggerServerEvent('rp_inventory:clothingAck', token, false) return
    end
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, false) then TriggerServerEvent('rp_inventory:clothingAck', token, false) return end
    local current = { token = token, ped = ped }
    active = current
    CreateThread(function()
        local animation = Clothing.animations[category] or Clothing.animations.default
        local dict, clip = animation.dict, animation.clip
        RequestAnimDict(dict)
        local timeout = GetGameTimer() + 1800
        while active == current and not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(20) end
        if active ~= current then return end
        if not HasAnimDictLoaded(dict) then TriggerServerEvent('rp_inventory:clothingAck', token, false) active = nil return end
        current.dict, current.clip = dict, clip
        TaskPlayAnim(ped, dict, clip, 4.0, -4.0, animation.duration, 48, 0.0, false, false, false)
        local deadline, healthy = GetGameTimer() + animation.duration, true
        while active == current and GetGameTimer() < deadline do
            if PlayerPedId() ~= ped or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) then healthy = false break end
            Wait(50)
        end
        if active == current then TriggerServerEvent('rp_inventory:clothingAck', token, healthy) end
        -- Failure/resource loss watchdog. Only stop our own animation.
        SetTimeout(8000, function()
            if active == current then StopAnimTask(ped, dict, clip, 2.0) active = nil apply() end
        end)
    end)
end)
RegisterNetEvent('rp_inventory:clothingFinish', function(token)
    if not active or token ~= active.token then return end
    if active.dict then StopAnimTask(active.ped, active.dict, active.clip, 2.0) RemoveAnimDict(active.dict) end
    active = nil
    apply()
end)
AddEventHandler('esx:onPlayerSpawn', function()
    CreateThread(function() Wait(500) TriggerServerEvent('rp_inventory:clothingRequest') end)
end)
AddEventHandler('esx:onPlayerLogout', function() state, preview, active = nil, false, nil end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if active and active.dict then StopAnimTask(active.ped, active.dict, active.clip, 2.0) end
end)
