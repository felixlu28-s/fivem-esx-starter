local checks,now=0,0
local function check(v,label) assert(v,label) checks=checks+1 end
local events,threads,acks={}, {}, {}
local entities={ [1]={},[10]={},[20]={pos={x=0,y=0,z=0},heading=180.0} }
local open,control,dead=false,true,false
local driveCalls,blocked,driveable=0,false,true
function GetGameTimer() return now end
function GetCurrentResourceName() return 'rp_vehicles' end
function PlayerPedId() return 1 end
function IsEntityDead(id) return id==1 and dead or entities[id] and entities[id].dead==true end
function GetEntityCoords(id) return entities[id].pos end
function GetEntityHeading(id) return entities[id].heading end
function GetEntitySpeed() return 0.0 end
function GetEntityModel() return 123 end
function IsVehicleDriveable() return driveable end
function GetEntityForwardVector(id)
    local h=math.rad(entities[id].heading or 0) return {x=-math.sin(h),y=math.cos(h),z=0}
end
function DoesEntityExist(id) return entities[id]~=nil end
function NetworkDoesEntityExistWithNetworkId(id) return entities[id]~=nil end
function NetworkGetEntityFromNetworkId(id) return id end
function NetworkRequestControlOfEntity() end
function NetworkHasControlOfEntity() return control end
function GetPedInVehicleSeat() return entities[10].vehicle==20 and 10 or 0 end
function IsPedInAnyVehicle(id) return entities[id].vehicle~=nil end
function TaskWarpPedIntoVehicle(id,vehicle) check(not open,'hidden initial warp only behind closed gate') entities[id].vehicle=vehicle end
function TaskEnterVehicle(id,vehicle) entities[id].vehicle=vehicle end
function TaskLeaveVehicle(id) entities[id].vehicle=nil end
function TaskVehicleDriveToCoord(ped,vehicle,x,y,z,speed,_,_,style)
    driveCalls=driveCalls+1
    check(speed<=4,'careful valet speed')
    check((style & 16777216)~=0,'short garage path explicitly bypasses road-network routing')
    check(entities[vehicle].engine and not entities[vehicle].brake,'drive starts only with engine on and brake released')
    check(entities[ped].vehicle==vehicle,'driver seated before driving')
    entities[vehicle].style=style
    if not blocked then entities[vehicle].pos={x=x,y=y,z=z} end
end
function TaskVehiclePark(_,vehicle,x,y,z,heading) entities[vehicle].pos={x=x,y=y,z=z} entities[vehicle].heading=heading end
function TaskFollowNavMeshToCoord(id,x,y,z) entities[id].pos={x=x,y=y,z=z} end
function SetVehicleHandbrake(id,value) entities[id].brake=value end
function ClearPedTasks(id) entities[id].cleared=true end
function SetEntityInvincible(id,value) entities[id].invincible=value end
function SetEntityCanBeDamaged(id,value) entities[id].damage=value end
function SetPedCanRagdoll(id,value) entities[id].ragdoll=value end
function SetPedCanBeDraggedOut(id,value) entities[id].dragged=value end
function SetVehicleEngineOn(id,value) entities[id].engine=value end
for _,name in ipairs({'RequestCollisionAtCoord','SetBlockingOfNonTemporaryEvents',
    'TaskLookAtEntity','TaskClearLookAt','RequestAnimDict','RemoveAnimDict','TaskPlayAnim','StopAnimTask','PlayPedAmbientSpeechNative',
    'SetPedFleeAttributes','SetPedKeepTask','SetDriverAbility','SetDriverAggressiveness',
    'SetVehicleDoorsLocked','TaskVehicleTempAction'}) do _G[name]=function() end end
