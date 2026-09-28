local W = Commerce.Weapons
local K = W.clerkClient
local X = { shops = {}, instances = {}, blips = {}, state = 'Closed', dev = false }
W.client = X
local ESX = exports.es_extended:getSharedObject()
local scene, refreshBusy, epoch = nil, false, 0
local function exists(e) return e and e ~= 0 and DoesEntityExist(e) end
local function erase(e) if exists(e) then SetEntityAsMissionEntity(e, true, true) DeleteEntity(e) end end
local function model(hash, alive, weapon)
    if weapon then RequestWeaponAsset(hash, 31, 0) else
        if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
        RequestModel(hash)
    end
    local deadline = GetGameTimer() + 4000
    while alive() and GetGameTimer() < deadline do
        if weapon and HasWeaponAssetLoaded(hash) or not weapon and HasModelLoaded(hash) then return true end
        Wait(25)
    end
    if weapon then RemoveWeaponAsset(hash) else SetModelAsNoLongerNeeded(hash) end
    return false
end
local function destroy(id)
    local instance = X.instances[id]
    if not instance then return end
    instance.alive = false
    K.reset(instance)
    for _, object in pairs(instance.objects) do erase(object.entity) end
    if instance.npc then pcall(function() exports.rp_core:rpReleasePed(instance.npc) end) erase(instance.npc) end
    X.instances[id] = nil
end
X.destroyInstance = destroy
local function transform(entity, pos, rot)
    SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, false, false, false)
    SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
end
local function spawnDisplay(instance, display)
    local entry = { loading = true, catalog = display.catalog, amount = 0 }
    instance.objects[display.id] = entry
    CreateThread(function()
        local def = W.catalog[display.catalog]
        local hash = joaat(def.weapon and def.item or def.model)
        local function alive() return instance.alive and instance.objects[display.id] == entry end
        if not model(hash, alive, def.weapon) then entry.loading = false return end
        if alive() then
            local p = display.pos
            local object = def.weapon and CreateWeaponObject(hash, 0, p.x, p.y, p.z, true, 1.0, 0, false, false)
                or CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
            if object and object ~= 0 then
                SetEntityAsMissionEntity(object, true, true)
                SetEntityCollision(object, false, false) SetEntityInvincible(object, true) FreezeEntityPosition(object, true)
                transform(object, display.pos, display.rot)
                entry.entity = object
            end
        end
        if def.weapon then RemoveWeaponAsset(hash) else SetModelAsNoLongerNeeded(hash) end
        entry.loading = false
    end)
end
local function updateInstance(id, shop)
    local instance = X.instances[id]
    if not instance then instance = { alive = true, objects = {}, shop = shop } X.instances[id] = instance end
    instance.shop = shop
    local wanted = {}
    for _, d in ipairs(shop.displays or {}) do
        wanted[d.id] = true
        local entry = instance.objects[d.id]
        if entry and entry.catalog ~= d.catalog then erase(entry.entity) instance.objects[d.id] = nil entry = nil end
        if not entry then spawnDisplay(instance, d)
        elseif exists(entry.entity) and (not scene or scene.instance ~= instance) then transform(entry.entity, d.pos, d.rot) end
    end
    for key, entry in pairs(instance.objects) do if not wanted[key] then erase(entry.entity) instance.objects[key] = nil end end
    local npc = shop.npc
    if instance.npc and not exists(instance.npc) then
        K.reset(instance)
        exports.rp_core:rpReleasePed(instance.npc) instance.npc = nil
    end
    if instance.npc and (not npc or instance.npcModel ~= npc.model) then
        K.reset(instance)
        exports.rp_core:rpReleasePed(instance.npc) erase(instance.npc) instance.npc = nil
    end
    if npc and not instance.npc and not instance.npcLoading then
        instance.npcLoading = true
        local modelName = npc.model
        CreateThread(function()
            local hash = joaat(modelName)
            if model(hash, function() return instance.alive and instance.shop.npc == npc and npc.model == modelName end) then
                if instance.alive and instance.shop.npc == npc and npc.model == modelName and IsModelAPed(hash) then
                    local ped = CreatePed(4, hash, npc.pos.x, npc.pos.y, npc.pos.z, npc.heading, false, false)
                    if ped ~= 0 then
                        instance.npc, instance.npcModel = ped, modelName
                        SetEntityAsMissionEntity(ped, true, true) SetEntityInvincible(ped, true)
                        FreezeEntityPosition(ped, true) SetBlockingOfNonTemporaryEvents(ped, true)
                        SetPedCanRagdoll(ped, false) SetPedCanEvasiveDive(ped, false)
                        SetPedFleeAttributes(ped, 0, false) SetPedCombatAttributes(ped, 46, false)
                        SetPedDropsWeaponsWhenDead(ped, false) SetPedCanBeTargetted(ped, false)
                        exports.rp_core:rpProtectPed(ped)
                        K.apply(instance, npc)
                    end
                end
                SetModelAsNoLongerNeeded(hash)
            end
            instance.npcLoading = false
            if instance.alive and instance.shop.npc and (instance.shop.npc ~= npc or npc.model ~= modelName) then updateInstance(id, instance.shop) end
        end)
    elseif npc and exists(instance.npc) then
        K.apply(instance, npc)
    end
    return instance
