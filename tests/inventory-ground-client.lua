-- Actual streamed prop/animation/input client with deterministic native stubs.
local base,passed='server-data/resources/[custom]/rp_inventory/',0
local function check(value,label) assert(value,label) passed=passed+1 end
dofile(base..'shared/items.lua')
local events,threads,entities,requests={},{},{},{}
local time,serial,loaded,modelReady,active=10000,0,true,true,true
local hint,action,animations=nil,nil,0
local physics,attached,released,floorContact=0,0,0,true
local attachedAt,airborne,jitter=0,false,false
local missingGrip,missingHand=false,false
local lastGrip
local vec={}
vec.__sub=function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},vec) end
vec.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vec) end
exports={es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end},
    rp_ui={rpShowInteraction=function(_,p) hint=p end,rpHideInteraction=function() hint=nil end,
        rpIsInteractionActive=function() return active end},
    rp_core={rpRegisterInputAction=function(_,p) action=p end}}
lib={notify=function() end,callback={await=function(name,_,value)
    requests[#requests+1]={name=name,value=value}
    if name=='rp_inventory:pickupStart' then return {ok=true,token='server-claim'} end
    return {ok=true}
end}}
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function GetGameTimer() return time end
function GetCurrentResourceName() return 'rp_inventory' end
function PlayerPedId() return 100 end
function GetEntityCoords(id) return entities[id] and entities[id].pos or vector3(0,0,0.8) end
function PlayerId() return 0 end
function GetPlayerServerId() return 7 end
function IsEntityDead() return false end
function joaat(value) return value end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return modelReady end
function RequestWeaponAsset() end
function HasWeaponAssetLoaded() return modelReady end
function RemoveWeaponAsset() end
function SetModelAsNoLongerNeeded() end
local function create(model,weapon,x,y,z)
    serial=serial+1 entities[serial]={model=model,weapon=weapon,pos=vector3(x,y,z)} return serial
end
function CreateObjectNoOffset(model,x,y,z,network)
    check(network==false,'props are local presentation, never network pickups')
    return create(model,false,x,y,z)
end
function CreateWeaponObject(model,count,x,y,z)
    check(count==0,'weapon presentation contains no free ammunition') return create(model,true,x,y,z)
end
function DoesWeaponTakeWeaponComponent() return true end
function GetWeaponComponentTypeModel() return 555 end
function GiveWeaponComponentToWeaponObject(entity,component) entities[entity].component=component end
function SetWeaponObjectTintIndex(entity,tint) entities[entity].tint=tint end
function DoesEntityExist(id) return id==100 or entities[id]~=nil end
function DeleteEntity(id) entities[id]=nil end
function SetEntityAsMissionEntity() end
function SetEntityCollision(id,enabled) entities[id].collision=enabled end
function FreezeEntityPosition(id,value) entities[id].frozen=value end
function SetEntityRotation(id,x,y,z) entities[id].rot=vector3(x,y,z) end
function GetEntityRotation(id) return entities[id].rot or vector3(0,0,0) end
function SetEntityInvincible() end
function SetEntityVisible() end
function GetPedBoneIndex(_,bone)
    check(bone==28422 or bone==57005,'prop grip or explicit wrist fallback selected')
    if bone==28422 then return missingGrip and -1 or 42 end
    return missingHand and -1 or 43
end
function AttachEntityToEntity(id,_,bone,x,y,z,rx,ry,rz,_,soft,collision,pedMode,order,sync)
    check(bone==42 or bone==43,'native bone index used instead of bone ID')
    check(not soft and not collision and pedMode and order==2 and sync,'rigid collision-free grip follows full hand rotation')
    lastGrip={bone=bone,x=x,y=y,z=z,rx=rx,ry=ry,rz=rz}
    attached=attached+1 entities[id].pos=vector3(0,0,1.1)
    attachedAt=time
end
function DetachEntity(id)
    released=released+1
    check(time-attachedAt>=1420,'release waits the extra second for the hand animation')
    check(entities[id].pos.z==1.1,'release occurs at exact animated hand position')
end
function SetEntityNoCollisionEntity(_,_,thisFrameOnly)
    check(thisFrameOnly==true,'thrower collision exemption lasts only the release frame')
end
function SetEntityDynamic() end
function SetEntityHasGravity() end
function ActivatePhysics(id)
    physics=physics+1
    check(not entities[id].frozen and entities[id].collision,'gravity runs unfrozen with world collision')
    entities[id].pos=vector3(0,0,0.12) -- deterministic mock landing; GTA performs the real integration
end
function SetEntityVelocity(_,x,y,z) check(math.abs(x)+math.abs(y)<0.2 and z<=0,'only a gentle release impulse') end
function GetEntityForwardVector() return vector3(0,1,0) end
function GetEntitySpeed() return jitter and 0.1 or 0 end
function HasEntityCollidedWithAnything() return floorContact end
function IsEntityInAir() return airborne end
function TriggerServerEvent(name,...) requests[#requests+1]={name=name,values={...}} end
function GetEntityModel(id) return entities[id].model end
function GetModelDimensions() return vector3(-0.1,-0.1,-0.1),vector3(0.1,0.1,0.1) end
function StartShapeTestLosProbe() return 1 end
function GetShapeTestResult() return 2,true,vector3(0,0,0) end
function GetPlayerFromServerId() return 0 end
function GetPlayerPed() return 100 end
function GetPedBoneCoords() return vector3(0,0,1.1) end
function SetEntityCoordsNoOffset(id,x,y,z) entities[id].pos=vector3(x,y,z) end
function RequestAnimDict() end
function HasAnimDictLoaded() return true end
function TaskPlayAnim(_,dict,clip)
    check(dict~='weapons@projectile@','no aggressive projectile throw')
    animations=animations+1
end
function StopAnimTask() end
function RemoveAnimDict() end
local function step(co)
    local ok,delay=coroutine.resume(co) assert(ok,delay)
    if type(delay)=='number' then time=time+math.max(16,delay) end
    return delay
end
local function finish(co) for _=1,400 do if coroutine.status(co)=='dead' then return end step(co) end error('thread did not finish') end
dofile(base..'client/ground.lua')
step(threads[1])
check(action.id=='rp_inventory:pickup' and action.defaultKey=='E','pickup registered as rebindable own E action')
local loop=threads[2]
local function item(id,weapon,age)
    return {id=id,label='Mineralwasser',count=2,model=weapon and 'WEAPON_PISTOL' or 'prop_ld_flow_bottle',
        weapon=weapon or false,pos={x=0,y=0,z=0.2},age=age or 10,owner=7}
end
source=22 events['rp_inventory:ground']({item('fake')})
check(#threads==2,'untrusted world state ignored')
local gun=item('b',true)
gun.components={453432689} gun.tintIndex=3
source=65535 events['rp_inventory:ground']({item('a'),gun})
finish(threads[3]) finish(threads[4])
check(entities[1] and entities[2] and entities[2].weapon,'items and guns have real local world objects')
check(entities[1].collision and entities[2].collision,'already resting streamed items and weapons have collision')
check(entities[2].component==453432689 and entities[2].tint==3,'ground weapon renders authoritative attachment and tint')
check(math.abs(entities[1].pos.z-0.12)<0.001,'model bounds keep props on surface')
events['rp_inventory:ground']({item('a'),item('b',true)})
check(#threads==4,'repeated streaming packets do not respawn existing entities')
events['rp_inventory:ground']({item('a')})
check(not entities[2] and entities[1],'removed server entry deletes only its prop')
step(loop)
check(hint.action=='rp_inventory:pickup' and hint.label:find('Mineralwasser',1,true),'item name and pickup action displayed')
active=false events['rp_core:inputPressed']('rp_inventory:pickup')
check(#requests==0,'nonvisible contextual action cannot pick up')
active=true events['rp_core:inputPressed']('rp_inventory:pickup')
local pickup=threads[#threads]
step(pickup)
check(#requests==1 and animations==1 and requests[1].name=='rp_inventory:pickupStart','server reservation precedes animation')
finish(pickup)
check(#requests==2 and requests[2].name=='rp_inventory:pickupFinish' and requests[2].value=='server-claim','finish uses only server token after animation')
check(entities[1]~=nil,'client never deletes ground ownership optimistically')
events['rp_inventory:ground']({})
check(not next(entities),'server removal clears pickup prop')
events['rp_inventory:ground']({item('thrown',false,0)})
local thrown=threads[#threads] step(thrown)
check(next(entities)~=nil,'throw creates a moving visible object')
check(lastGrip.bone==42 and lastGrip.x==0.02 and lastGrip.z==-0.07,'bottle uses physical hand grip and its own pivot correction')
finish(thrown)
check(math.abs(entities[3].pos.z-0.12)<0.001,'throw finishes on floor')
check(attached==1 and released==1 and physics==1,'real prop attaches to hand then enters physics')
check(entities[3].frozen and entities[3].collision,'settled object keeps resting pose and world collision')
check(requests[#requests].name=='rp_inventory:groundSettled','owner publishes one cosmetic landing pose')
local snapshot=item('thrown',false,5) snapshot.visual={pos={x=0.05,y=0,z=0.12},rot={x=4,y=5,z=6}}
events['rp_inventory:ground']({snapshot})
check(entities[3].pos.x==0.05 and entities[3].rot.z==6 and entities[3].collision,'server-validated resting pose updates without disabling collision')
events['rp_inventory:ground']({})
floorContact=false
events['rp_inventory:ground']({item('no-collision',false,0)})
finish(threads[#threads])
check(entities[4].frozen and entities[4].collision and math.abs(entities[4].pos.z-0.12)<0.001,'missing contact flag preserves actual supported landing and collision')
floorContact=true
events['rp_inventory:ground']({})
jitter=true
events['rp_inventory:ground']({item('rocking-weapon',true,0)})
local rocking=threads[#threads]
step(rocking)
check(lastGrip.bone==42 and lastGrip.x==0 and lastGrip.z==0,'weapon uses its grip origin instead of bottle offsets')
while physics<3 do step(rocking) end
local weapon=entities[5]
weapon.pos=vector3(1.5,0,0.16) weapon.rot=vector3(12,73,41)
finish(rocking)
check(weapon.pos.x==1.5 and weapon.rot.z==41,'physics timeout keeps landed weapon position and rotation instead of anchor reset')
check(requests[#requests].values[2].x==1.5 and requests[#requests].values[3].z==41,'owner reports exact final weapon pose to server')
jitter=false
events['rp_inventory:ground']({item('interrupted',false,0)})
local interrupted=threads[#threads] step(interrupted)
events['esx:onPlayerLogout']() finish(interrupted)
check(not next(entities),'logout during hand release deletes prop and ends animation')
events.onResourceStop('rp_inventory')
check(not next(entities) and hint==nil,'resource stop clears props and hint')
modelReady=false
events['rp_inventory:ground']({item('pending')})
local pending=threads[#threads] step(pending)
events['esx:onPlayerLogout']()
modelReady=true finish(pending)
check(not next(entities),'delayed model load cannot create a prop after logout')

local sandwich=item('sandwich',false,0) sandwich.model='prop_sandwich_01'
events['rp_inventory:ground']({sandwich})
finish(threads[#threads])
check(lastGrip.x==0.025 and lastGrip.z==-0.01,'flat sandwich sits forward in the palm with a separate profile')
events['rp_inventory:ground']({})

local generic=item('generic',false,0) generic.model='prop_cs_cardbox_01'
events['rp_inventory:ground']({generic}) finish(threads[#threads])
check(lastGrip.x==0.02 and lastGrip.z==-0.015,'unlisted ESX props use the default hand profile')
events['rp_inventory:ground']({})

missingGrip=true
events['rp_inventory:ground']({item('wrist-fallback',false,0)}) finish(threads[#threads])
check(lastGrip.bone==43 and math.abs(lastGrip.x-0.12)<0.0001 and lastGrip.y==0.02,'missing prop bone compensates wrist anchor towards fingers')
events['rp_inventory:ground']({})
missingHand=true
local before=attached
events['rp_inventory:ground']({item('no-hand',false,0)}) finish(threads[#threads])
check(attached==before,'missing skeleton never attaches object to ped root')
events.onResourceStop('rp_inventory')
check(not next(entities),'all grip paths clean up their local props')
missingGrip,missingHand=false,false
local shirt=item('shirt',false,10)
shirt.model='prop_ld_shirt_01' shirt.fallbackModel='prop_paper_bag_small'
events['rp_inventory:ground']({shirt}) finish(threads[#threads])
check(entities[serial].model=='prop_ld_shirt_01' and entities[serial].collision,'clothing prop streams with ground collision')
events['rp_inventory:ground']({})
function IsModelInCdimage(hash) return hash~='missing_clothing' end
shirt.id='missing-shirt' shirt.model='missing_clothing'
events['rp_inventory:ground']({shirt}) finish(threads[#threads])
check(entities[serial].model=='prop_paper_bag_small','unavailable garment model uses the configured small bag')
events['rp_inventory:ground']({})
function HasModelLoaded(hash) return hash~='slow_clothing' end
shirt.id='slow-shirt' shirt.model='slow_clothing'
events['rp_inventory:ground']({shirt}) finish(threads[#threads])
check(entities[serial].model=='prop_paper_bag_small','timed-out garment load also falls back after bounded wait')
events['rp_inventory:ground']({})
shirt.id='cancelled-shirt'
events['rp_inventory:ground']({shirt})
local cancelled=threads[#threads] step(cancelled)
events['esx:onPlayerLogout']() finish(cancelled)
check(not next(entities),'cancelled garment model load never spawns a late fallback')
print(('PASS: %d ground client streaming/input/animation/cleanup assertions'):format(passed))
