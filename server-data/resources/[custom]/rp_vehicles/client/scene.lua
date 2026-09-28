local C,R=Garage.Config,Garage.Rules
local S={ active=nil }
Garage.Scene=S
local function control(net,active)
    local deadline=GetGameTimer()+6000
    while active() and GetGameTimer()<deadline do
        if NetworkDoesEntityExistWithNetworkId(net) then
            local entity=NetworkGetEntityFromNetworkId(net)
            if DoesEntityExist(entity) then
                NetworkRequestControlOfEntity(entity)
                if NetworkHasControlOfEntity(entity) then return entity end
            end
        end
        Wait(50)
    end
end
local function waitFor(active,predicate,timeout)
    local deadline=GetGameTimer()+(timeout or 20000)
    repeat
        if not active() then return false end
        if predicate() then return true end
        Wait(100)
    until GetGameTimer()>deadline
    return false
end
local function at(entity,point,radius)
    return DoesEntityExist(entity) and R.distance(GetEntityCoords(entity),point)<radius
end
local function drive(ped,vehicle,point,active,parking)
    if GetPedInVehicleSeat(vehicle,-1)~=ped then return false,'driver_not_seated' end
    if not IsVehicleDriveable(vehicle,false) then return false,'vehicle_not_driveable' end
    local origin,forward=GetEntityCoords(vehicle),GetEntityForwardVector(vehicle)
    local dx,dy=point.x-origin.x,point.y-origin.y
    -- Garage waypoints are off the road network. Follow each short segment
    -- directly; reverse for a point behind the car instead of attempting a U-turn.
    local style=C.drivingStyle | 16777216
    if dx*forward.x+dy*forward.y < -math.sqrt(dx*dx+dy*dy)*0.5 then style=style | 1024 end
    local function issue()
        SetVehicleHandbrake(vehicle,false)
        SetVehicleEngineOn(vehicle,true,true,false)
        TaskVehicleDriveToCoord(ped,vehicle,point.x,point.y,point.z,C.speed,0,GetEntityModel(vehicle),style,0.75,1.0)
        SetPedKeepTask(ped,true)
    end
    local deadline,progress,retries=GetGameTimer()+20000,GetGameTimer(),0
    local best=R.distance(origin,point)
    issue()
    while active() and GetGameTimer()<deadline do
        if not DoesEntityExist(ped) or IsEntityDead(ped) then return false,'valet_dead' end
        if not DoesEntityExist(vehicle) then return false,'vehicle_missing' end
        if not NetworkHasControlOfEntity(ped) or not NetworkHasControlOfEntity(vehicle) then return false,'entity_control_lost' end
        if GetPedInVehicleSeat(vehicle,-1)~=ped then return false,'driver_not_seated' end
        local distance=R.distance(GetEntityCoords(vehicle),point)
        if distance<(parking and 1.6 or 2.0) then return true end
        if distance<best-0.25 then best,progress=distance,GetGameTimer() end
        if GetGameTimer()-progress>3000 and retries<2 then
            retries,progress=retries+1,GetGameTimer() issue()
        end
        Wait(100)
    end
    return false,active() and 'drive_timeout' or 'cancelled'