function RegisterNetEvent(name,fn) events[name]=fn end
AddEventHandler=RegisterNetEvent
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) return coroutine.yield(ms) end
function TriggerServerEvent(name,token,step,ok,reason) acks[#acks+1]={name=name,token=token,step=step,ok=ok,reason=reason} end
local function advance(ms)
    local finish=now+ms
    repeat
        now=now+50
        for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and now>=t.wake then
            local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
        end end
    until now>=finish
end
lib={notify=function() end}
dofile('server-data/resources/[custom]/rp_vehicles/shared/config.lua')
dofile('server-data/resources/[custom]/rp_vehicles/shared/rules.lua')
function HasAnimDictLoaded() return true end
Garage.World={gateReady=function(_,expected) return expected==open end,
    gateStatus=function(_,expected) return expected==open,'gate_not_closed' end,react=function() end}
dofile('server-data/resources/[custom]/rp_vehicles/client/scene.lua')
local step=0
local function send(action,point)
    step=step+1 source=65535
    events['rp_vehicles:step']({garage='la_mesa',token='test',step=step,action=action,point=point,vehicle=20,ped=10})
    advance(100)
end
send('prepare') check(acks[#acks].ok,'closed physical door required')
send('seat') check(acks[#acks].ok and entities[10].vehicle==20,'hidden driver seated')
check(entities[10].invincible==false and entities[10].damage and entities[10].ragdoll and entities[10].dragged,'valet is mortal and may be pulled from the driver seat')
send('gate_open') advance(1000)
check(acks[#acks].step==2,'door does not complete before physical opening')
open=true advance(100)
check(acks[#acks].step==3 and acks[#acks].ok,'physical open acknowledged')
send('drive',{x=5,y=2,z=1}) check(acks[#acks].ok,'drive uses task and acknowledges arrival')
send('park',{x=5,y=2,z=1,h=180}) check(acks[#acks].ok and entities[20].brake,'vehicle stopped at handover')
send('exit') check(not entities[10].vehicle,'attendant exits through native animation')
send('walk',{x=0,y=2,z=1}) check(entities[10].pos.y==2,'return uses navmesh walking task')
send('gate_closed') open=false advance(100)
check(acks[#acks].step==8 and acks[#acks].ok,'close waits for real door ratio')
events['rp_vehicles:finish']('test',true,'ready')
check(not Garage.Scene.active and not entities[20].brake,'finish releases scene and handbrake')
source=1
events['rp_vehicles:step']({garage='la_mesa',token='forged',step=1,action='seat',vehicle=20,ped=10})
check(not Garage.Scene.active,'local forged command rejected')
control=false send('enter') advance(13000)
check(not acks[#acks].ok,'missing network control has bounded failure')
control=true source=65535 events['rp_vehicles:finish']('test',false)
open=true send('prepare') advance(13000)
check(not acks[#acks].ok,'cannot spawn behind an open/unavailable door')
source=65535 events['rp_vehicles:finish']('test',false)
open=false send('prepare')
local before=#acks
source=65535 events['rp_vehicles:step']({garage='la_mesa',token='test',step=step,action='seat',vehicle=20,ped=10})
advance(100) check(#acks==before,'duplicate stage ignored')
send('seat')
entities[20].pos={x=0,y=0,z=0} entities[20].heading=90
send('drive',{x=5,y=0,z=0})
check(acks[#acks].ok and (entities[20].style & 1024)~=0,'target behind vehicle uses reverse instead of road-network U-turn')
entities[20].pos={x=0,y=0,z=0} blocked=true
local priorDrive=driveCalls
send('drive',{x=20,y=0,z=0}) advance(21000)
check(not acks[#acks].ok and acks[#acks].reason=='drive_timeout','real obstacle produces bounded failure')
check(driveCalls-priorDrive==3 and entities[20].pos.x==0,'at most two task retries; never teleport or force velocity')
blocked=false driveable=false priorDrive=driveCalls
send('drive',{x=20,y=0,z=0})
check(not acks[#acks].ok and acks[#acks].reason=='vehicle_not_driveable' and driveCalls==priorDrive,'wrecked car is not silently repaired')
driveable=true blocked=true
send('drive',{x=20,y=0,z=0}) entities[10].dead=true advance(200)
check(not acks[#acks].ok and acks[#acks].reason=='valet_dead','death cancels a running driving task')
entities[10].cleared=false
source=65535 events['rp_vehicles:finish']('test',false,'','valet_dead',true)
check(not entities[10].cleared,'cleanup preserves death animation and ragdoll')
entities[10].dead=false blocked=false
before=#acks
control=false send('enter')
events.onResourceStop('rp_vehicles') advance(13000)
check(not Garage.Scene.active and #acks==before,'resource stop cancels pending control wait without late ack')
print(('garage-client: %d checks passed'):format(checks))
