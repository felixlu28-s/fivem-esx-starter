local now,removed,created,inside,exists,plate=0,0,0,false,false,'TEMP'
local events,threads={},{}
function GetGameTimer() return now end
function PlayerPedId() return 1 end
function IsEntityDead() return false end
function GetCurrentResourceName() return 'rp_vehicles' end
function NetworkDoesEntityExistWithNetworkId() return exists end
function NetworkGetEntityFromNetworkId() return 5 end
function DoesEntityExist() return exists end
function GetVehicleNumberPlateText() return plate end
function GetVehiclePedIsIn() return inside and 5 or 0 end
function AddBlipForEntity(e) assert(e==5) created=created+1 return created end
function RemoveBlip() removed=removed+1 end
for _,n in ipairs({'SetBlipSprite','SetBlipColour','SetBlipScale','SetBlipAsShortRange','BeginTextCommandSetBlipName','AddTextComponentString','EndTextCommandSetBlipName'}) do _G[n]=function() end end
function RegisterNetEvent(n,f) events[n]=f end AddEventHandler=RegisterNetEvent
function CreateThread(f) threads[#threads+1]=coroutine.create(f) end
function Wait(ms) coroutine.yield(ms) end
local function tick(ms) for _=1,math.ceil(ms/250) do now=now+250 for _,co in ipairs(threads) do if coroutine.status(co)~='dead' then local ok,err=coroutine.resume(co) assert(ok,err) end end end end
Garage={} dofile('server-data/resources/[custom]/rp_vehicles/shared/rules.lua')
dofile('server-data/resources/[custom]/rp_vehicles/client/delivery.lua')
source=1 events['rp_vehicles:deliveryBlip']('a',5,'TEST') tick(250) assert(created==0)
source=65535 events['rp_vehicles:deliveryBlip']('a',5,'TEST') tick(1000) assert(created==0)
exists=true tick(1000) assert(created==0,'wait for replicated plate instead of deleting tracker')
plate='TEST' tick(500) assert(created==1)
events['rp_vehicles:finish']('a',true) tick(500) assert(removed==0,'success keeps moving entity blip until boarding')
inside=true tick(500) assert(removed==1,'boarding removes blip')
inside=false events['rp_vehicles:deliveryBlip']('b',5,'TEST') tick(250)
events['rp_vehicles:finish']('b',false) assert(removed==2,'abort cleans blip')
events['rp_vehicles:deliveryBlip']('c',5,'TEST') tick(250)
events['rp_vehicles:finish']('c',false,'','valet_dead',true) tick(250)
assert(removed==2,'retained vehicle after valet death keeps its blip')
inside=true tick(250) assert(removed==3,'boarding retained car removes the blip normally')
inside=false events['rp_vehicles:deliveryBlip']('d',5,'TEST') tick(250)
events.onResourceStop('rp_vehicles') tick(250) assert(removed==4)
print('garage-delivery: server-only tracking, delayed entity/plate, arrival, boarding, failure and stop cleanup passed')