end
local function perform(data,active)
    local g=C.garages[data.garage]
    if data.action=='prepare' then
        S.garage=data.garage
        RequestCollisionAtCoord(g.hidden.x,g.hidden.y,g.hidden.z)
        local ok=waitFor(active,function() return Garage.World.gateReady(data.garage,false) end,12000)
        local _,reason=Garage.World.gateStatus(data.garage,false)
        return ok,reason
    end
    if data.action=='gate_open' or data.action=='gate_closed' then
        local ok=waitFor(active,function() return Garage.World.gateReady(data.garage,data.action=='gate_open') end,12000)
        local _,reason=Garage.World.gateStatus(data.garage,data.action=='gate_open')
        return ok,reason
    end
    local ped=control(data.ped,active)
    local vehicle=control(data.vehicle,active)
    if not ped or not vehicle then return false,'entity_control_timeout' end
    S.ped,S.vehicle=ped,vehicle
    SetBlockingOfNonTemporaryEvents(ped,true)
    if IsEntityDead(ped) then return false,'valet_dead' end
    SetPedCanRagdoll(ped,true)
    SetEntityInvincible(ped,false)
    SetEntityCanBeDamaged(ped,true)
    SetPedFleeAttributes(ped,0,false)
    SetPedKeepTask(ped,true)
    SetDriverAbility(ped,1.0)
    SetDriverAggressiveness(ped,0.0)
    SetPedCanBeDraggedOut(ped,true)
    local point=data.point
    if data.action=='handover' or data.action=='collect' then
        TaskLookAtEntity(ped,PlayerPedId(),2000,2048,3)
        local dict='gestures@m@standing@casual'
        RequestAnimDict(dict)
        waitFor(active,function() return HasAnimDictLoaded(dict) end,1500)
        if not active() then RemoveAnimDict(dict) return false,'cancelled' end
        if HasAnimDictLoaded(dict) then TaskPlayAnim(ped,dict,'gesture_nod_yes_soft',2.0,-2.0,1600,48,0.0,false,false,false) end
        PlayPedAmbientSpeechNative(ped,data.action=='handover' and 'GENERIC_BYE' or 'GENERIC_THANKS','SPEECH_PARAMS_STANDARD')
        local untilTime=GetGameTimer()+1700
        waitFor(active,function() return GetGameTimer()>=untilTime end,2000)
        if DoesEntityExist(ped) then StopAnimTask(ped,dict,'gesture_nod_yes_soft',2.0) TaskClearLookAt(ped) end
        RemoveAnimDict(dict) return active()
    elseif data.action=='seat' then
        -- The ONLY warp occurs inside the closed garage, before the gate opens.
        TaskWarpPedIntoVehicle(ped,vehicle,-1)
        local seated=waitFor(active,function() return GetPedInVehicleSeat(vehicle,-1)==ped end,4000)
        if seated and active() then SetVehicleEngineOn(vehicle,true,true,false) end
        return seated
    elseif data.action=='enter' then
        SetVehicleDoorsLocked(vehicle,1)
        TaskEnterVehicle(ped,vehicle,18000,-1,1.5,1,0)
        local entered=waitFor(active,function() return GetPedInVehicleSeat(vehicle,-1)==ped end)
        if entered then SetVehicleDoorsLocked(vehicle,2) SetVehicleEngineOn(vehicle,true,true,false) end
        return entered
    elseif data.action=='drive' or data.action=='park' then
        local arrived,reason=drive(ped,vehicle,point,active,data.action=='park')
        if not arrived then return false,reason end
        if data.action=='park' then
            TaskVehiclePark(ped,vehicle,point.x,point.y,point.z,point.h or 0.0,1,20.0,false)
            if not waitFor(active,function()
                local angle=math.abs(((GetEntityHeading(vehicle)-(point.h or 0.0)+180.0)%360.0)-180.0)
                return at(vehicle,point,1.8) and GetEntitySpeed(vehicle)<0.6 and (angle<20.0 or angle>160.0)
            end,10000) then return false end
            TaskVehicleTempAction(ped,vehicle,27,1500)
            if not waitFor(active,function() return GetEntitySpeed(vehicle)<0.4 end,2500) then return false end
            SetVehicleHandbrake(vehicle,true)
            SetVehicleEngineOn(vehicle,false,true,false)
        end
        return true
    elseif data.action=='exit' then
        TaskLeaveVehicle(ped,vehicle,0)
        return waitFor(active,function() return not IsPedInAnyVehicle(ped,false) end,10000)
    elseif data.action=='walk' then
        TaskFollowNavMeshToCoord(ped,point.x,point.y,point.z,2.0,20000,0.6,false,point.h or 0.0)
        return waitFor(active,function() return at(ped,point,1.3) end)
    end
    return false
end
RegisterNetEvent('rp_vehicles:step',function(data)
    if source~=65535 or type(data)~='table' or not C.garages[data.garage] then return end
    if S.active and S.active~=data.token then return end
    if S.active==data.token and S.step and data.step<=S.step then return end
    S.active,S.step=data.token,data.step
    local ticket={}
    S.ticket=ticket
    CreateThread(function()
        local function active()
            return S.ticket==ticket and S.active==data.token and not IsEntityDead(PlayerPedId())
        end
        local ok,result,reason=pcall(perform,data,active)
        if not ok then print(('[rp_vehicles] %s step=%s error: %s'):format(data.garage,data.action,tostring(result))) reason='native_error' end
        if ok and not result and not reason then reason=data.action..'_timeout' end
        if S.ticket==ticket then TriggerServerEvent('rp_vehicles:ack',data.token,data.step,ok and result==true,reason) end
    end)
end)
local function clear()
    S.active,S.ticket,S.step=nil,nil,nil
    if S.ped and DoesEntityExist(S.ped) and not IsEntityDead(S.ped) and NetworkHasControlOfEntity(S.ped) then ClearPedTasks(S.ped) end
    if S.vehicle and DoesEntityExist(S.vehicle) and NetworkHasControlOfEntity(S.vehicle) then
        SetVehicleHandbrake(S.vehicle,false)
    end
    S.ped,S.vehicle,S.garage=nil,nil,nil
end
local errors={gate_missing='Das konfigurierte Tor wurde nicht gefunden. /rp_garage_dev → Tor anvisieren.',
    gate_physics_unloaded='Die Torphysik wurde nicht geladen.',gate_not_closed='Das Tor schließt nicht. Andere Torsteuerungen prüfen.',
    gate_not_open='Das Tor öffnet nicht.',entity_control_timeout='Fahrer oder Fahrzeug konnten nicht übernommen werden.',
    drive_timeout='Der Fahrweg ist blockiert oder nicht befahrbar.',park_timeout='Der Fahrer erreicht den Parkplatz nicht.',walk_timeout='Der Fußweg ist blockiert.',
    valet_dead='Der Fahrer ist gestorben. Der Parkservice wurde abgebrochen; dein Fahrzeug bleibt ausgeparkt.',
    driver_not_seated='Der Fahrer sitzt nicht mehr am Steuer. Der Parkservice wurde abgebrochen.',
    vehicle_not_driveable='Das Fahrzeug ist nicht fahrbereit.',entity_control_lost='Die Fahrzeugsteuerung wurde unterbrochen.'}
RegisterNetEvent('rp_vehicles:finish',function(ticket,ok,message,reason)
    if source~=65535 or (S.active and S.active~=ticket) then return end
    if ok and S.garage then Garage.World.react(S.garage,'farewell') end
    clear()
    local code=type(reason)=='string' and reason:match('^([^:]+)')
    lib.notify({title='Parkservice',description=ok and message or errors[code] or 'Der Parkservice wurde unterbrochen. Bitte den Übergabeplatz und Zufahrtsweg freihalten.',type=ok and 'success' or 'error'})
end)
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then clear() end end)
