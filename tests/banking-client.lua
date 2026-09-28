-- ATM object discovery, UI ownership and animation cleanup without a GTA process.
local checks=0
local function check(value,label) assert(value,label) checks=checks+1 end
local threads,events,commands,routes={},{},{},{}
local playerPos,atmPos,model,view,scenario,dead,inVehicle,loaded
local focused=false local blips,removed,hidden,closed,opened,cleared=0,0,0,0,0,0
local resources={rp_ui='started',rp_core='started'}
function GetCurrentResourceName() return 'rp_banking' end
function GetResourceState(name) return resources[name] or 'started' end
function joaat(value) return value end
function PlayerPedId() return 1 end
function GetEntityCoords(id) return id==1 and playerPos or atmPos end
function DoesEntityExist(id) return id==1 or id==2 end
function IsPedDeadOrDying() return dead end
function IsPedInAnyVehicle() return inVehicle end
function IsNuiFocused() return focused end
function GetClosestObjectOfType(_,_,_,_,hash) return hash==model and 2 or 0 end
function IsPedUsingScenario() return scenario end
function ClearPedTasks() scenario=false cleared=cleared+1 end
function TaskStartScenarioInPlace() scenario=true end
function TaskTurnPedToFaceEntity() end
function PlaySoundFrontend() end
function TriggerServerEvent(name) if name=='rp_banking:close' then closed=closed+1 end end
function Wait(ms) coroutine.yield(ms) end
local function resume(thread) local ok,err=coroutine.resume(thread) assert(ok,err) end
function CreateThread(fn) local thread=coroutine.create(fn) threads[#threads+1]=thread resume(thread) end
function AddEventHandler(name,fn) events[name]=fn end
RegisterNetEvent=AddEventHandler
function RegisterCommand(name,fn) commands[name]=fn end
function AddBlipForCoord() blips=blips+1 return blips end
function RemoveBlip() removed=removed+1 end
function SetBlipSprite() end function SetBlipScale() end function SetBlipColour() end function SetBlipAsShortRange() end
function BeginTextCommandSetBlipName() end function AddTextComponentString() end function EndTextCommandSetBlipName() end
local shown,registered
exports={es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end},
    rp_core={rpRegisterInputAction=function(_,definition) registered=definition end},
    rp_ui={rpGetView=function() return view end,
        rpHideInteraction=function() shown=nil hidden=hidden+1 end,
        rpShowInteraction=function(_,data) shown=data end,
        rpIsInteractionActive=function(_,action) return shown and shown.action==action end,
        rpRegisterAction=function(_,name,fn) routes[name]=fn end,
        rpOpen=function(_,name,payload,lock,options)
            view=name focused=true opened=opened+1
            check(options.toggleAction=='rp_banking:interact' and not lock,'own close binding and unlocked UI') return true
        end,
        rpClose=function() view=nil focused=false end}}
lib={notify=function()end,callback={await=function(name,_,location,kind)
    if name=='rp_banking:open' then return {ok=true,banking={session='session-test',brand=Banking.Config.models[kind]}} end
    return {ok=true}
end}}
dofile('server-data/resources/[custom]/rp_banking/shared/config.lua')
dofile('server-data/resources/[custom]/rp_banking/shared/locations.lua')
local at=Banking.locations[1]
playerPos={x=at.x,y=at.y,z=at.z} atmPos={x=at.x,y=at.y,z=at.z}
model='prop_fleeca_atm' loaded=true
dofile('server-data/resources/[custom]/rp_banking/client/main.lua')
local poll=threads[1]
check(blips==70 and registered.defaultKey=='E','configured map blips and rebindable E')
check(shown and shown.icon=='bank' and shown.label=='Fleeca Bank','nearby GTA object gets themed interaction')
events['rp_core:inputPressed']('rp_banking:interact')
check(not view,'turn-to-ATM finishes before opening UI')
local opening=threads[#threads] resume(opening)
check(view=='banking' and scenario,'ATM scenario and screen active')
check(not routes['rp_banking:action']({session='forged'}).ok,'local route rejects foreign session')
check(routes['rp_banking:action']({session='session-test',action='history'}).ok,'own session forwards callback')
view=nil focused=false resume(poll)
check(not scenario and closed==1 and cleared==1,'UI close stops only owned ATM scenario and closes server view')
playerPos.x=at.x+30 resume(poll)
check(not shown,'leaving location hides interaction')
commands.rp_atm() check(opened==1,'command cannot open remotely')
playerPos.x=at.x model='prop_atm_03' resume(poll)
check(shown.label=='Maze Bank','matching model selects Maze brand')
dead=true resume(poll) check(not shown,'dead player cannot interact') dead=false
inVehicle=true resume(poll) check(not shown,'vehicle occupant cannot interact') inVehicle=false
resume(poll) commands.rp_atm() resume(threads[#threads])
dead=true resume(poll)
check(not view and not scenario,'death cleans up active ATM') dead=false
resume(poll) commands.rp_atm() resume(threads[#threads])
source=1 events['rp_banking:hide']() check(view=='banking','fake local hide event ignored')
source=65535 events['rp_banking:hide']() check(not view and not scenario,'server close releases ATM')
resume(poll) commands.rp_atm()
opening=threads[#threads] events['esx:onPlayerLogout']() resume(opening)
check(not view and not scenario,'logout cancels pending turn/animation')
resources.rp_ui='stopped' events.onResourceStop('rp_ui') resume(poll)
check(removed==0,'UI restart does not discard ATM map blips')
resources.rp_ui='started' events.onClientResourceStart('rp_ui') resume(poll)
check(shown and routes['rp_banking:action'],'dependency restart restores interaction/route')
events.onResourceStop('rp_banking')
check(removed==blips and not shown,'own stop removes map blips and prompt')
print(('PASS: %d banking client discovery / input / lifecycle checks'):format(checks))
