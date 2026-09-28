local registry,events,entities={}, {}, {[10]={model=100,type=1},[11]={model=100,type=1},[12]={model=2,type=2}}
local owner='rp_vehicles'
local checks=0
local function check(v,label) assert(v,label) checks=checks+1 end
GlobalState={}
function GetInvokingResource() return owner end
function GetCurrentResourceName() return 'rp_core' end
function DoesEntityExist(id) return entities[id]~=nil end
function GetEntityModel(id) return entities[id].model end
function GetEntityType(id) return entities[id].type end
function GetPlayers() return {'1'} end
function GetPlayerPed() return 11 end
function NetworkGetNetworkIdFromEntity(id) return id end
function AddEventHandler(name,fn) events[name]=fn end
function DeleteEntity(id) entities[id]=nil end
exports=function(name,fn) registry[name]=fn end
dofile('server-data/resources/[custom]/rp_core/server/network_peds.lua')
check(registry.rpProtectNetworkPed(10),'server resource can protect its valet')
check(GlobalState['rp_core:networkPeds']['10']==100,'server-owned global registry contains identity')
check(not registry.rpProtectNetworkPed(11),'player cannot be registered as a service ped')
check(not registry.rpProtectNetworkPed(12),'vehicle cannot be registered')
owner='unrelated_resource'
check(not registry.rpProtectNetworkPed(10),'foreign resource cannot take ownership')
check(not registry.rpReleaseNetworkPed(10),'foreign resource cannot release protection')
owner=nil
check(not registry.rpProtectNetworkPed(10),'no invoking server resource rejected')
owner='rp_vehicles'
check(registry.rpReleaseNetworkPed(10),'creator can release')
check(next(GlobalState['rp_core:networkPeds'])==nil,'release clears registry')
check(registry.rpProtectNetworkPed(10),'can register again')
events.onResourceStop('rp_vehicles')
check(not entities[10] and next(GlobalState['rp_core:networkPeds'])==nil,'owner stop deletes mission actor and protection')
print(('garage-network-peds: %d checks passed'):format(checks))