end
X.updateInstance = updateInstance
function X.setDraft(shop)
    X.draft = shop
    if shop then
        if shop.id then destroy(shop.normalshop and 'store:'..shop.id or shop.id) end
        updateInstance('draft', shop)
    else destroy('draft') end
end
function X.refreshDraft() if X.draft then updateInstance('draft', X.draft) end end
local function clearComponent(s)
    if s.component and exists(s.component.entity) then
        RemoveWeaponComponentFromWeaponObject(s.component.entity, s.component.hash)
    end
    s.component = nil
end
function X.focus(display, preview, component)
    local s = scene
    if not s or s.closing then return end
    clearComponent(s)
    local entry = display and s.instance.objects[display.id]
    if component and entry and exists(entry.entity) and W.catalog[display.catalog].weapon then
        local hash = joaat(component)
        if DoesWeaponTakeWeaponComponent(joaat(W.catalog[display.catalog].item), hash) then
            local ticket={entity=entry.entity,hash=hash}
            s.component=ticket
            CreateThread(function()
                local componentModel=GetWeaponComponentTypeModel(hash)
                local function alive() return scene==s and not s.closing and s.component==ticket and exists(ticket.entity) end
                if model(componentModel,alive) then
                    if alive() then GiveWeaponComponentToWeaponObject(ticket.entity,hash) end
                    SetModelAsNoLongerNeeded(componentModel)
                end
            end)
        end
    end
    -- Changing an accessory never restarts the camera or prop animation.
    local selected=display and display.id
    if s.selected==selected and s.preview==preview then return end
    s.lightFrom = s.lightPosition and W.copy(s.lightPosition) or nil
    if s.selected~=selected then s.presented=false end
    if not s.presented then s.presentationAt=GetGameTimer()+W.camera.duration end
    local goal = display and W.pose(display, preview and 1 or 0, 1) or W.copy(s.current)
    s.selected, s.preview = selected, preview
    s.from, s.goal, s.started = W.copy(s.current), goal, GetGameTimer()
    X.state = 'Transition'
end
-- One local, frame-scoped light in the existing scene loop. No light entity,
-- network traffic or work for shops that nobody is currently inspecting.
local function illuminate(s, display, position, t, dt)
    local cfg = W.camera.lighting
    if not cfg.enabled then return end
    local active = display and position and not s.closing
    local intensity = active and (s.preview and cfg.preview or cfg.browse) or 0.0
    s.lightStrength = W.lerp(s.lightStrength or 0.0, intensity, 1.0 - math.exp(-cfg.fadeSpeed * dt))
    if active then
        local a = math.rad(display.heading)
        local goal = { x = position.x - math.sin(a) * cfg.forward + math.cos(a) * cfg.side,
            y = position.y + math.cos(a) * cfg.forward + math.sin(a) * cfg.side, z = position.z + cfg.height }
        s.lightPosition = W.mix(s.lightFrom or goal, goal, t)
    end
    local p = s.lightPosition
    local strength = s.lightStrength * (s.closing and (1.0 - t) or 1.0)
    if p and strength > 0.01 then
        DrawLightWithRange(p.x, p.y, p.z, cfg.color.r, cfg.color.g, cfg.color.b, cfg.range, strength)
    end
end
local function finish(s)
    if scene ~= s then return end
    clearComponent(s)
    for _, d in ipairs(s.shop.displays) do
        local object = s.instance.objects[d.id]
        if object and exists(object.entity) then
            transform(object.entity, d.pos, d.rot)
            object.amount,object.pitch,object.yaw,object.pitchVelocity,object.yawVelocity=0,0,0,0,0
            object.moveTarget,object.moveFrom,object.moveStart=nil,nil,nil
        end
    end
    if DoesCamExist(s.cam) then DestroyCam(s.cam, false) end
    if exists(s.ped) then FreezeEntityPosition(s.ped, s.wasFrozen) end
    scene = nil X.state = X.dev and 'DevMode' or 'Closed'
    if s.onEnd then
        local ok, err = pcall(s.onEnd)
        if not ok then print('[rp_commerce] Scene close callback failed: '..tostring(err)) end
    end
