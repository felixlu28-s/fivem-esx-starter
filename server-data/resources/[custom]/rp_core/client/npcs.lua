local C, ESX = RP.NpcConfig, exports.es_extended:getSharedObject()
local entries, greetings = {}, {}
local speechAt, gestureAt = 0, 0
local N = {} -- Internal to rp_core; world.lua owns registration/release.
RP.NpcPresentation = N

local function exists(e)
    return DoesEntityExist(e.ped) and GetEntityModel(e.ped) == e.model
end
local function stop(e)
    local motion = e.motion
    e.motion = nil -- Invalidates pending dictionary loads before any cleanup.
    if motion then
        if exists(e) then StopAnimTask(e.ped, motion.dict, motion.clip, 2.0) end
        RemoveAnimDict(motion.dict)
    end
end
function N.release(ped, owner)
    local e = entries[ped]
    if not e or e.owner ~= owner then return false end
    stop(e)
    if exists(e) then TaskClearLookAt(ped) end
    entries[ped] = nil
    return true
end
function N.register(ped, owner)
    local old = entries[ped]
    if old and old.owner ~= owner then return false end
    if old and exists(old) then return true end
    if old then N.release(ped, owner) end
    entries[ped] = { ped = ped, owner = owner, model = GetEntityModel(ped), profile = 'generic',
        key = owner .. ':' .. ped, greetAt = 0, chatAt = GetGameTimer() + math.random(C.chatterMin, C.chatterMax) }
    return true
