local base='server-data/resources/[custom]/rp_vehicles/'
local now,checks,physics,ratio,lock,removed=0,0,false,0.6,0,0
local threads,events={},{}
local function check(v,label) assert(v,label) checks=checks+1 end
function GetGameTimer() return now end
function GetCurrentResourceName() return 'rp_vehicles' end
function PlayerPedId() return 1 end
function joaat(v) return v end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) coroutine.yield(ms) end
function RegisterNetEvent(n,f) events[n]=f end AddEventHandler=RegisterNetEvent
function RegisterCommand() end
local function advance(ms)
    for _=1,math.ceil(ms/50) do now=now+50 for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and t.wake<=now then
        local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
    end end end
end
dofile(base..'shared/config.lua') dofile(base..'shared/rules.lua') dofile(base..'shared/schema.lua')
local g=Garage.Config.garages.la_mesa
check(g.gate.model=='prop_id2_11_gdoor' and math.abs(g.gate.x-723.12)<0.01,'correct La Mesa map door')
function GetEntityCoords(id) return id==100 and {x=723.119,y=-1088.829,z=23.281} or {x=g.interaction.x,y=g.interaction.y,z=22.17} end
function DoesEntityExist(id) return id==100 end
function GetClosestObjectOfType(_,_,_,_,model) check(model=='prop_id2_11_gdoor','look up real model') return 100 end
function IsModelInCdimage() return false end
function DoorSystemFindExistingDoor(x,y,z,model) check(x==723.119 and z==23.281,'register actual object origin') return true,55 end
function DoorSystemGetDoorState() return lock end
function DoorSystemGetOpenRatio() return ratio end
function DoorSystemGetIsPhysicsLoaded() return physics end
function DoorSystemSetDoorState(_,value) check(physics or now>3000,'no premature door-state command') lock=value end
function DoorSystemSetOpenRatio(_,value) check(physics or now>3000,'no premature ratio command') ratio=value end
function RemoveDoorFromSystem() removed=removed+1 end
function AddBlipForCoord() return 9 end
for _,n in ipairs({'SetBlipSprite','SetBlipColour','SetBlipScale','SetBlipAsShortRange','BeginTextCommandSetBlipName','AddTextComponentString','EndTextCommandSetBlipName','RemoveBlip','DoorSystemSetAutomaticDistance','DoorSystemSetAutomaticRate'}) do _G[n]=function() end end
GlobalState={}
lib={callback={await=function() local r=Garage.Rules.copy(g) r.id='la_mesa' r.revision=1 return {ok=true,garages={r}} end}}
exports={rp_core={},es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return true end} end}}
dofile(base..'client/world.lua')
advance(1200)
check(Garage.World.instances.la_mesa.open==nil,'unloaded physics never caches closed success')
local ok,reason=Garage.World.gateStatus('la_mesa',false)
check(not ok and reason=='gate_physics_unloaded','specific physics diagnostic')
physics=true advance(500)
check(Garage.World.gateReady('la_mesa',false) and lock==1,'close retried after physics loads, then locked')
GlobalState['rp_vehicles:gate:la_mesa']=true advance(500)
check(ratio==1 and lock==0 and Garage.World.gateReady('la_mesa',true),'unlock before opening')
GlobalState['rp_vehicles:gate:la_mesa']=false advance(500)
check(ratio==0 and lock==1,'reclose confirmed')
advance(500) events.onResourceStop('rp_vehicles')
check(removed==0 and ratio==0.6 and lock==0,'borrowed map door restored without unregistering it')
print(('garage-world: %d door streaming/physics checks passed'):format(checks))
