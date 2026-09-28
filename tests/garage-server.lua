-- Runs the actual garage service with deterministic OneSync/SQL boundaries.
local base='server-data/resources/[custom]/rp_vehicles/'
local passed,now,nextEntity=0,0,100
local function check(value,label) assert(value,label) passed=passed+1 end
local callbacks,events,commands,api,threads={}, {}, {}, {}, {}
local entities,rows,journal,notifications={}, {}, {}, {}
local spawnMode,sceneMode,refuseDelete,spawnCount=nil,nil,false,0
local pedMode
local killAt,deathPosition
local protectedActors={}
local pedCount,propertyPublishes=0,0
local nativePrint,lastFailure=print,nil
function print(message)
    if type(message)=='string' and message:find('interrupted:',1,true) then lastFailure=message end
    nativePrint(message)
end
local players={ [1]={identifier='char1:license:a',source=1}, [2]={identifier='char2:license:a',source=2} }
local encoded,serial={},0
local function clone(value)
    if type(value)~='table' then return value end
    local copy={} for k,v in pairs(value) do copy[k]=clone(v) end return copy
end
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
json={encode=function(v) serial=serial+1 encoded[tostring(serial)]=clone(v) return tostring(serial) end,
    decode=function(v) return clone(encoded[v] or {}) end}
