local ESX,G,D=exports.es_extended:getSharedObject(),Inventory.ground,Inventory.dropMotion
local drops,closest,picking,epoch={},nil,false,0
local handOwner
local function stopMotion(entry)
    if handOwner==entry then
        StopAnimTask(entry.ped,D.dict,D.clip,2.0)
        RemoveAnimDict(D.dict)
        handOwner=nil
    end
end
local function remove(entry)
    stopMotion(entry)
    if entry.entity and DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    entry.entity=nil
end
local function clear()
    epoch=epoch+1 closest=nil picking=false
    for _,entry in pairs(drops) do remove(entry) end
    drops={}
    exports.rp_ui:rpHideInteraction()
end
local function alive(entry,version) return version==epoch and drops[entry.id]==entry end
local function distanceSquared(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function applyVisual(entry)
    local visual=entry.visual
    if entry.atRest and not entry.poseApplied and visual and entry.entity and DoesEntityExist(entry.entity) then
        SetEntityCoordsNoOffset(entry.entity,visual.pos.x,visual.pos.y,visual.pos.z,false,false,false)
        SetEntityRotation(entry.entity,visual.rot.x,visual.rot.y,visual.rot.z,2,true)
        entry.poseApplied=true
    end
end
local function fall(entry,version,entity)
    local player=GetPlayerFromServerId(entry.owner or 0)
    local ped=player~=-1 and GetPlayerPed(player) or 0
    local localOwner=entry.owner==GetPlayerServerId(PlayerId())
    if ped==0 or not DoesEntityExist(ped) or IsEntityDead(ped)
        or distanceSquared(GetEntityCoords(ped),entry.pos)>9 then return false end
    local grip=D.grip
    local profile=grip.models[entry.model] or (entry.weapon and grip.weapon) or grip.default
    local bone=GetPedBoneIndex(ped,grip.bone)
    local x,y,z=profile.pos.x,profile.pos.y,profile.pos.z
    if bone<=0 then
        bone=GetPedBoneIndex(ped,grip.fallbackBone)
        x,y,z=x+grip.fallbackOffset.x,y+grip.fallbackOffset.y,z+grip.fallbackOffset.z
    end
    -- An unavailable grip must never attach to the ped root/abdomen.
    if bone<=0 then return false end
    entry.ped=ped
    if localOwner and not handOwner then
        handOwner=entry
        RequestAnimDict(D.dict)
        local deadline=GetGameTimer()+1500
        while alive(entry,version) and not HasAnimDictLoaded(D.dict) and GetGameTimer()<deadline do Wait(25) end
        if not alive(entry,version) then stopMotion(entry) return false end
        if HasAnimDictLoaded(D.dict) then TaskPlayAnim(ped,D.dict,D.clip,2.0,-2.0,D.duration,48,0.0,false,false,false) end
    end
    if not alive(entry,version) or not DoesEntityExist(ped) or IsEntityDead(ped) then stopMotion(entry) return false end
    -- Prop grip plus model-specific pivot correction, not an unadjusted wrist origin.
    -- Enable the ped rotation mode so configured pitch/roll are actually respected.
    AttachEntityToEntity(entity,ped,bone,x,y,z,profile.rot.x,profile.rot.y,profile.rot.z,false,false,false,true,2,true)
    SetEntityVisible(entity,true,false)
    local releaseAt=GetGameTimer()+D.releaseMs
    while alive(entry,version) and DoesEntityExist(ped) and not IsEntityDead(ped) and GetGameTimer()<releaseAt do Wait(25) end
    if not alive(entry,version) then stopMotion(entry) return false end
    -- Detach preserves the actual animated hand transform. No scripted arc or per-frame teleport.
    DetachEntity(entity,true,false)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then stopMotion(entry) return false end
    -- Ignore the releasing hand only this frame, not this ped for the whole drop lifetime.
    SetEntityNoCollisionEntity(entity,ped,true)
    FreezeEntityPosition(entity,false)
    SetEntityDynamic(entity,true)
    SetEntityHasGravity(entity,true)
    SetEntityCollision(entity,true,true)
    ActivatePhysics(entity)
    local forward=GetEntityForwardVector(ped)
    SetEntityVelocity(entity,forward.x*0.12,forward.y*0.12,-0.08)
    local started,stable,previous=GetGameTimer(),nil,GetEntityRotation(entity,2)
    local settled=false
    while alive(entry,version) and GetGameTimer()-started<D.physicsMs do
        local now=GetGameTimer()
        local pos,rot=GetEntityCoords(entity),GetEntityRotation(entity,2)
        if distanceSquared(pos,entry.pos)>D.maxDrift^2 then break end
        local angular=math.abs((rot.x-previous.x+180)%360-180)+math.abs((rot.y-previous.y+180)%360-180)+math.abs((rot.z-previous.z+180)%360-180)
        if (HasEntityCollidedWithAnything(entity) or not IsEntityInAir(entity)) and GetEntitySpeed(entity)<0.08 and angular<1.5 then
            stable=stable or now
            if now-stable>=D.settleMs then settled=distanceSquared(pos,entry.pos)<=D.maxDrift^2 break end
        else stable=nil end
        previous=rot
        if now-started>D.duration-D.releaseMs then stopMotion(entry) end
        Wait(50) -- GTA simulates the fall; no 0ms physics/sync loop.
    end
    stopMotion(entry)
    if not alive(entry,version) then return false end
    -- Some weapon models keep tiny contact/rotation jitter and never reach the quiet threshold.
    -- At the budget limit keep their actual supported pose, never reset a landed gun to the anchor.
    if not settled and (HasEntityCollidedWithAnything(entity) or not IsEntityInAir(entity))
        and distanceSquared(GetEntityCoords(entity),entry.pos)<=D.maxDrift^2 then settled=true end
    FreezeEntityPosition(entity,true)
    SetEntityDynamic(entity,false)
    if settled and localOwner then
        local pos,rot=GetEntityCoords(entity),GetEntityRotation(entity,2)
        TriggerServerEvent('rp_inventory:groundSettled',entry.id,{x=pos.x,y=pos.y,z=pos.z},{x=rot.x,y=rot.y,z=rot.z})
    end
    return settled
end
local function spawn(entry)
    local version=epoch
    CreateThread(function()
        local hash=joaat(entry.model)
        local weapon=entry.weapon
        local fallback=not weapon and type(entry.fallbackModel)=='string' and joaat(entry.fallbackModel) or nil
        if fallback and (not IsModelInCdimage(fallback) or not IsModelValid(fallback)) then fallback=nil end
        if weapon then RequestWeaponAsset(hash,31,0)
        else
            if not IsModelInCdimage(hash) or not IsModelValid(hash) then hash=fallback or joaat(G.model) end
            RequestModel(hash)
        end
        local deadline=GetGameTimer()+4000
        local function loaded() return weapon and HasWeaponAssetLoaded(hash) or not weapon and HasModelLoaded(hash) end
        while alive(entry,version) and not loaded() and GetGameTimer()<deadline do Wait(25) end
        local function release() if weapon then RemoveWeaponAsset(hash) else SetModelAsNoLongerNeeded(hash) end end
        if alive(entry,version) and not loaded() and fallback and hash~=fallback then
            release()
            hash=fallback
            RequestModel(hash)
            deadline=GetGameTimer()+1500
            while alive(entry,version) and not loaded() and GetGameTimer()<deadline do Wait(25) end
        end
        if not alive(entry,version) or not loaded() then release() entry.retry=GetGameTimer()+5000 return end
        local components={}
        if weapon then
            for _, value in ipairs(type(entry.components)=='table' and entry.components or {}) do
                local component=type(value)=='string' and joaat(value) or type(value)=='number' and value or type(value)=='table' and value.hash
                if type(component)=='number' and DoesWeaponTakeWeaponComponent(hash,component) then
                    local model=GetWeaponComponentTypeModel(component)
                    if model and model~=0 then
                        RequestModel(model)
                        while alive(entry,version) and not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(25) end
                        local ready=HasModelLoaded(model)
                        SetModelAsNoLongerNeeded(model)
                        if not alive(entry,version) or not ready then release() entry.retry=GetGameTimer()+5000 return end
                    end
                    components[#components+1]=component
                end
            end
        end
        local p=entry.pos
        local entity=weapon and CreateWeaponObject(hash,0,p.x,p.y,p.z,true,1.0,0)
            or CreateObjectNoOffset(hash,p.x,p.y,p.z,false,false,false)
        release()
        if entity==0 then entry.retry=GetGameTimer()+5000 return end
        entry.entity=entity
        if weapon then
            for _,component in ipairs(components) do GiveWeaponComponentToWeaponObject(entity,component) end
            if type(entry.tintIndex)=='number' then SetWeaponObjectTintIndex(entity,entry.tintIndex) end
        end
        SetEntityAsMissionEntity(entity,true,true)
        SetEntityInvincible(entity,true)
        SetEntityCollision(entity,false,false)
        FreezeEntityPosition(entity,true)
        local fresh=entry.age<=1 and not entry.visual
        if fresh then SetEntityVisible(entity,false,false) end
        local z=p.z
        local ray=StartShapeTestLosProbe(p.x,p.y,p.z+0.65,p.x,p.y,p.z-1.0,1,PlayerPedId(),7)
        local status,hit,point
        repeat
            status,hit,point=GetShapeTestResult(ray)
            if status==1 then Wait(0) end
        until status~=1 or not alive(entry,version) or GetGameTimer()>deadline
        if not alive(entry,version) then remove(entry) return end
        if status==2 and (hit==1 or hit==true) and math.abs(point.z-p.z)<1.0 then
            local minimum=GetModelDimensions(GetEntityModel(entity))
            z=point.z-(weapon and minimum.y or minimum.z)+0.02
        end
        local settled=fresh and fall(entry,version,entity)
        if not alive(entry,version) then remove(entry) return end
        if not settled then
            -- Old streamed drops / unavailable ped / missing model collision: safe stationary fallback.
            SetEntityRotation(entity,weapon and 90.0 or 0.0,0.0,0.0,2,true)
            SetEntityCoordsNoOffset(entity,p.x,p.y,z,false,false,false)
        end
        entry.atRest=true
        applyVisual(entry)
        -- Includes freshly landed, re-streamed and stationary fallback props.
        -- Keep the synchronized resting pose while retaining the model's collision mesh.
        FreezeEntityPosition(entity,true)
        SetEntityCollision(entity,true,true)
        SetEntityVisible(entity,true,false)
    end)
end
RegisterNetEvent('rp_inventory:ground',function(payload)
    if source~=65535 or type(payload)~='table' or #payload>G.limit or not ESX.IsPlayerLoaded() then return end
    local retained={}
    for _,value in ipairs(payload) do
        if type(value)=='table' and type(value.id)=='string' and type(value.label)=='string'
            and type(value.model)=='string' and type(value.pos)=='table' and type(value.pos.x)=='number'
            and type(value.pos.y)=='number' and type(value.pos.z)=='number' and type(value.age)=='number'
            and type(value.count)=='number' then
            retained[value.id]=true
            if not drops[value.id] then drops[value.id]=value spawn(value)
            else
                local entry=drops[value.id]
                entry.pos=value.pos
                entry.visual=value.visual or entry.visual
                applyVisual(entry)
                if not entry.entity and entry.retry and GetGameTimer()>entry.retry then
                    entry.retry=nil entry.age=value.age spawn(entry)
                end
            end
        end
    end
    for id,entry in pairs(drops) do if not retained[id] then drops[id]=nil remove(entry) end end
end)
local function register()
    exports.rp_core:rpRegisterInputAction({id='rp_inventory:pickup',label='Gegenstand aufheben',category='Interaktionen',
        defaultKey='E',description='Den angezeigten Gegenstand vom Boden aufheben.'})
end
CreateThread(register)
AddEventHandler('onClientResourceStart',function(resource) if resource=='rp_core' then register() end end)
AddEventHandler('rp_core:inputPressed',function(action)
    if action~='rp_inventory:pickup' or picking or not closest or not exports.rp_ui:rpIsInteractionActive(action) then return end
    local id,version=closest.id,epoch
    picking=true
    CreateThread(function()
        local ok,result=pcall(lib.callback.await,'rp_inventory:pickupStart',false,id)
        if ok and result and result.ok and version==epoch then
            local ped,dict=PlayerPedId(),'pickup_object'
            RequestAnimDict(dict)
            local deadline=GetGameTimer()+1500
            while not HasAnimDictLoaded(dict) and GetGameTimer()<deadline and version==epoch do Wait(25) end
            if version==epoch and not IsEntityDead(ped) then
                if HasAnimDictLoaded(dict) then TaskPlayAnim(ped,dict,'pickup_low',4.0,-4.0,1000,48,0.0,false,false,false) end
                Wait(900)
                if version==epoch and ped==PlayerPedId() and not IsEntityDead(ped) then
                    ok,result=pcall(lib.callback.await,'rp_inventory:pickupFinish',false,result.token)
                end
                StopAnimTask(ped,dict,'pickup_low',1.0)
            end
            RemoveAnimDict(dict)
        end
        if version~=epoch then return end
        if not ok or not result or not result.ok then
            lib.notify({title='Aufheben',description='Nicht möglich: zu wenig Platz, zu weit entfernt oder bereits aufgehoben.',type='error'})
        end
        picking=false
    end)
end)
CreateThread(function()
    while true do
        closest=nil
        local distance=G.radius
        if ESX.IsPlayerLoaded() and not picking then
            local p=GetEntityCoords(PlayerPedId())
            for _,entry in pairs(drops) do
                local d=#(p-vector3(entry.pos.x,entry.pos.y,entry.pos.z))
                if d<distance then closest,distance=entry,d end
            end
        end
        if closest then
            exports.rp_ui:rpShowInteraction({action='rp_inventory:pickup',label=('%s × %s'):format(closest.count,closest.label),
                verb='Aufheben',icon='bag',distance=distance})
        else exports.rp_ui:rpHideInteraction() end
        Wait(200)
    end
end)
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then clear() end end)
