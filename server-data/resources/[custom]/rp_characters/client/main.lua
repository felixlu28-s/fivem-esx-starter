local ESX = exports.es_extended:getSharedObject()
local A, C = Characters.Appearance, Characters.Config
local phase, roster = 'waiting', { characters = {}, slots = 1 }
local pendingSlot
local spawning, sceneReady = false, false
local function request(name, data)
    for attempt = 1, 3 do
        local ok, result = pcall(lib.callback.await, 'rp_characters:' .. name, false, data)
        if not ok or type(result) ~= 'table' then return { ok = false, error = 'unavailable' } end
        if result.error ~= 'rate_limited' or attempt == 3 then return result end
        local delay = tonumber(result.retryAfterMs)
        if not delay or delay ~= delay then delay = 1500 end
        Wait(math.min(2000, math.max(100, math.ceil(delay))) + 50)
    end
end
local function display(mode, extra)
    local payload = { mode = mode, characters = roster.characters, slots = roster.slots,
        skin = A.current(), fields = A.catalog(), minAge = C.minAge, maxAge = C.maxAge }
    for key, value in pairs(extra or {}) do payload[key] = value end
    exports.rp_ui:rpOpen('characters', payload, true)
end
local function appearanceResult()
    return { ok = true, skin = A.current(), fields = A.catalog() }
end
local function cleanup()
    Characters.Scene.clear()
    A.destroyCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(PlayerId(), true, 0)
    DisplayRadar(true)
    exports.rp_core:rpSetClockPreview(nil)
    ClearOverrideWeather()
end
local function select(slot)
    phase = 'loading'
    for _, character in ipairs(roster.characters) do
        if character.slot == slot and not A.apply(character.skin) then
            phase = 'selection'
            return { ok = false, error = 'appearance_failed' }
        end
    end
    local result = request('select', { slot = slot })
    if not result.ok then phase = 'selection' elseif phase ~= 'active' then display('loading') end
    return result
end
local function resumeCreated()
    local result = select(pendingSlot)
    if not result.ok then display('error', { error = result.error }) end
    return result
end
local function refresh(initial)
    local result = initial or request('bootstrap')
    if not result.ok then display('error', { error = result.error }) return result end
    roster = result
    if not sceneReady then
        sceneReady = Characters.Scene.prepare()
        if not sceneReady then
            display('error', { error = 'preview_unavailable' })
            return { ok = false, error = 'preview_unavailable' }
        end
    end
    if #roster.characters == 1 and roster.slots == 1 then
        local selected = select(roster.characters[1].slot)
        if not selected.ok then display('error', { error = selected.error }) end
        return selected
    end
    if #roster.characters == 0 then
        phase = 'creator'
        if not A.apply(A.defaults(0)) then display('error', { error = 'appearance_failed' }) return { ok = false } end
        display('creator')
    else
        phase = 'selection'
        if not A.apply(roster.characters[1].skin) then display('error', { error = 'appearance_failed' }) return { ok = false } end
        display('selection')
    end
    return { ok = true }
end

local function registerActions()
    exports.rp_ui:rpRegisterAction('rp_characters:refresh', function()
        if phase == 'active' or phase == 'loading' then return { ok = false, error = 'invalid_state' } end
        if pendingSlot then return resumeCreated() end
        return refresh()
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:preview', function(data)
        if phase ~= 'selection' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        for _, character in ipairs(roster.characters) do
            if character.slot == data.slot then return { ok = A.apply(character.skin) } end
        end
        return { ok = false, error = 'not_found' }
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:new', function()
        if phase ~= 'selection' or #roster.characters >= roster.slots then return { ok = false, error = 'character_limit' } end
        phase = 'creator'
        A.apply(A.defaults(0))
        display('creator')
        return { ok = true }
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:back', function()
        if phase ~= 'creator' or #roster.characters == 0 then return { ok = false, error = 'invalid_state' } end
        phase = 'selection'
        A.apply(roster.characters[1].skin)
        display('selection')
        return { ok = true }
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:appearance', function(data)
        if phase ~= 'creator' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        if not A.change(data.key, data.value) then return { ok = false, error = 'appearance_failed' } end
        return appearanceResult()
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:camera', function(data)
        if (phase ~= 'creator' and phase ~= 'selection') or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        if not A.camera(data) then return { ok = false, error = 'invalid_fields' } end
        return { ok = true }
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:select', function(data)
        if phase ~= 'selection' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        return select(data.slot)
    end)
    exports.rp_ui:rpRegisterAction('rp_characters:create', function(data)
        if phase ~= 'creator' or type(data) ~= 'table' then return { ok = false, error = 'invalid_state' } end
        phase = 'loading'
        local result = request('create', { identity = data, skin = A.current() })
        if result.ok and Characters.Validation.integer(result.slot, 1, C.maxSlots) then
            pendingSlot = result.slot
            return resumeCreated()
        end
        phase = 'creator'
        -- The reply can be lost after the DB commit, or the UI can still show
        -- an old empty roster. Reconcile saved slots instead of offering create.
        if result.error == 'character_limit' or result.error == 'unavailable' then
            return refresh()
        end
        return result.ok and { ok = false, error = 'invalid_state' } or result
    end)
