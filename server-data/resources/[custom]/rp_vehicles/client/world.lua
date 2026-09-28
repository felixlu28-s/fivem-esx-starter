local C,R,ESX=Garage.Config,Garage.Rules,exports.es_extended:getSharedObject()
local W={instances={},stopped=false,received=false}
Garage.World=W
-- The client must use the server's current instance catalog, not the seed data.
C.garages={}
local function modelHash(model) return type(model)=='number' and model or joaat(model) end
local function loadModel(model,active)
    local hash=modelHash(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAPed(hash) then return end
    RequestModel(hash)
    local deadline=GetGameTimer()+4000
    while active() and not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(50) end
    if active() and HasModelLoaded(hash) then return hash end
    SetModelAsNoLongerNeeded(hash)
end
function W.nearest()
    if W.draft then return end
    local position,found,distance=GetEntityCoords(PlayerPedId()),nil,C.radius
    for id,g in pairs(C.garages) do
        local d=R.distance(position,g.interaction or g.clerk)
        if d<distance then found,distance=id,d end
    end
    return found,distance
end
function W.gateStatus(id,open)
    local i=W.instances[id]
    if not i or not i.gate or not DoesEntityExist(i.gate) then return false,'gate_missing' end
    if not DoorSystemGetIsPhysicsLoaded(i.hash) then return false,'gate_physics_unloaded' end
    local ratio=math.abs(DoorSystemGetOpenRatio(i.hash))
    local ready=open and ratio>0.9 or not open and ratio<0.05
    if ready then return true end
    return false,open and 'gate_not_open' or 'gate_not_closed'
end
function W.gateReady(id,open) return W.gateStatus(id,open) end
function W.react(id,kind)
    local i=W.instances[id]
    if i and i.ped and DoesEntityExist(i.ped) then exports.rp_core:rpReactNpc(i.ped,kind) end
end
local function destroy(i)
    i.alive=false
    if i.ped then exports.rp_core:rpReleasePed(i.ped) if DoesEntityExist(i.ped) then DeleteEntity(i.ped) end end
    if i.registered then
        if DoorSystemGetIsPhysicsLoaded(i.hash) then
            DoorSystemSetDoorState(i.hash,i.previousState or 0,false,true)
            DoorSystemSetOpenRatio(i.hash,i.previousRatio or 0.0,false,true)
        end
        if i.ownsDoor then RemoveDoorFromSystem(i.hash) end
    end
    if i.blip then RemoveBlip(i.blip) end
end
function W.footHeight(ped)
    local root=GetEntityCoords(ped)
    local left=GetPedBoneCoords(ped,0x3779,0.0,0.0,0.0)
    local right=GetPedBoneCoords(ped,0xCC4D,0.0,0.0,0.0)
    local feet=math.min(left.z,right.z)-0.06
    local height=root.z-feet
    if height>=0.3 and height<=1.8 then return height,feet end
end
function W.playerFloor(active)
    local ped=PlayerPedId() local p=GetEntityCoords(ped)
    local _,feet=W.footHeight(ped) if not feet then return end
    local top,deadline=p.z+0.5,GetGameTimer()+1000
    for _=1,4 do
        local ray=StartShapeTestRay(p.x,p.y,top,p.x,p.y,feet-0.4,17,ped,7)
        local state,hit,point,normal
        repeat state,hit,point,normal=GetShapeTestResult(ray) if state==1 then Wait(25) end
        until state~=1 or not active() or GetGameTimer()>=deadline
        if not active() or PlayerPedId()~=ped or R.distance(GetEntityCoords(ped),p)>0.35 then return end
        if state~=2 or (hit~=1 and hit~=true) or GetGameTimer()>=deadline then return end
        if point.z<=feet+0.15 and point.z>=feet-0.4 and normal.z>0.5 then return {x=p.x,y=p.y,z=point.z,h=GetEntityHeading(ped)} end
        top=point.z-0.05 if top<feet-0.4 then return end
    end
end
local function clerk(i,g)
    i.loading=true
    CreateThread(function()
        local model=loadModel(g.clerk.model,function() return i.alive and not W.stopped end)
        i.loading=false if not model then return end
        local p=g.clerk local ped=CreatePed(4,model,p.x,p.y,p.z+1.0,p.h,false,false)
        SetModelAsNoLongerNeeded(model) if ped==0 then return end
        i.ped=ped
        if not exports.rp_core:rpProtectPed(ped) then DeleteEntity(ped) i.ped=nil return end
        SetEntityInvincible(ped,true) SetBlockingOfNonTemporaryEvents(ped,true)
        SetPedCanRagdoll(ped,false) FreezeEntityPosition(ped,true)
        TaskStartScenarioInPlace(ped,p.scenario or 'WORLD_HUMAN_CLIPBOARD',0,false)
        exports.rp_core:rpConfigureNpc(ped,{profile='shop',key='garage:'..i.id,paused=W.draft~=nil})
        local deadline,previous,stable=GetGameTimer()+1000,nil,0
        repeat
            Wait(50) if not i.alive or not DoesEntityExist(ped) then return end
            local height=W.footHeight(ped)
            if height then
                stable=previous and math.abs(height-previous)<0.005 and stable+1 or 0 previous=height
                SetEntityCoordsNoOffset(ped,p.x,p.y,p.z+height,false,false,false)
            end
        until stable>=2 or GetGameTimer()>deadline
    end)
end
local function instance(id,g)
    local i={id=id,config=g,alive=true,hash=joaat('rp_vehicles:gate:'..id)}
    if g.blip then
        local b=AddBlipForCoord(g.interaction.x,g.interaction.y,g.interaction.z)
        SetBlipSprite(b,g.blip.sprite) SetBlipColour(b,g.blip.color) SetBlipScale(b,0.7) SetBlipAsShortRange(b,true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(g.label) EndTextCommandSetBlipName(b) i.blip=b
    end
    W.instances[id]=i return i
end
function W.setDraft(g)
    W.draft=g and R.copy(g) or nil W.testOpen=false
    for id,i in pairs(W.instances) do
        if id=='draft' or (g and id==g.id) or i.draft then destroy(i) W.instances[id]=nil
        elseif i.ped then exports.rp_core:rpConfigureNpc(i.ped,{paused=g~=nil}) end
    end
end
function W.install(rows)
    if type(rows)~='table' or #rows>C.editor.maxGarages then return false end
    local nextRows={}
    for _,raw in ipairs(rows) do
        local g=R.definition(raw)
        if not g or type(raw.id)~='string' or #raw.id>48 then return false end
        g.id,g.revision=raw.id,raw.revision nextRows[g.id]=g
    end
    for id,i in pairs(W.instances) do
        if not nextRows[id] or not C.garages[id] or nextRows[id].revision~=C.garages[id].revision then destroy(i) W.instances[id]=nil end
    end
    C.garages=nextRows
    return true
end
local refreshing,queued,epoch,nextRetry=false,false,0,0
function W.refresh()
    if W.stopped or not ESX.IsPlayerLoaded() then return end
    if refreshing then queued=true return end
    refreshing,queued=true,false
    local ticket=epoch
    CreateThread(function()
        for _=1,4 do
            local ok,result=pcall(lib.callback.await,'rp_vehicles:locations',false)
            if W.stopped or ticket~=epoch or not ESX.IsPlayerLoaded() then break end
            if ok and type(result)=='table' and result.ok and W.install(result.garages) then
                W.received,W.error=true,nil break
            end
            W.error=ok and 'catalog_unavailable' or 'transport_error'
            Wait(1200)
        end
        refreshing=false
        nextRetry=GetGameTimer()+5000
        -- A bucket/catalog change arriving during an await must not be lost.
        if queued then W.refresh() end
    end)
end
RegisterNetEvent('rp_vehicles:locationsChanged',function() if source==65535 then W.refresh() end end)
RegisterNetEvent('esx:playerLoaded',function() if source==65535 then W.refresh() end end)
local function clearCatalog()
    epoch=epoch+1 queued=false W.received,W.error=false,nil
    W.setDraft(nil) W.install({})
end
RegisterNetEvent('esx:onPlayerLogout',function() if source==65535 then clearCatalog() end end)
RegisterCommand('rp_garage_status',function()
    local count=0 for _ in pairs(C.garages) do count=count+1 end
    print(('[rp_vehicles] loaded=%s catalog=%s garages=%d nearest=%s error=%s')
        :format(tostring(ESX.IsPlayerLoaded()),W.received and 'ready' or 'waiting',count,tostring(W.nearest()),W.error or '-'))
end,false)
CreateThread(function()
    local wasLoaded=false
    while not W.stopped do
        local loaded=ESX.IsPlayerLoaded()
        if loaded and not wasLoaded then W.refresh()
        elseif not loaded and wasLoaded then clearCatalog()
        elseif loaded and not refreshing and (not W.received or W.error) and GetGameTimer()>=nextRetry then W.refresh() end
        wasLoaded=loaded
        local position=GetEntityCoords(PlayerPedId())
        local visible={} for id,g in pairs(C.garages) do visible[id]=g end
        if W.draft then visible[W.draft.id or 'draft']=W.draft end
        for id,g in pairs(visible) do
            local i=W.instances[id] or instance(id,g)
            i.draft=W.draft and (W.draft.id or 'draft')==id or false
            if R.distance(position,g.interaction)<C.streamDistance then
                if not i.ped and not i.loading then clerk(i,g) end
                if not i.gate or not DoesEntityExist(i.gate) then
                    local d=g.gate local hash=modelHash(d.model)
                    local entity=GetClosestObjectOfType(d.x,d.y,d.z,3.0,hash,false,false,false)
                    if entity~=0 then
                        i.gate=entity local p=GetEntityCoords(entity)
                        -- Register the actual map object's origin, not an approximate editor point.
                        local found,existing=DoorSystemFindExistingDoor(p.x,p.y,p.z,hash)
                        if found then
                            i.hash=existing i.previousState=DoorSystemGetDoorState(existing) i.previousRatio=DoorSystemGetOpenRatio(existing)
                        elseif not IsDoorRegisteredWithSystem(i.hash) then
                            AddDoorToSystem(i.hash,hash,p.x,p.y,p.z,false,false,true) i.ownsDoor=true
                        end
                        i.registered=true i.open=nil
                        DoorSystemSetAutomaticDistance(i.hash,0.0,false,true) DoorSystemSetAutomaticRate(i.hash,0.8,false,true)
                    end
                end
                -- GTA ignores commands until the door's physics exists. Do not cache them early.
                if i.gate and DoorSystemGetIsPhysicsLoaded(i.hash) then
                    local open=i.draft and W.testOpen==true or not i.draft and GlobalState['rp_vehicles:gate:'..id]==true
                    if i.open~=open then
                        DoorSystemSetDoorState(i.hash,0,false,true)
                        DoorSystemSetOpenRatio(i.hash,open and 1.0 or 0.0,false,true) i.open=open
                    end
                    if not open and math.abs(DoorSystemGetOpenRatio(i.hash))<0.05 then DoorSystemSetDoorState(i.hash,1,false,true) end
                end
            elseif i.ped or i.loading or i.gate then destroy(i) W.instances[id]=nil end
        end
        Wait(250)
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end W.stopped=true
    for _,i in pairs(W.instances) do destroy(i) end
end)