end
function X.endScene(immediate)
    local s = scene
    if not s or s.closing then if immediate and s then finish(s) end return end
    s.closing, s.started = true, GetGameTimer()
    clearComponent(s)
    X.state = 'Transition'
    RenderScriptCams(false, not immediate, immediate and 0 or W.camera.exitDuration, true, true)
    if immediate then finish(s) end
end
function X.beginScene(shop, onEnd)
    if scene or IsEntityDead(PlayerPedId()) or not ESX.IsPlayerLoaded() then return false end
    local id = X.dev and 'draft' or shop.id
    local instance = updateInstance(id, shop)
    local deadline = GetGameTimer() + 5000
    while instance.alive and GetGameTimer() < deadline do
        local loading = false for _, obj in pairs(instance.objects) do if obj.loading then loading = true break end end
        if not loading then break end Wait(25)
    end
    if not instance.alive or scene or not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId())
        or W.distance(GetEntityCoords(PlayerPedId()), shop.coords) > (X.dev and 75 or Commerce.Config.radius + 0.2) then return false end
    local first = shop.displays[1]
    if not first then return false end
    local object = instance.objects[first.id]
    if not object or not exists(object.entity) then return false end
    local ped, cam = PlayerPedId(), CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if cam == 0 then return false end
    local p, rot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    SetCamCoord(cam, p.x, p.y, p.z) SetCamRot(cam, rot.x, rot.y, rot.z, 2) SetCamFov(cam, GetGameplayCamFov())
    local a, z = math.rad(rot.z), math.rad(rot.x)
    local current = { camera = { x=p.x,y=p.y,z=p.z }, target = { x=p.x-math.sin(a)*math.cos(z)*2,
        y=p.y+math.cos(a)*math.cos(z)*2,z=p.z+math.sin(z)*2 }, fov=GetGameplayCamFov() }
    scene = { shop = shop, instance = instance, ped = ped, cam = cam, wasFrozen = IsEntityPositionFrozen(ped),
        current = current, onEnd = onEnd, frameAt = GetGameTimer() }
    FreezeEntityPosition(ped, true)
    RenderScriptCams(true, false, 0, true, true)
    X.focus(first, false)
    return true
