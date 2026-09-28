local ESX = exports.es_extended:getSharedObject()
local C, R = Garage.Config, Garage.Rules
local busy, actors, epochs, rates, vehicles, plateLocks = {}, {}, {}, {}, {}, {}
local recoveries,corpses={},{}
local serial, ready, stopping = 0, false, false
Garage.Service={busy=function(id) return busy[id]~=nil or recoveries[id]~=nil end}
local function locationReady(id)
    return not Garage.Locations or (Garage.Locations.ready and not Garage.Locations.editing[id] and not Garage.Locations.reserved[id])
end
local function token()
    serial = serial + 1
    return ('garage_%x_%x_%x'):format(GetGameTimer(), math.random(0, 0x7fffffff), serial)
end
local function rate(source)
    local now = GetGameTimer()
    if (rates[source] or 0) > now then return false end
    rates[source] = now + 1000
    return true
end
local function exists(entity) return entity and entity ~= 0 and DoesEntityExist(entity) end
local function current(op)
    local player = ESX.GetPlayerFromId(op.source)
    return not stopping and not op.cancelled and player and player.identifier == op.owner
        and (epochs[op.source] or 0) == op.epoch and player
end
local function near(source, garage, radius)
    local ped = GetPlayerPed(source)
    return exists(ped) and GetEntityHealth(ped) > 0 and GetPlayerRoutingBucket(source) == garage.bucket
        and R.distance(GetEntityCoords(ped), garage.interaction or garage.clerk) <= (radius or C.radius + 1.0)
end
local function occupied(vehicle, allowedPed)
    -- Bounded seat checks, never a scan of all (potentially 2,000) players per scene tick.
    for seat = -1, 31 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and ped ~= allowedPed then return true end
    end
    return false
end
local function clearSpace(point, except)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if vehicle ~= except and R.distance(GetEntityCoords(vehicle), point) < 4.0 then return false end
    end
    return true
end
local function mark(op, phase)
    op.phase = phase
    MySQL.update.await('UPDATE rp_vehicle_garage_operations SET phase=? WHERE token=?', { phase, op.token })
end
local function gate(op, open)
    if open then op.closedConfirmed=false end
    GlobalState['rp_vehicles:gate:' .. op.garage] = open
end
local function deleteConfirmed(entity)
    if not exists(entity) then return true end
    DeleteEntity(entity)
    local untilTime = GetGameTimer() + 2500
    while exists(entity) and GetGameTimer() < untilTime do Wait(50) end
    return not exists(entity)
end
local function vehicleValid(op)
    local record = vehicles[op.plate]
    if not record or record.entity ~= op.vehicle or record.owner ~= op.owner then return false,'vehicle_unregistered' end
    if not exists(op.vehicle) then return false,'vehicle_missing' end
    if GetEntityModel(op.vehicle) ~= record.model then return false,'vehicle_model_mismatch' end
    if GetEntityRoutingBucket(op.vehicle) ~= op.config.bucket then return false,'vehicle_bucket_mismatch' end
    if R.plate(GetVehicleNumberPlateText(op.vehicle)) ~= op.plate then return false,'vehicle_plate_mismatch' end
    return true
end
local function assertSession(op)
    assert(current(op) and near(op.source, op.config, 90.0), 'session_ended')
    assert(GetGameTimer() < op.deadline, 'timeout')
end
local function assertVehicleLive(op)
    assertSession(op)
    if op.vehicle then
        local valid,reason=vehicleValid(op)
        assert(valid,reason)
        assert(not occupied(op.vehicle,op.ped), 'vehicle_occupied')
    end
end
local function assertValetIdentity(op)
    assert(exists(op.ped), 'valet_missing')
    assert(GetEntityType(op.ped)==1 and GetEntityModel(op.ped)==op.pedModel, 'valet_model_mismatch')
    assert(GetEntityRoutingBucket(op.ped)==op.config.bucket, 'valet_bucket_mismatch')
