-- Local shop presentation only; purchases and editor permissions remain server-owned.
local W = Commerce.Weapons
local C, K = W.clerk, {}
W.clerkClient = K
local function valid(instance, ped)
    return ped and ped ~= 0 and instance.alive and instance.npc == ped and DoesEntityExist(ped)
end
-- Model bounding boxes can extend below the shoes. Use the live skeleton,
-- with a small ankle-to-sole allowance, instead of treating min.z as the feet.
local function footHeight(ped)
    local p = GetEntityCoords(ped)
    local left = GetPedBoneCoords(ped, 0x3779, 0.0, 0.0, 0.0)
    local right = GetPedBoneCoords(ped, 0xCC4D, 0.0, 0.0, 0.0)
    local foot = math.min(left.z, right.z) - C.soleClearance
    local height = p.z - foot
    if height == height and height >= 0.3 and height <= 1.8 then return height, foot end
end
local function crossed(npc, instance)
    -- Existing shops used this as their default. Keep saved records compatible.
    return not instance.shop.normalshop and (npc.scenario == 'AMMU_ARMS_CROSSED' or npc.scenario == 'WORLD_HUMAN_STAND_IMPATIENT')
end
function K.reset(instance)
    if instance.npc then pcall(function() exports.rp_core:rpConfigureNpc(instance.npc, { paused = true }) end) end
    instance.socialPaused = nil
    instance.clerkTicket = nil
    instance.clerkPlacement = nil
    instance.clerkPose = nil
end
local function animate(instance, clip, duration)
    local ped, ticket = instance.npc, {}
    instance.clerkTicket = ticket
    CreateThread(function()
        RequestAnimDict(C.dict)
        local deadline = GetGameTimer() + 2000
        local function current() return valid(instance, ped) and instance.clerkTicket == ticket end
        while current() and not HasAnimDictLoaded(C.dict) and GetGameTimer() < deadline do Wait(25) end
        if current() then
            if HasAnimDictLoaded(C.dict) then
                TaskPlayAnim(ped, C.dict, clip, 3.0, -3.0, duration, duration < 0 and 1 or 0, 0.0, false, false, false)
            end
        end
        RemoveAnimDict(C.dict)
    end)
end
function K.apply(instance, npc)
    local ped = instance.npc
    if not valid(instance, ped) then return end
    local old = instance.clerkPose
    if old and old.ped == ped and old.x == npc.pos.x and old.y == npc.pos.y and old.z == npc.pos.z
        and old.heading == npc.heading and old.scenario == npc.scenario then return end
    K.reset(instance)
    -- Stored positions are sole anchors. Never add an editor correction here.
    local rootHeight = footHeight(ped) or 1.0 -- provisional until the skeleton is ready
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, npc.pos.x, npc.pos.y, npc.pos.z + rootHeight, false, false, false)
    SetEntityHeading(ped, npc.heading)
    FreezeEntityPosition(ped, true)
    instance.clerkPose = { ped=ped, x=npc.pos.x, y=npc.pos.y, z=npc.pos.z, heading=npc.heading, scenario=npc.scenario }
    if crossed(npc, instance) then animate(instance, C.idle, -1)
    else TaskStartScenarioInPlace(ped, npc.scenario, 0, false) end
    local paused = W.client.dev == true
    exports.rp_core:rpConfigureNpc(ped, {
        profile = crossed(npc, instance) and 'ammunation' or 'shop',
        key = (instance.shop.normalshop and 'shop:' or 'weapon:') .. (instance.shop.id or 'draft'),
        paused = paused,
    })
    instance.socialPaused = paused
    local placement = {}
    instance.clerkPlacement = placement
    local anchor = { x = npc.pos.x, y = npc.pos.y, z = npc.pos.z }
    CreateThread(function()
        -- Let the newly spawned/replaced model update its bones. Bounded and
        -- cancellable; streaming ticks never repeatedly snap a manual position.
        local deadline, previous, stable = GetGameTimer() + 1000, nil, 0
        repeat
            Wait(50)
            if not valid(instance, ped) or instance.clerkPlacement ~= placement then return end
            local height = footHeight(ped)
            if height then
                stable = previous and math.abs(height - previous) < 0.005 and stable + 1 or 0
                previous = height
                SetEntityCoordsNoOffset(ped, anchor.x, anchor.y, anchor.z + height, false, false, false)
            end
        until stable >= 2 or GetGameTimer() >= deadline
        instance.clerkPlacement = nil
    end)
end
function K.tick(instance)
    local paused = W.client.dev == true
    if valid(instance, instance.npc) and instance.socialPaused ~= paused then
        exports.rp_core:rpConfigureNpc(instance.npc, { paused = paused })
        instance.socialPaused = paused
    end
end

-- Bounded interior-safe floor probe; +0.5 is a probe origin, not a permanent hover offset.
function K.playerFloor(isCurrent, accept)
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local _, feet = footHeight(ped)
    if not feet then accept(nil) return end
    CreateThread(function()
        local top = p.z + C.placementLift
        local deadline = GetGameTimer() + 1000
        for _ = 1, 4 do
            -- World/objects only: another clerk/player is never a floor.
            local ray = StartShapeTestRay(p.x, p.y, top, p.x, p.y, feet - 0.4, 17, ped, 7)
            local state, hit, point, normal
            repeat
                state, hit, point, normal = GetShapeTestResult(ray)
                if state == 1 then Wait(25) end
            until state ~= 1 or not isCurrent() or GetGameTimer() >= deadline
            if not isCurrent() then return end
            if PlayerPedId() ~= ped or W.distance(GetEntityCoords(ped), p) > 0.35 then accept(nil) return end
            if state ~= 2 or (hit ~= 1 and hit ~= true) or GetGameTimer() >= deadline then break end
            if math.abs(point.x-p.x) >= 0.1 or math.abs(point.y-p.y) >= 0.1 or point.z > top then break end
            if point.z <= feet + 0.15 and point.z >= feet - 0.4 then
                if normal.z > 0.5 then accept({x=p.x,y=p.y,z=point.z}) return end
                break
            end
            -- Shelves/counters above the standing player's feet are not their
            -- supporting floor. Retry below that surface, with a strict bound.
            top = point.z - 0.05
            if top < feet - 0.4 then break end
        end
        accept(nil)
    end)
end
