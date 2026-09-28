-- Actual client catalogue lifecycle with asynchronous RPCs and ESX login timing.
local base='server-data/resources/[custom]/rp_vehicles/'
local now,checks,loaded,bucket,requests=0,0,false,10001,0
local latency,failUntil,throwOnce=0,0,false
local threads,events,network,blips={},{},{},{}
local function check(value,label) assert(value,label) checks=checks+1 end
function GetGameTimer() return now end
function GetCurrentResourceName() return 'rp_vehicles' end
function PlayerPedId() return 1 end
function GetEntityCoords() return {x=0,y=0,z=0} end -- outside NPC streaming range
function joaat(v) return v end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) coroutine.yield(ms) end
function RegisterNetEvent(n,f) network[n]=true events[n]=f end
function AddEventHandler(n,f) events[n]=f end
function RegisterCommand() end
local function advance(ms)
    for _=1,math.ceil(ms/50) do
        now=now+50
        for _,t in ipairs(threads) do
            if coroutine.status(t.co)~='dead' and t.wake<=now then
                local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
            end
        end
    end
end
local function send(name,origin)
    check(network[name],'network event registered: '..name)
    source=origin or 65535 events[name]() source=nil
end
function AddBlipForCoord() local id={} blips[id]=true return id end
function RemoveBlip(id) blips[id]=nil end
local function countBlips() local n=0 for _ in pairs(blips) do n=n+1 end return n end
for _,n in ipairs({'SetBlipSprite','SetBlipColour','SetBlipScale','SetBlipAsShortRange',
    'BeginTextCommandSetBlipName','AddTextComponentString','EndTextCommandSetBlipName'}) do _G[n]=function() end end
dofile(base..'shared/config.lua') dofile(base..'shared/rules.lua') dofile(base..'shared/schema.lua')
local row=Garage.Rules.copy(Garage.Config.garages.la_mesa) row.id='la_mesa' row.revision=1
exports={rp_core={},es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end}}
lib={callback={await=function(name)
    assert(name=='rp_vehicles:locations') requests=requests+1
    local rows=bucket==0 and {Garage.Rules.copy(row)} or {}
    if latency>0 then Wait(latency) end
    if throwOnce then throwOnce=false error('simulated transport timeout') end
    if now<failUntil then return {ok=false} end
    return {ok=true,garages=rows}
end}}
dofile(base..'client/world.lua')
local W=Garage.World
advance(15000)
check(requests==0 and countBlips()==0 and not W.received,'slow login neither leaks seed blips nor exhausts retries')
loaded=true send('esx:playerLoaded') advance(1500)
check(W.received and not Garage.Config.garages.la_mesa and countBlips()==0,'private character instance legitimately has empty catalogue')
local baseline=requests
send('rp_vehicles:locationsChanged',0) advance(250)
check(requests==baseline,'local notification cannot reload server catalogue')
bucket=0 send('rp_vehicles:locationsChanged') advance(500)
check(Garage.Config.garages.la_mesa and countBlips()==1,'world transition loads La Mesa and its blip')
baseline=requests advance(30000)
check(requests==baseline,'successful catalogue is not polled repeatedly')

-- Notification arriving while a request still contains the old bucket snapshot.
latency=1000 bucket=10001 send('rp_vehicles:locationsChanged') advance(100)
bucket=0 send('rp_vehicles:locationsChanged') advance(2400)
check(Garage.Config.garages.la_mesa and countBlips()==1,'in-flight transition queues a fresh authoritative catalogue')
baseline=requests advance(3000) check(requests==baseline,'coalesced request terminates')

-- Logout must invalidate an outstanding reply and remove all world hints.
send('rp_vehicles:locationsChanged') advance(100)
loaded=false send('esx:onPlayerLogout') advance(1500)
check(not W.received and not Garage.Config.garages.la_mesa and countBlips()==0,'late reply cannot resurrect garage after logout')
loaded=true latency=0 send('esx:playerLoaded') advance(1500)
check(W.received and countBlips()==1,'next character obtains its own catalogue')

-- Four failed requests must not permanently disable the garage resource.
loaded=false send('esx:onPlayerLogout') advance(300)
loaded=true failUntil=now+14500 throwOnce=true send('esx:playerLoaded') advance(10000)
check(not W.received and W.error~=nil and countBlips()==0,'temporary unavailable server remains recoverable without seed fallback')
advance(12000)
check(W.received and W.error==nil and countBlips()==1,'catalogue recovers after more than four startup failures')
baseline=requests advance(15000) check(requests==baseline,'recovery polling ends after success')

latency=1000 send('rp_vehicles:locationsChanged') advance(100)
events.onResourceStop('rp_vehicles') advance(1500)
check(countBlips()==0 and W.stopped,'resource stop discards late RPC and removes blips')
print(('garage-catalogue: %d login/instance/cleanup checks passed'):format(checks))