end

-- Network safety is resource-local: ESX's registration does not register ours.
RegisterNetEvent('esx:playerLoaded', function()
    if source ~= 65535 or phase == 'active' or spawning then return end
    spawning = true
    CreateThread(function()
        phase = 'loading'
        DoScreenFadeOut(300)
        local result
        for _ = 1, 10 do
            result = request('spawnData')
            if result.ok then break end
            Wait(900)
        end
        if not result or not result.ok then
            spawning = false
            print('[rp_characters] Login failed while requesting authoritative spawn data.')
            display('error', { error = 'login_failed' })
            DoScreenFadeIn(300)
            return
        end
        local ok, err = pcall(function()
            if not A.apply(result.skin) then error('appearance_failed') end
            ESX.SpawnPlayer(A.current(), result.position, function()
                -- Same handshake as official esx_multicharacter: ESX owns spawned.
                TriggerServerEvent('esx:onPlayerSpawn')
                TriggerEvent('esx:onPlayerSpawn')
                TriggerEvent('esx:restoreLoadout')
                TriggerEvent('esx:loadingScreenOff')
                exports.rp_ui:rpFinishLoading()
            end)
            local accepted = false
            for _ = 1, 15 do
                local response = request('spawned')
                if response.ok then accepted = true break end
                Wait(900)
            end
            if not accepted then error('spawn_timeout') end
        end)
        if not ok then
            spawning = false
            print('[rp_characters] Spawn failed: ' .. tostring(err))
            display('error', { error = 'login_failed' })
            DoScreenFadeIn(300)
            return
        end
        phase = 'active'
        spawning = false
        pendingSlot = nil
        exports.rp_ui:rpClose()
        cleanup()
        DoScreenFadeIn(800)
    end)
end)

CreateThread(function()
    registerActions()
    local deadline = GetGameTimer() + 60000
    while not NetworkIsPlayerActive(PlayerId()) and GetGameTimer() < deadline do Wait(100) end
    if ESX.IsPlayerLoaded() then phase = 'active' exports.rp_ui:rpFinishLoading() return end
    exports.rp_ui:rpLoadingPhase('session')
    if not ESX.GetConfig('Multichar') then
        exports.rp_ui:rpFinishLoading()
        display('error', { error = 'configuration_error' })
        return
    end
    ESX.DisableSpawnManager()
    DoScreenFadeOut(0)
    -- Reserve the private routing bucket before making a preview ped visible.
    local initial = request('bootstrap')
    local first = initial.ok and initial.characters and initial.characters[1]
    if not A.apply(first and first.skin or A.defaults(0)) then
        exports.rp_ui:rpFinishLoading()
        display('error', { error = 'appearance_failed' })
        return
    end
    SetOverrideWeather('EXTRASUNNY')
    exports.rp_core:rpSetClockPreview(C.studioHour)
    exports.rp_ui:rpLoadingPhase('scene')
    sceneReady = Characters.Scene.prepare()
    A.camera({ view = 'body', rotation = 0 })
    phase = 'selection'
    exports.rp_ui:rpFinishLoading()
    DoScreenFadeIn(600)
    display('loading')
    if not sceneReady then display('error', { error = 'preview_unavailable' }) return end
    refresh(initial)
end)

CreateThread(function()
    while true do
        if phase ~= 'waiting' and phase ~= 'active' then
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        else Wait(500) end
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'rp_ui' then
        registerActions()
        if phase ~= 'active' and phase ~= 'waiting' then display(phase == 'creator' and 'creator' or 'selection') end
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if phase ~= 'active' then cleanup() exports.rp_ui:rpClose() end
end)