end
local function assertLive(op)
    assertVehicleLive(op)
    if op.ped then
        assertValetIdentity(op)
        if GetEntityHealth(op.ped)<=0 then op.failed='valet_dead' error('valet_dead') end
    end
end
local function waitForSpawnSync(op)
    local deadline,nextPublish=GetGameTimer()+C.spawnSyncTimeout,GetGameTimer()+1000
    while true do
        assertSession(op)
        local valid,reason=vehicleValid(op)
        -- Only the initial asynchronous plate projection may lag. The registered
        -- entity, model, bucket and vacant seats remain mandatory throughout.
        assert(valid or reason=='vehicle_plate_mismatch',reason)
        assert(not occupied(op.vehicle), 'vehicle_occupied')
        if valid then return end
        local now=GetGameTimer()
        assert(now<deadline,'vehicle_plate_sync_timeout')
        if now>=nextPublish then
            -- ESX's standard handler only applies properties on the owning client.
            -- Re-publish if its first statebag callback preceded network ownership.
            -- Identical state values are not replicated by Cfx; ESX safely ignores nil.
            local state=Entity(op.vehicle).state
            state:set('VehicleProperties',nil,true)
            state:set('VehicleProperties',op.properties,true)
            nextPublish=now+1000
        end
        Wait(100)
    end
end
local function step(op, action, point, predicate, minimum)
    assertLive(op)
    op.step = (op.step or 0) + 1
    op.action=action
    op.ack = nil
    TriggerClientEvent('rp_vehicles:step', op.source, {
        token=op.token, step=op.step, garage=op.garage, action=action, point=point,
        direction=op.direction, config=action=='prepare' and op.config or nil,
        vehicle=op.vehicle and NetworkGetNetworkIdFromEntity(op.vehicle),
        ped=op.ped and NetworkGetNetworkIdFromEntity(op.ped),
    })
    local start, deadline = GetGameTimer(), GetGameTimer() + C.stageTimeout
    repeat
        Wait(200)
        assertLive(op)
        assert(not op.failed, op.failed or 'scene_failed')
        assert(GetGameTimer() < deadline, 'stage_timeout:'..action)
    until op.ack == op.step and GetGameTimer() - start >= (minimum or 0) and (not predicate or predicate())
    if action=='prepare' or action=='gate_closed' then op.closedConfirmed=true end
end
local function at(entity, point, radius)
    return exists(entity) and R.distance(GetEntityCoords(entity), point) <= radius
end
local function move(op, point, park)
    step(op, park and 'park' or 'drive', point, function()
        return at(op.vehicle, point, park and 2.0 or 2.8)
            and GetPedInVehicleSeat(op.vehicle, -1) == op.ped
            and (not park or GetEntitySpeed(op.vehicle) < 0.6)
    end, 500)
end
local function walk(op, point)
    step(op, 'walk', point, function() return at(op.ped, point, 1.8) and GetVehiclePedIsIn(op.ped, false) == 0 end, 300)
end
local function spawnValet(op, point)
    assertLive(op)
    op.pedModel=joaat(op.config.valetModel)
    local ped = CreatePed(4, op.pedModel, point.x, point.y, point.z + 1.0, point.h or 0.0, true, true)
    assert(exists(ped), 'ped_spawn_failed')
    op.ped = ped
    SetEntityRoutingBucket(ped, op.config.bucket)
    SetEntityOrphanMode(ped, 2)
    assert(exports.rp_core:rpProtectNetworkPed(ped), 'ped_protection_failed')
    -- CreatePed registers a server entity before an owning client sends PedHealth.
    -- Register protection first, then wait for that initial sync without reviving
    -- the ped or bypassing identity, vehicle, character and distance checks.
    local deadline=GetGameTimer()+C.pedSyncTimeout
    while true do
        assertVehicleLive(op)
        assertValetIdentity(op)
        if GetEntityHealth(ped)>0 then op.valetReady=true return end
        assert(GetGameTimer()<deadline, 'valet_sync_timeout')
        Wait(100)
    end