end
exports('rpConfigureNpc', function(ped, options)
    local e = entries[ped]
    if not e or e.owner ~= GetInvokingResource() or not exists(e) or type(options) ~= 'table' then return false end
    if options.profile ~= nil and not C.profiles[options.profile] then return false end
    if options.paused ~= nil and type(options.paused) ~= 'boolean' then return false end
    if options.key ~= nil and (type(options.key) ~= 'string' or #options.key < 1 or #options.key > 100) then return false end
    if options.profile and options.profile ~= e.profile then stop(e) e.profile = options.profile end
    if options.key then e.key = e.owner .. ':' .. options.key e.greetAt = greetings[e.key] or 0 end
    if options.paused ~= nil then
        e.paused = options.paused
        if e.paused then e.request=nil stop(e) TaskClearLookAt(ped) end
    end
    return true
end)

-- Explicit, owner-only service reactions share the normal NPC cooldown/cleanup.
local reactions={acknowledge={clip='gesture_nod_yes_soft',speech='GENERIC_THANKS'},farewell={clip='gesture_hello',speech='GENERIC_BYE'}}
exports('rpReactNpc',function(ped,kind)
    local e=entries[ped]
    if not e or e.owner~=GetInvokingResource() or not exists(e) or e.paused or not reactions[kind] then return false end
    e.request={kind=kind,expires=GetGameTimer()+12000}
    return true
end)

local function distance2(a, b) return (a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2 end
local function canSee(e, player)
    return GetInteriorFromEntity(player) == GetInteriorFromEntity(e.ped)
        and HasEntityClearLosToEntity(e.ped, player, 17)
end
local function animate(e, clip, duration)
    local profile = C.profiles[e.profile]
    local dict = profile.dict or (IsPedMale(e.ped) and profile.maleDict or profile.femaleDict)
    local motion = { dict = dict, clip = clip, untilAt = GetGameTimer() + duration + C.loadTimeout }
    e.motion = motion
    CreateThread(function()
        RequestAnimDict(dict)
        local deadline = GetGameTimer() + C.loadTimeout
        local function current()
            return entries[e.ped] == e and e.motion == motion and not e.paused and exists(e) and not IsEntityDead(e.ped)
        end
        while current() and not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(50) end
        local player = PlayerPedId()
        if current() and HasAnimDictLoaded(dict) and ESX.IsPlayerLoaded() and not IsEntityDead(player)
            and not IsPauseMenuActive() and distance2(GetEntityCoords(player), GetEntityCoords(e.ped)) <= C.radius^2 and canSee(e, player) then
            -- Secondary upper-body gesture: retain the owner's idle/scenario and feet anchor.
            TaskPlayAnim(e.ped, dict, clip, 2.0, -2.0, duration, 48, 0.0, false, false, false)
            motion.untilAt = GetGameTimer() + duration
        elseif e.motion == motion then e.motion = nil end
        RemoveAnimDict(dict)
    end)
end
local function react(e, player, now)
    local profile = C.profiles[e.profile]
    if e.request and e.request.expires<now then e.request=nil end
    local requested=e.request and reactions[e.request.kind]
    local greeting = not e.greeted and now >= e.greetAt
    if not requested and not greeting and now < e.chatAt then return end
    if e.motion or IsAnySpeechPlaying(e.ped) or now < gestureAt or ((greeting or requested) and now < speechAt) then return end
    gestureAt = now + C.gestureGap
    TaskLookAtEntity(e.ped, player, 2500, 2048, 3)
    e.lookAt = now + math.random(8000, 14000)
    e.chatAt = now + math.random(C.chatterMin, C.chatterMax)
    if requested then
        e.request=nil
        animate(e,profile.dict and profile.greeting or requested.clip,2200)
    elseif greeting then
        e.greeted, e.greetAt = true, now + C.greetingCooldown
        greetings[e.key] = e.greetAt
        animate(e, profile.greeting, 2500)
    else
        local index = math.random(#profile.gestures)
        if index == e.lastGesture then index = index % #profile.gestures + 1 end
        e.lastGesture = index
        animate(e, profile.gestures[index], 3000)
    end
    if now >= speechAt and not IsAnySpeechPlaying(player) and (requested or greeting or math.random(3) == 1) then
        PlayPedAmbientSpeechNative(e.ped, requested and requested.speech or greeting and profile.greetingSpeech or profile.chatterSpeech, 'SPEECH_PARAMS_STANDARD')
        speechAt = now + C.speechGap
    end
end
CreateThread(function()
    while true do
        local now, player = GetGameTimer(), PlayerPedId()
        local active = ESX.IsPlayerLoaded() and DoesEntityExist(player) and not IsEntityDead(player) and not IsPauseMenuActive()
        local pos = active and GetEntityCoords(player)
        local nearest, best = nil, math.huge
        for ped, e in pairs(entries) do
            if not exists(e) then N.release(ped, e.owner)
            else
                if e.motion and now >= e.motion.untilAt then stop(e) end
                local distance = active and distance2(pos, GetEntityCoords(ped)) or math.huge
                if not active or e.paused or IsEntityDead(ped) or distance > C.leaveRadius^2 then
                    e.visitor = false
                    stop(e)
                elseif distance <= C.radius^2 and canSee(e, player) then
                    if not e.visitor then
                        e.visitor, e.greeted = true, now < e.greetAt
                        e.reactAt = now + math.random(350, 900)
                        e.chatAt = now + math.random(C.chatterMin, C.chatterMax)
                    end
                    e.seenAt = now
                    if distance < best then nearest, best = e, distance end
                elseif e.seenAt and now - e.seenAt >= C.lostSightMs then
                    e.visitor = false
                    stop(e)
                end
            end
        end
        if nearest and now >= nearest.reactAt then
            if now >= (nearest.lookAt or 0) then
                TaskLookAtEntity(nearest.ped, player, 2000, 2048, 3)
                nearest.lookAt = now + math.random(8000, 14000)
            end
            react(nearest, player, now)
        end
        -- Only recent greetings are retained, including across local stream-out/in.
        for key, expires in pairs(greetings) do if now >= expires then greetings[key] = nil end end
        Wait(C.tickMs)
    end
end)
AddEventHandler('esx:onPlayerLogout', function()
    for _, e in pairs(entries) do stop(e) e.request=nil e.visitor = false TaskClearLookAt(e.ped) end
    greetings, speechAt, gestureAt = {}, 0, 0
end)
AddEventHandler('onResourceStop', function(resource)
    for ped, e in pairs(entries) do
        if resource == GetCurrentResourceName() or e.owner == resource then N.release(ped, e.owner) end
    end
end)