end
CreateThread(function()
    while true do
        local s = scene
        if s then
            if IsEntityDead(PlayerPedId()) or PlayerPedId() ~= s.ped or not ESX.IsPlayerLoaded()
                or not s.instance.alive or IsPauseMenuActive()
                or (not s.closing and exports.rp_ui:rpGetView() ~= 'nativeui') then X.endScene(true)
            else
                DisablePlayerFiring(PlayerId(), true)
                for _, control in ipairs({ 24,25,30,31,32,33,34,35,37,44,45,140,141,142 }) do DisableControlAction(0,control,true) end
                local now=GetGameTimer()
                local dt=math.min(0.1,math.max(0,(now-s.frameAt)/1000)) s.frameAt=now
                local pitchInput=(IsDisabledControlPressed(0,32) and 1 or 0)-(IsDisabledControlPressed(0,33) and 1 or 0)
                local yawInput=(IsDisabledControlPressed(0,35) and 1 or 0)-(IsDisabledControlPressed(0,34) and 1 or 0)
                local duration = s.closing and W.camera.exitDuration or W.camera.duration
                local t = W.ease((GetGameTimer()-s.started)/duration)
                if not s.closing and not s.presented and now>=s.presentationAt then s.presented=true end
                local litDisplay, litPosition
                for _, d in ipairs(s.shop.displays) do
                    local object = s.instance.objects[d.id]
                    if object and exists(object.entity) then
                        local target = not s.closing and s.presented and s.selected == d.id and 1 or 0
                        if object.moveTarget~=target then
                            object.moveTarget,object.moveFrom,object.moveStart=target,object.amount or 0,now
                        end
                        local motion=W.camera.presentation
                        local progress=(now-object.moveStart)/(target==1 and motion.duration or motion.returnDuration)
                        local eased=target==1 and W.presentEase(progress) or W.ease(progress)
                        object.amount = W.lerp(object.moveFrom,target,eased)
                        object.pitch,object.pitchVelocity=W.spring(object.pitch or 0,object.pitchVelocity or 0,
                            pitchInput*W.camera.inspect.pitch*target,dt)
                        object.yaw,object.yawVelocity=W.spring(object.yaw or 0,object.yawVelocity or 0,
                            yawInput*W.camera.inspect.yaw*target,dt)
                        local pose=W.pose(d,0,object.amount)
                        pose.rotation.x=pose.rotation.x+object.pitch*object.amount
                        pose.rotation.z=pose.rotation.z+object.yaw*object.amount
                        transform(object.entity,pose.object,pose.rotation)
                        if s.selected == d.id then litDisplay, litPosition = d, pose.object end
                    end
                end
                illuminate(s, litDisplay, litPosition, t, dt)
                if s.closing then if t == 1 then finish(s) end else
                    s.current = { camera = W.mix(s.from.camera,s.goal.camera,t), target = W.mix(s.from.target,s.goal.target,t),
                        fov = W.lerp(s.from.fov,s.goal.fov,t) }
                    local p, target = s.current.camera, s.current.target
                    SetCamCoord(s.cam,p.x,p.y,p.z) PointCamAtCoord(s.cam,target.x,target.y,target.z) SetCamFov(s.cam,s.current.fov)
                    if t == 1 then X.state = s.preview and 'Preview' or 'Browse' end
                end
            end
        end
        Wait(scene and 0 or 250) -- Native camera/entity interpolation is per frame only while in the shop.
    end
end)
function X.refresh()
    if refreshBusy or not ESX.IsPlayerLoaded() then return end
    refreshBusy = true
    local generation = epoch
    local ok, data = pcall(lib.callback.await, 'rp_commerce:weaponshops', false)
    refreshBusy = false
    if generation ~= epoch or not ok or not data or not data.ok or not ESX.IsPlayerLoaded() then return end
    local nextShops = {}
    for _, shop in ipairs(data.shops) do
        nextShops[shop.id] = shop
        local old = X.shops[shop.id]
        if old and old.revision ~= shop.revision then
            if scene and scene.shop.id == shop.id and not X.dev then X.endScene(true) end
            destroy(shop.id)
        end
        Commerce.Config.venues['weapon_'..shop.id] = { weaponshop = true, kind = 'shop', coords = shop.coords, label = shop.label, shopId = shop.id }
        if not X.blips[shop.id] then
            local b = AddBlipForCoord(shop.coords.x,shop.coords.y,shop.coords.z)
            SetBlipSprite(b,110) SetBlipColour(b,0) SetBlipScale(b,0.75) SetBlipAsShortRange(b,true)
            X.blips[shop.id] = b
        end
        local b = X.blips[shop.id]
        SetBlipCoords(b,shop.coords.x,shop.coords.y,shop.coords.z)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(shop.label) EndTextCommandSetBlipName(b)
    end
    for id in pairs(X.shops) do if not nextShops[id] then
        if scene and scene.shop.id == id and not X.dev then X.endScene(true) end
        destroy(id) Commerce.Config.venues['weapon_'..id] = nil
        if X.blips[id] then RemoveBlip(X.blips[id]) X.blips[id] = nil end
    end end
    X.shops = nextShops
end
RegisterNetEvent('rp_commerce:weaponshopsChanged', function()
    if source == 65535 then CreateThread(function() Wait(1600) X.refresh() end) end
end)
CreateThread(function() while true do X.refresh() Wait(5000) end end)
CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for id, shop in pairs(X.shops) do
            local distance = W.distance(p,shop.coords)
            if shop.displays and ESX.IsPlayerLoaded() and distance < W.streamIn and not (X.draft and X.draft.id == id) then updateInstance(id,shop)
            elseif distance > W.streamOut or not ESX.IsPlayerLoaded() then destroy(id) end
        end
        if ESX.IsPlayerLoaded() then
            for _, instance in pairs(X.instances) do K.tick(instance, PlayerPedId(), GetGameTimer()) end
        end
        Wait(750)
    end
end)
function X.clearWorld()
    epoch = epoch + 1
    X.endScene(true)
    for id in pairs(X.instances) do destroy(id) end
    for id,b in pairs(X.blips) do RemoveBlip(b) Commerce.Config.venues['weapon_'..id] = nil end
    X.shops, X.blips = {}, {}
end
AddEventHandler('esx:onPlayerLogout', X.clearWorld)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'rp_ui' or resource == 'rp_nativeui' or resource == 'rp_core' then X.clearWorld() end
end)