end
local function storeRow(op)
    -- Never write stored=true while a live vehicle still exists.
    assert(not exists(op.vehicle), 'vehicle_still_exists')
    local changed = MySQL.update.await([[UPDATE owned_vehicles SET stored=1, parking=?, vehicle=?
        WHERE plate=? AND owner=? AND stored=0 AND (pound IS NULL OR pound='')]],
        { op.garage, json.encode(op.properties), op.plate, op.owner })
    assert(changed == 1, 'store_conflict')
    vehicles[op.plate] = nil
    op.committed = true
    mark(op, 'complete')
end
local function run(op)
    local g = op.config
    -- Closed door + loaded collision acknowledged BEFORE spawning the actual car.
    step(op, 'prepare', nil, nil, 500)
    assertLive(op)
    if op.direction == 'out' then
        assert(clearSpace(g.hidden) and clearSpace(g.parking), 'parking_blocked')
        -- Reserve through the standard ESX stored flag BEFORE the yielding spawn.
        local changed = MySQL.update.await([[UPDATE owned_vehicles SET stored=0 WHERE plate=? AND owner=?
            AND stored=1 AND (parking IS NULL OR parking='' OR parking=?) AND (pound IS NULL OR pound='')]],
            { op.plate, op.owner, op.garage })
        assert(changed == 1, 'already_outside')
        op.reserved = true
        assertLive(op)
        op.spawnAttempted = true
        local net = ESX.OneSync.SpawnVehicle(op.properties.model, vector3(g.hidden.x,g.hidden.y,g.hidden.z),
            g.hidden.h, op.properties, nil, 'automobile')
        op.vehicle = net and NetworkGetEntityFromNetworkId(net)
        assert(exists(op.vehicle), 'vehicle_spawn_failed')
        SetEntityRoutingBucket(op.vehicle, g.bucket)
        SetVehicleNumberPlateText(op.vehicle, op.plate)
        Entity(op.vehicle).state:set('owner',op.owner,false)
        Entity(op.vehicle).state:set('plate',op.plate,false)
        vehicles[op.plate] = { entity=op.vehicle, owner=op.owner, model=GetEntityModel(op.vehicle) }
        TriggerClientEvent('rp_vehicles:deliveryBlip',op.source,op.token,net,op.plate)
        SetVehicleDoorsLocked(op.vehicle, 2)
        mark(op, 'spawned')
        waitForSpawnSync(op)
        spawnValet(op, g.staffDoor)
        step(op, 'seat', nil, function() return GetPedInVehicleSeat(op.vehicle,-1) == op.ped end)
        gate(op, true)
        step(op, 'gate_open', nil, nil, C.gateTime)
        for _, point in ipairs(g.outward) do move(op, point, false) end
        move(op, g.parking, true)
        step(op, 'exit', nil, function() return GetVehiclePedIsIn(op.ped,false) == 0 end, 500)
        step(op,'handover',nil,nil,1000)
        for i = #g.staffPath, 1, -1 do walk(op, g.staffPath[i]) end
        walk(op, { x=g.staffDoor.x,y=g.staffDoor.y,z=g.staffDoor.z+1.0 })
        gate(op, false)
        step(op, 'gate_closed', nil, nil, C.gateTime)
        assert(deleteConfirmed(op.ped), 'ped_delete_failed')
        exports.rp_core:rpReleaseNetworkPed(op.ped)
        op.ped = nil
        SetVehicleDoorsLocked(op.vehicle, 1)
        op.delivered = true
        mark(op, 'complete')
    else
        assert(vehicleValid(op) and at(op.vehicle,g.parking,4.0) and not occupied(op.vehicle), 'park_at_handover')
        SetVehicleDoorsLocked(op.vehicle, 2)
        spawnValet(op, g.staffDoor)
        gate(op, true)
        step(op, 'gate_open', nil, nil, C.gateTime)
        for _, point in ipairs(g.staffPath) do walk(op, point) end
        step(op,'collect',nil,nil,1000)
        step(op, 'enter', nil, function() return GetPedInVehicleSeat(op.vehicle,-1) == op.ped end, 700)
        for _, point in ipairs(g.inward) do move(op, point, false) end
        move(op, g.hidden, true)
        gate(op, false)
        step(op, 'gate_closed', nil, nil, C.gateTime)
        assertLive(op)
        mark(op, 'deleting')
        assertLive(op) -- a death/logout during the journal await still aborts storage
        assert(deleteConfirmed(op.ped), 'ped_delete_failed')
        exports.rp_core:rpReleaseNetworkPed(op.ped)
        op.ped = nil
        assert(deleteConfirmed(op.vehicle), 'vehicle_delete_failed')
        mark(op, 'deleted')
        storeRow(op)
    end