function joaat(value) if type(value)=='number' then return value end local hash=0 for i=1,#value do hash=(hash*31+value:byte(i))%2147483647 end return hash end
function vector3(x,y,z) return {x=x,y=y,z=z} end
function GetGameTimer() return now end
function GetCurrentResourceName() return 'rp_vehicles' end
function GetInvokingResource() return 'trusted_dealership' end
function DoesEntityExist(id) return entities[id]~=nil end
function GetEntityType(id) return entities[id].type end
function GetEntityModel(id) return entities[id].model end
function GetEntityCoords(id) return entities[id].pos end
function GetEntityHealth(id) return entities[id].health or 200 end
function GetEntitySpeed(id) return entities[id].speed or 0 end
function GetEntityRoutingBucket(id) return entities[id].bucket or 0 end
function SetEntityRoutingBucket(id,bucket) entities[id].bucket=bucket end
function SetEntityOrphanMode() end
function GetPlayerRoutingBucket(id) return players[id].bucket or 0 end
function GetPlayerPed(id) return tonumber(id) end
function GetPlayers() local ids={} for id in pairs(players) do ids[#ids+1]=tostring(id) end return ids end
function GetVehiclePedIsIn(id) return entities[id] and entities[id].vehicle or 0 end
function GetPedInVehicleSeat(vehicle) for id,e in pairs(entities) do if e.type==1 and e.vehicle==vehicle then return id end end return 0 end
function GetVehicleNumberPlateText(id) return entities[id].plate or '' end
-- Server RPC can precede client ownership and never arrive. ESX's standard
-- VehicleProperties statebag projects the actual plate asynchronously instead.
function SetVehicleNumberPlateText() end
function NetworkGetEntityFromNetworkId(id) return id end
function NetworkGetNetworkIdFromEntity(id) return id end
function GetAllVehicles() local result={} for id,e in pairs(entities) do if e.type==2 then result[#result+1]=id end end return result end
function SetVehicleDoorsLocked(id,lock) entities[id].lock=lock end
function DeleteEntity(id) if not (refuseDelete and entities[id] and entities[id].type==2) then entities[id]=nil end end
function Entity(id) return {state={set=function(_,k,v)
    local e=entities[id] e.state=e.state or {}
    if same(e.state[k],v) then return end -- Cfx does not replicate identical values
    e.state[k]=clone(v)
    if k~='VehicleProperties' or not v then return end -- state.plate is NOT the GTA plate
    propertyPublishes=propertyPublishes+1 e.publishes=(e.publishes or 0)+1
    if e.spawnMode=='plate_timeout' or (e.spawnMode=='late_owner' and e.publishes==1) then return end
    CreateThread(function()
        Wait(1200)
        if entities[id]==e then e.plate=v.plate end
    end)
end}} end
function CreatePed(_,model,x,y,z)
    pedCount=pedCount+1
    for _,e in pairs(entities) do if e.type==2 and e.state and e.state.VehicleProperties then
        check(e.plate==e.state.VehicleProperties.plate,'valet waits for real GTA plate, not statebag mirror')
    end end
    nextEntity=nextEntity+1
    local id,mode=nextEntity,pedMode
    local e={type=1,model=model,pos=vector3(x,y,z),health=0} entities[id]=e
    -- A server-created entity exists before its first client PedHealth sync node.
    CreateThread(function()
        check(e.protected,'networked valet is registered before the first initialization wait')
        Wait(mode=='slow' and 8000 or 800)
        if entities[id]~=e then return end
        if mode=='deleted' then entities[id]=nil
        elseif mode=='model_changed' then e.model=joaat('a_m_y_skater_01')
        elseif mode=='bucket_changed' then e.bucket=999
        elseif mode=='logout' then events['esx:playerLogout'](1)
        elseif mode~='timeout' then e.health=200 end
    end)
    return id
end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) return coroutine.yield(ms) end
function AddEventHandler(name,fn) events[name]=fn end
RegisterNetEvent=AddEventHandler
local function advance(ms)
    local deadline=now+ms
    repeat
        now=now+100
        for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and t.wake<=now then
            local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
        end end
    until now>=deadline
end
GlobalState={}
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
local esx={GetPlayerFromId=function(id) return players[id] end,
    RegisterCommand=function(name,_,fn) commands[name]=fn end,OneSync={}}
esx.OneSync.SpawnVehicle=function(model,pos,heading,props)
    spawnCount=spawnCount+1
    check(rows[props.plate].stored==0,'ESX stored flag reserved BEFORE yielding spawn')
    nextEntity=nextEntity+1
    local id=nextEntity
    entities[id]={type=2,model=joaat(model),pos=clone(pos),plate='RANDOM',spawnMode=spawnMode}
    Entity(id).state:set('VehicleProperties',props,true)
    if spawnMode=='ambiguous' then error('connection lost AFTER spawn') end
    if spawnMode=='deleted' or spawnMode=='model_changed' or spawnMode=='bucket_changed' or spawnMode=='logout' then
        local mode=spawnMode
        CreateThread(function()
            Wait(300)
            if mode=='deleted' then entities[id]=nil
            elseif mode=='model_changed' then entities[id].model=joaat('rhino')
            elseif mode=='logout' then events['esx:playerLogout'](1)
            else entities[id].bucket=999 end
        end)
    end
    return id
end
exports=setmetatable({es_extended={getSharedObject=function() return esx end},rp_core={
    rpProtectNetworkPed=function(_,ped) entities[ped].protected=true protectedActors[ped]=true return true end,
    rpReleaseNetworkPed=function(_,ped) protectedActors[ped]=nil return true end,
}}, {__call=function(_,name,fn) api[name]=fn end})
MySQL={query={},single={},update={},insert={},ready=function(fn) fn() end}
MySQL.query.await=function(sql,params)
    if sql:find('ORDER BY') then
        local result={} for _,row in pairs(rows) do if row.owner==params[1] then result[#result+1]=clone(row) end end return result
    end
    return {}
end
MySQL.single.await=function(_,params)
    local row=rows[params[2]]
    return row and row.owner==params[1] and clone(row) or nil
end
MySQL.insert.await=function(_,p) journal[p[1]]={owner=p[2],plate=p[3],garage=p[4],direction=p[5],phase='preparing'} return 1 end
MySQL.update.await=function(sql,p)
    if sql:find('UPDATE rp_vehicle_garage_operations') then
        journal[p[2]].phase=p[1]
        if killAt=='journal' and p[1]=='deleting' then
            for id in pairs(protectedActors) do if entities[id] then entities[id].health=0 end end
        end
        return 1
    end
    if sql:find('SET stored=0') then
        local row=rows[p[1]]
        if row and row.owner==p[2] and row.stored==1 and (not row.parking or row.parking==p[3]) then row.stored=0 return 1 end
        return 0
    end
    if sql:find('SET stored=1, parking=%?, vehicle=') then
        local row=rows[p[3]]
        for _,entity in pairs(entities) do check(entity.plate~=p[3],'stored=true only AFTER actual entity deletion') end
        if row and row.owner==p[4] and row.stored==0 then row.stored,row.parking,row.vehicle=1,p[1],p[2] return 1 end return 0
    end
    if sql:find('SET stored=1 WHERE') then
        local row=rows[p[1]]
        if row and row.owner==p[2] and row.stored==0 then row.stored=1 return 1 end return 0
    end
    error('Unexpected SQL '..sql)
end
function TriggerClientEvent(name,target,data,success,message,reason,retained)
    if name=='rp_vehicles:finish' then notifications[#notifications+1]={target=target,ok=success,reason=reason,retained=retained} return end
    if name~='rp_vehicles:step' then return end
    local action=data.action
    if data.ped then check(GetEntityHealth(data.ped)>0,'no scene command before first live ped health synchronization') end
    if killAt==action and data.ped then
        entities[data.ped].health=0
        deathPosition=clone(entities[data.vehicle].pos)
        source=target events['rp_vehicles:ack'](data.token,data.step,false,'valet_dead') return
    end
    if sceneMode=='plate_tamper' and action=='gate_open' then entities[data.vehicle].plate='CHANGED' end
    if sceneMode=='valet_dies' and action=='gate_open' then entities[data.ped].health=0 end
    if sceneMode=='timeout' then return end
    if sceneMode=='disconnect' and action=='exit' then
        source=target events.playerDropped() return
    end
    local ok=not (sceneMode=='no_gate' and action=='prepare')
    if action=='seat' or action=='enter' then entities[data.ped].vehicle=data.vehicle
    elseif (action=='drive' or action=='park') and sceneMode~='forged_arrival' then entities[data.vehicle].pos=clone(data.point)
    elseif action=='exit' then entities[data.ped].vehicle=nil
    elseif action=='walk' then entities[data.ped].pos=clone(data.point) end
    source=target
    events['rp_vehicles:ack'](data.token,data.step,ok)
end
dofile(base..'shared/config.lua')
dofile(base..'shared/rules.lua')
local g=Garage.Config.garages.la_mesa
for id,p in pairs(players) do entities[id]={type=1,pos=clone(g.clerk),model=id} p.showNotification=function() end end
dofile(base..'server/main.lua')
advance(200)
local function car(plate,owner)
    rows[plate]={owner=owner or players[1].identifier,plate=plate,type='car',stored=1,parking='la_mesa',
        vehicle=json.encode({model=joaat('asea'),plate=plate,fuelLevel=80,engineHealth=950,modEngine=3,customField={insured=true}})}
end
local function begin(plate,direction,id,condition)
    advance(1100)
    return callbacks['rp_vehicles:start'](id or 1,'la_mesa',direction or 'out',plate,condition)
end
car('TEST1') car('OTHER',players[2].identifier)
check(not begin('TEST1','out',2).ok,'same account OTHER CHARACTER cannot access vehicle')
check(not begin({}).ok,'table plate rejected')
check(not begin('OTHER').ok,'foreign owner rejected')
entities[1].pos={x=0,y=0,z=0}
check(not begin('TEST1').ok,'remote request rejected')
entities[1].pos=clone(g.clerk)
local out=begin('TEST1')
check(out.ok,'owner can request stored car')
advance(1100)
check(not callbacks['rp_vehicles:start'](2,'la_mesa','out','OTHER').ok,'one service per gate even across players')
advance(20000)
check(rows.TEST1.stored==0 and spawnCount==1,'exactly one car and standard out flag')
local entity=GetAllVehicles()[1]
check(entity and entities[entity].lock==1 and Garage.Rules.distance(entities[entity].pos,g.parking)<1,'handover unlocked only after attendant leaves')
check(not begin('TEST1').ok,'replayed request cannot duplicate')
entities[1].vehicle=entity
check(not begin('TEST1','in').ok,'player must leave vehicle')
entities[1].vehicle=nil
check(begin('TEST1','in',1,{fuelLevel=60,model='rhino',plate='FAKE',modEngine=9}).ok,'tracked vehicle accepted')
advance(20000)
check(rows.TEST1.stored==1 and not entities[entity],'store completed only with vehicle removed')
local props=json.decode(rows.TEST1.vehicle)
check(props.fuelLevel==60 and props.model==joaat('asea') and props.modEngine==3 and props.customField.insured,'condition saved; client model/upgrades ignored; metadata preserved')
check(begin('TEST1').ok,'retrieve again after successful storage') advance(20000)
entity=GetAllVehicles()[1]
refuseDelete=true
check(begin('TEST1','in').ok,'begin deletion failure scenario') advance(25000)
check(rows.TEST1.stored==0 and entities[entity],'failed entity deletion never makes vehicle available again')
refuseDelete=false entities[entity]=nil
car('GATE') sceneMode='no_gate'
local before=spawnCount
check(begin('GATE').ok,'gate test reservation accepted') advance(6000)
check(rows.GATE.stored==1 and spawnCount==before,'missing gate fails BEFORE reservation/spawn')
sceneMode='timeout'
check(begin('GATE').ok,'timeout test accepted') advance(35000)
check(rows.GATE.stored==1,'missing callback has bounded cleanup')
sceneMode=nil spawnMode='ambiguous'
check(begin('GATE').ok,'ambiguous spawn test accepted') advance(9000)
check(rows.GATE.stored==0,'ambiguous spawn result fails CLOSED, never resets stored')
spawnMode=nil
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
car('QUIT') sceneMode='disconnect'
check(begin('QUIT').ok,'disconnect scenario accepted') advance(20000)
check(rows.QUIT.stored==0,'disconnect during delivery cannot duplicate vehicle')
for _,id in ipairs(GetAllVehicles()) do check(entities[id].lock==1,'interrupted delivery unlocks remaining vehicle') end
sceneMode=nil
car('FORGED') rows.FORGED.stored=0
local fake=10000 entities[fake]={type=2,pos=clone(g.parking),model=joaat('asea'),plate='FORGED'}
check(not begin('FORGED','in').ok,'forged plate is not trusted ownership')
check(api.rpRegisterOwnedVehicle(fake,players[1].identifier,'FORGED'),'trusted server dealership adapter registers standard owned vehicle')
check(begin('FORGED','in').ok,'registered owned vehicle accepted') advance(20000)
check(rows.FORGED.stored==1,'adapter shares same safe storage lifecycle')
local condition=Garage.Rules.condition({fuelLevel=10,engineHealth=200},{fuelLevel=100,engineHealth=1000})
check(condition.fuelLevel==10 and condition.engineHealth==200,'client cannot repair or refuel via storage report')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
car('ACKTEST') sceneMode='forged_arrival'
check(begin('ACKTEST').ok,'forged arrival scenario begins') advance(40000)
check(not notifications[#notifications].ok and rows.ACKTEST.stored==0,'client ack cannot bypass actual server position and fails closed')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
sceneMode=nil spawnMode='late_owner' car('LATE')
local priorPeds,priorPublishes=pedCount,propertyPublishes
check(begin('LATE').ok,'delayed network ownership scenario accepted') advance(1600)
check(pedCount==priorPeds and not GlobalState['rp_vehicles:gate:la_mesa'],'no valet or open gate before plate projection')
advance(21000)
check(notifications[#notifications].ok and rows.LATE.stored==0,'standard ESX statebag retry recovers missed initial ownership')
check(propertyPublishes-priorPublishes<=4,'initialization retries are bounded, never per frame')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end

for index,case in ipairs({
    {'plate_timeout','vehicle_plate_sync_timeout'}, {'deleted','vehicle_missing'},
    {'model_changed','vehicle_model_mismatch'}, {'bucket_changed','vehicle_bucket_mismatch'}, {'logout','session_ended'},
}) do
    spawnMode=case[1] local plate='SYNC'..index car(plate)
    priorPeds=pedCount local priorSpawns=spawnCount
    check(begin(plate).ok,case[1]..' scenario accepted') advance(16000)
    check(lastFailure and lastFailure:find(case[2],1,true),case[1]..' reports precise failure')
    check(pedCount==priorPeds and spawnCount==priorSpawns+1,case[1]..' never bypasses validation or spawns duplicates')
    check(#GetAllVehicles()==0 and rows[plate].stored==1,case[1]..' restores storage only after concealed entity is gone')
    check(not GlobalState['rp_vehicles:gate:la_mesa'],case[1]..' keeps physical gate closed')
end
spawnMode=nil sceneMode='plate_tamper' car('TAMPER')
check(begin('TAMPER').ok,'post-initialization tamper scenario accepted') advance(12000)
check(lastFailure:find('vehicle_plate_mismatch',1,true),'plate grace ends before valet scene; later mismatches still abort')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
sceneMode=nil pedMode='slow' car('PEDLATE')
check(begin('PEDLATE').ok,'slow ped health initialization accepted') advance(6000)
check(not GlobalState['rp_vehicles:gate:la_mesa'],'garage stays closed while waiting for first ped health sync')
check(next(protectedActors)~=nil,'pending actor retains server-owned NPC protection')
advance(26000)
check(notifications[#notifications].ok and rows.PEDLATE.stored==0,'late synchronized valet completes handover')
check(next(protectedActors)==nil,'finished driver releases protection')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
for index,case in ipairs({
    {'timeout','valet_sync_timeout'}, {'deleted','valet_missing'},
    {'model_changed','valet_model_mismatch'}, {'bucket_changed','valet_bucket_mismatch'}, {'logout','session_ended'},
}) do
    pedMode=case[1] local plate='PED'..index car(plate)
    local previousPeds,previousSpawns=pedCount,spawnCount
    check(begin(plate).ok,case[1]..' ped scenario accepted') advance(18000)
    check(lastFailure:find(case[2],1,true),case[1]..' has specific ped diagnostic')
    check(pedCount==previousPeds+1 and spawnCount==previousSpawns+1,case[1]..' never retries by spawning extra actors or cars')
    check(next(protectedActors)==nil and #GetAllVehicles()==0 and rows[plate].stored==1,case[1]..' cleanup releases actor and safely restores concealed car')
    for id,e in pairs(entities) do check(players[id]~=nil,'initialization failure leaves no mission ped') end
end
pedMode=nil sceneMode='valet_dies' car('PEDDEAD')
check(begin('PEDDEAD').ok,'death after ped initialization accepted') advance(12000)
check(lastFailure:find('valet_dead',1,true),'health wait does not mask death after scene starts')
check(next(protectedActors)~=nil,'dead body remains protected during its bounded visible lifetime')
check(rows.PEDDEAD.stored==0 and #GetAllVehicles()==1,'driver death leaves the actual car out, never rolls it back')
check(GlobalState['rp_vehicles:gate:la_mesa'],'vehicle behind the gate remains accessible after death')
advance(61000) check(next(protectedActors)==nil,'dead actor protection released after body cleanup')
for _,id in ipairs(GetAllVehicles()) do entities[id]=nil end
sceneMode=nil advance(1200)
for index,phase in ipairs({'seat','drive','park','walk','gate_closed'}) do
    local plate='OUTD'..index car(plate) killAt=phase
    check(begin(plate).ok,'out death during '..phase..' accepted') advance(24000)
    local carId=GetAllVehicles()[1]
    check(rows[plate].stored==0 and carId and entities[carId].lock==1,'out death during '..phase..' retains and unlocks vehicle')
    check(Garage.Rules.distance(entities[carId].pos,deathPosition)<0.01,'out death never teleports car')
    check(notifications[#notifications].reason=='valet_dead' and notifications[#notifications].retained,'out death communicates retained vehicle')
    if not Garage.Rules.outsideGate(g,deathPosition,Garage.Config.gateClearance) then
        check(GlobalState['rp_vehicles:gate:la_mesa'] and Garage.Service.busy('la_mesa'),'gate remains open and reserved for retrieval')
        entities[carId].pos=clone(g.parking) advance(1200)
        check(not GlobalState['rp_vehicles:gate:la_mesa'] and not Garage.Service.busy('la_mesa'),'gate closes only after surviving car clears exit')
    end
    advance(61000) check(next(protectedActors)==nil,'out corpse cleaned without changing car ownership')
    entities[carId]=nil
end
for index,phase in ipairs({'walk','enter','drive','park','gate_closed','journal'}) do
    local plate='IND'..index car(plate) rows[plate].stored=0
    nextEntity=nextEntity+1 local carId=nextEntity
    entities[carId]={type=2,pos=clone(g.parking),model=joaat('asea'),plate=plate}
    check(api.rpRegisterOwnedVehicle(carId,players[1].identifier,plate),'register owned car for in death test')
    killAt=phase deathPosition=nil
    check(begin(plate,'in').ok,'in death during '..phase..' accepted') advance(28000)
    check(rows[plate].stored==0 and entities[carId] and entities[carId].lock==1,'in death before disappearance never commits storage')
    if deathPosition then check(Garage.Rules.distance(entities[carId].pos,deathPosition)<0.01,'in abort preserves exact car location') end
    check(notifications[#notifications].reason=='valet_dead' and notifications[#notifications].retained,'in death reports abort and keeps tracking car')
    entities[carId].pos=clone(g.parking) advance(1200)
    check(not GlobalState['rp_vehicles:gate:la_mesa'],'in abort gate closes after recovery')
    advance(61000) check(next(protectedActors)==nil,'in corpse protection eventually released')
    entities[carId]=nil
end
killAt=nil
car('STOPDEAD') killAt='drive'
check(begin('STOPDEAD').ok,'resource-stop cleanup scenario accepted') advance(8000)
local remaining=GetAllVehicles()[1]
check(next(protectedActors) and Garage.Service.busy('la_mesa'),'dead actor and recovery gate are active before stop')
events.onResourceStop('rp_vehicles') advance(61000)
check(next(protectedActors)==nil and not Garage.Service.busy('la_mesa'),'resource stop clears corpse protection and recovery watcher')
check(remaining and entities[remaining] and rows.STOPDEAD.stored==0,'stop and delayed cleanup never delete or re-store retained car')
print(('garage-server: %d checks passed'):format(passed))