end
local function retireValet(op)
    local ped=op.ped
    if not ped then return end
    if op.valetReady and exists(ped) and GetEntityModel(ped)==op.pedModel and GetEntityHealth(ped)<=0 then
        op.failed='valet_dead'
        local record={model=op.pedModel,net=NetworkGetNetworkIdFromEntity(ped)}
        corpses[ped]=record
        CreateThread(function()
            Wait(C.deadValetLifetime)
            if corpses[ped]~=record then return end
            if exists(ped) and GetEntityModel(ped)==record.model and NetworkGetNetworkIdFromEntity(ped)==record.net then deleteConfirmed(ped) end
            exports.rp_core:rpReleaseNetworkPed(ped)
            corpses[ped]=nil
        end)
    else
        if exists(ped) then deleteConfirmed(ped) end
        exports.rp_core:rpReleaseNetworkPed(ped)
    end
end
local function allowVehicleRecovery(op)
    if not vehicleValid(op) or R.outsideGate(op.config,GetEntityCoords(op.vehicle),C.gateClearance) then return end
    local record={vehicle=op.vehicle,model=GetEntityModel(op.vehicle),net=NetworkGetNetworkIdFromEntity(op.vehicle)}
    recoveries[op.garage]=record
    gate(op,true)
    CreateThread(function()
        while not stopping and recoveries[op.garage]==record do
            Wait(1000)
            if not exists(record.vehicle) or GetEntityModel(record.vehicle)~=record.model
                or NetworkGetNetworkIdFromEntity(record.vehicle)~=record.net
                or GetEntityRoutingBucket(record.vehicle)~=op.config.bucket
                or R.outsideGate(op.config,GetEntityCoords(record.vehicle),C.gateClearance) then break end
        end
        if recoveries[op.garage]==record then
            recoveries[op.garage]=nil
            GlobalState['rp_vehicles:gate:'..op.garage]=false
        end
    end)
end
local function finish(op, success, err)
    -- Failure never teleports an exposed car or returns an existing one to storage.
    gate(op, false)
    retireValet(op)
    if not success then
        if exists(op.vehicle) then SetVehicleDoorsLocked(op.vehicle,1) end
        if not op.valetReady and op.reserved and not op.delivered and op.closedConfirmed and exists(op.vehicle) and at(op.vehicle,op.config.hidden,3.0)
            and not occupied(op.vehicle) then
            -- Concealed rollback only; close the physical gate first.
            Wait(C.gateTime)
            if at(op.vehicle,op.config.hidden,3.0) and not occupied(op.vehicle) then deleteConfirmed(op.vehicle) end
        end
        if not op.valetReady and op.reserved and not exists(op.vehicle) and (not op.spawnAttempted or op.vehicle) then
            MySQL.update.await('UPDATE owned_vehicles SET stored=1 WHERE plate=? AND owner=? AND stored=0', {op.plate,op.owner})
            vehicles[op.plate] = nil
        end
        if op.valetReady and exists(op.vehicle) then allowVehicleRecovery(op) end
        mark(op, op.committed and 'complete' or 'interrupted')
        print(('[rp_vehicles] %s %s interrupted: %s'):format(op.garage,op.plate,tostring(err)))
    end
    if (epochs[op.source] or 0)==op.epoch then
        local retained=not success and op.valetReady==true and vehicleValid(op)==true
        if retained then TriggerClientEvent('rp_vehicles:deliveryBlip',op.source,op.token,NetworkGetNetworkIdFromEntity(op.vehicle),op.plate) end
        TriggerClientEvent('rp_vehicles:finish',op.source,op.token,success,
            op.direction == 'out' and 'Dein Fahrzeug steht zur Abholung bereit.' or 'Dein Fahrzeug ist sicher eingeparkt.',op.failed,retained)
    end
    if actors[op.source] == op then actors[op.source] = nil end
    if busy[op.garage] == op then busy[op.garage] = nil end
    if plateLocks[op.plate] == op then plateLocks[op.plate] = nil end
end
local function start(source, garageId, direction, plate, observed)
    local player, g = ESX.GetPlayerFromId(source), type(garageId)=='string' and C.garages[garageId]
    plate = R.plate(plate)
    if not ready or not locationReady(garageId) or not player or not g or not plate or (direction~='in' and direction~='out')
        or not rate(source) or not near(source,g) then return {ok=false,error='unavailable'} end
    if recoveries[garageId] then return {ok=false,error='recovery_vehicle'} end
    if busy[garageId] or actors[source] or plateLocks[plate] then return {ok=false,error='busy'} end
    local op = {source=source,owner=player.identifier,epoch=epochs[source] or 0,config=g,garage=garageId,
        plate=plate,direction=direction,token=token(),deadline=GetGameTimer()+C.operationTimeout}
    busy[garageId],actors[source],plateLocks[plate] = op,op,op
    local ok, err = pcall(function()
        local row = MySQL.single.await('SELECT * FROM owned_vehicles WHERE owner=? AND plate=?', {op.owner,plate})
        assert(current(op) and near(source,g), 'session_ended')
        assert(row and row.type=='car' and (not row.job or row.job=='') and (not row.pound or row.pound==''), 'not_owned')
        op.properties = json.decode(row.vehicle or '{}')
        assert(type(op.properties)=='table' and (type(op.properties.model)=='number' or type(op.properties.model)=='string'), 'invalid_vehicle')
        op.properties.plate = plate
        if direction=='out' then
            assert(R.available(row,op.owner,garageId), 'not_stored_here')
            assert(not vehicles[plate] or not exists(vehicles[plate].entity), 'already_outside')
            for _, entity in ipairs(GetAllVehicles()) do
                assert(R.plate(GetVehicleNumberPlateText(entity))~=plate, 'plate_already_present')
            end
        else
            op.vehicle = vehicles[plate] and vehicles[plate].entity
            assert(tonumber(row.stored)==0 and vehicleValid(op) and at(op.vehicle,g.parking,4.0)
                and not occupied(op.vehicle) and GetEntitySpeed(op.vehicle)<0.6, 'park_at_handover')
            op.properties = R.condition(op.properties,observed)
        end
        MySQL.insert.await([[INSERT INTO rp_vehicle_garage_operations (token,owner,plate,garage,direction,phase)
            VALUES (?,?,?,?,?,'preparing')]], {op.token,op.owner,plate,garageId,direction})
    end)
    if not ok then
        busy[garageId],actors[source],plateLocks[plate] = nil,nil,nil
        return {ok=false,error=(tostring(err):match('([^:]+)$') or ''):match('^%s*(.-)%s*$')}
    end
    CreateThread(function()
        Wait(250) -- let the callback reach the caller before sending scene stages
        local success, failure = xpcall(function() run(op) end,debug.traceback)
        local cleaned, cleanupError = pcall(finish,op,success,failure)
        if not cleaned then
            -- Keep the plate locked on ambiguous database failure; never duplicate it.
            gate(op,false)
            if exists(op.ped) then DeleteEntity(op.ped) end
            TriggerClientEvent('rp_vehicles:finish',op.source,op.token,false)
            print('[rp_vehicles] Cleanup requires review: '..tostring(cleanupError))
        end
    end)
    return {ok=true,token=op.token}
end
lib.callback.register('rp_vehicles:start', start)
lib.callback.register('rp_vehicles:list', function(source,id)
    local p,g = ESX.GetPlayerFromId(source), type(id)=='string' and C.garages[id]
    if not ready or not locationReady(id) or not p or not g or not rate(source) or not near(source,g) then return {ok=false} end
    local owner,epoch = p.identifier,epochs[source] or 0
    local rows=MySQL.query.await([[SELECT plate,vehicle,stored,parking,pound FROM owned_vehicles
        WHERE owner=? AND type='car' AND (job IS NULL OR job='') ORDER BY plate LIMIT 150]],{owner})
    p=ESX.GetPlayerFromId(source)
    if not p or p.identifier~=owner or (epochs[source] or 0)~=epoch or not near(source,g) then return {ok=false} end
    local result={}
    for _,row in ipairs(rows) do
        local parsed,props=pcall(json.decode,row.vehicle or '{}')
        if parsed and type(props)=='table' then
            local record=vehicles[row.plate]
            result[#result+1]={plate=row.plate,model=props.model,stored=tonumber(row.stored)==1,
                available=tonumber(row.stored)==1 and (not row.parking or row.parking=='' or row.parking==id) and (not row.pound or row.pound==''),
                canStore=record and record.owner==owner and exists(record.entity) and at(record.entity,g.parking,4.0)
                    and not occupied(record.entity) or false,
                netId=record and exists(record.entity) and NetworkGetNetworkIdFromEntity(record.entity) or nil}
        end
    end
    return {ok=true,vehicles=result,busy=busy[id]~=nil or recoveries[id]~=nil}
end)
RegisterNetEvent('rp_vehicles:ack',function(ticket,index,ok,reason)
    local op=actors[source]
    if not op or type(ticket)~='string' or ticket~=op.token or index~=op.step or type(ok)~='boolean' or op.ack==index then return end
    if ok then op.ack=index else
        -- Client diagnostics are bounded data, never executable code or authority.
        reason=type(reason)=='string' and reason:match('^[a-z_]+$') and #reason<=48 and reason or 'client_scene_failed'
        op.failed=reason..':'..op.action
    end
end)
-- Explicit server-only adapter for dealerships/other trusted vehicle spawners.
exports('rpRegisterOwnedVehicle',function(entity,owner,plate)
    if not GetInvokingResource() or not exists(entity) or GetEntityType(entity)~=2 or type(owner)~='string' then return false end
    plate=R.plate(plate)
    if not plate or plateLocks[plate] or (vehicles[plate] and exists(vehicles[plate].entity) and vehicles[plate].entity~=entity) then return false end
    local row=MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner=? AND plate=? AND stored=0',{owner,plate})
    if not row or not exists(entity) or plateLocks[plate]
        or (vehicles[plate] and exists(vehicles[plate].entity) and vehicles[plate].entity~=entity) then return false end
    local props=json.decode(row.vehicle or '{}')
    local model=type(props.model)=='string' and joaat(props.model) or props.model
    if model~=GetEntityModel(entity) or R.plate(GetVehicleNumberPlateText(entity))~=plate then return false end
    vehicles[plate]={entity=entity,owner=owner,model=model}
    return true
end)
local function leave(id)
    epochs[id]=(epochs[id] or 0)+1
    if actors[id] then actors[id].cancelled=true end
    rates[id]=nil
end
AddEventHandler('playerDropped',function() leave(source) end)
AddEventHandler('esx:playerLogout',leave)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    stopping=true
    for ped,record in pairs(corpses) do
        if exists(ped) and GetEntityModel(ped)==record.model and NetworkGetNetworkIdFromEntity(ped)==record.net then DeleteEntity(ped) end
        exports.rp_core:rpReleaseNetworkPed(ped) corpses[ped]=nil
    end
    for id in pairs(recoveries) do recoveries[id]=nil GlobalState['rp_vehicles:gate:'..id]=false end
    for _,op in pairs(busy) do
        gate(op,false)
        if exists(op.ped) then DeleteEntity(op.ped) end
        if exists(op.vehicle) then SetVehicleDoorsLocked(op.vehicle,1) end
        TriggerClientEvent('rp_vehicles:finish',op.source,op.token,false)
    end
    -- Never reset stored flags during resource shutdown: vehicles may still exist.
end)
MySQL.ready(function()
    CreateThread(function()
        local ok,err=pcall(function()
            MySQL.query.await('SELECT token FROM rp_vehicle_garage_operations LIMIT 1')
            MySQL.query.await('SELECT owner,plate,vehicle,type,job,stored,parking,pound FROM owned_vehicles LIMIT 1')
        end)
        ready=ok
        if not ok then print('[rp_vehicles] Import migrations/001_garage_operations.sql first: '..tostring(err)) end
        for id in pairs(C.garages) do GlobalState['rp_vehicles:gate:'..id]=false end
    end)
end)
ESX.RegisterCommand('rp_garage_test',{'admin','owner'},function(player,_,showError)
    if not ready or not player or not rate(player.source) then return end
    local owner=player.identifier
    local plate=('RP%06d'):format(math.random(0,999999))
    local changed=MySQL.update.await([[INSERT IGNORE INTO owned_vehicles (owner,plate,vehicle,type,stored,parking)
        VALUES (?,?,?,'car',1,'la_mesa')]],{owner,plate,json.encode({model=joaat(C.testModel),plate=plate,fuelLevel=100.0})})
    if changed==1 then player.showNotification('Testfahrzeug '..plate..' wartet in La Mesa.') else showError('Bitte erneut versuchen.') end
end,false,{help='Eigenes ESX-Testfahrzeug in der Garage La Mesa anlegen',validate=true,arguments={}})

ESX.RegisterCommand('rp_garage_recover',{'admin','owner'},function(player,args,showError)
    local plate=R.plate(args.plate)
    if not ready or not player or not plate or not rate(player.source) then return end
    if plateLocks[plate] then showError('Das Fahrzeug hat noch einen laufenden Vorgang.') return end
    local lock={}
    plateLocks[plate]=lock
    local ok,err=pcall(function()
        for _,entity in ipairs(GetAllVehicles()) do
            assert(R.plate(GetVehicleNumberPlateText(entity))~=plate,'Das Fahrzeug existiert noch in der Welt.')
        end
        local changed=MySQL.update.await([[UPDATE owned_vehicles SET stored=1, parking=COALESCE(NULLIF(parking,''),'la_mesa')
            WHERE plate=? AND stored=0 AND type='car' AND (job IS NULL OR job='') AND (pound IS NULL OR pound='')]],{plate})
        assert(changed==1,'Kein wiederherstellbares Fahrzeug mit diesem Kennzeichen.')
        vehicles[plate]=nil
        print(('[rp_vehicles] recovery admin=%d plate=%s (no live entity)'):format(player.source,plate))
    end)
    if plateLocks[plate]==lock then plateLocks[plate]=nil end
    if ok then player.showNotification('Fahrzeug '..plate..' wieder eingelagert.') else showError(tostring(err)) end
end,false,{help='Nach geprüftem Verlust ein Fahrzeug wieder einlagern; vorhandene Fahrzeuge werden abgelehnt',validate=true,
    arguments={{name='plate',help='Kennzeichen',type='string'}}})
