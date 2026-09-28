-- Client native bridge: item/session gates, call routing, camera lifetime and focus.
local path='server-data/resources/[custom]/rp_phone/client/apps.lua'
local tests,clock,hasPhone,dead,ped,threads=0,0,true,false,10,{}
local routes,events,volumes,targets,serverEvents,cameras={},{},{},{},{},{}
local target,typing,lastEvent,syncs,rings,nextCamera=0,false,nil,0,0,100
local lastLens,lastFov
local function check(condition,message) tests=tests+1 assert(condition,message) end
local vectorMeta={__sub=function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},getmetatable(a)) end,
    __len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end}
local function vec(x,y,z) return setmetatable({x=x,y=y,z=z},vectorMeta) end
exports={es_extended={getSharedObject=function() return {
    IsPlayerLoaded=function() return true end,
    GetPlayerData=function() return {inventory={{name='phone',count=hasPhone and 1 or 0}}} end} end},
    rp_ui={rpRegisterAction=function(_,name,fn) routes[name]=fn end,
    rpSetTextInput=function(_,value) typing=value return true end,
    rpPhoneEvent=function(_,data) lastEvent=data end}}
lib={callback={await=function(name) if name=='rp_phone:sync' then syncs=syncs+1 end return {ok=true} end}}
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),at=clock} end
function Wait(ms) coroutine.yield(ms) end
local function tick(ms)
    clock=clock+ms
    for _,t in ipairs(threads) do if t.at<=clock and coroutine.status(t.co)~='dead' then
        local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.at=clock+(delay or 0)
    end end
end
function GetGameTimer() return clock end
function GetCurrentResourceName() return 'rp_phone' end
function PlayerPedId() return ped end
function PlayerId() return 0 end
function GetPlayerServerId(id) return id+1 end
function GetPlayerPed(id) return id+10 end
function IsEntityDead() return dead end
function GetActivePlayers() return {0,1,2} end
function GetEntityCoords(entity) return vec(entity==10 and 0 or entity==11 and 1 or 100,0,0) end
function MumbleGetTalkerProximity() return 5 end
function MumbleClearVoiceTarget() targets={} end
function MumbleSetVoiceTarget(id) target=id end
function MumbleAddVoiceTargetPlayerByServerId(_,id) targets['server:'..id]=true end
function MumbleAddVoiceTargetPlayer(_,id) targets['local:'..id]=true end
function MumbleSetVolumeOverrideByServerId(id,volume) volumes[id]=volume end
function PlaySoundFrontend() rings=rings+1 end
function TriggerServerEvent(name,data) serverEvents[#serverEvents+1]={name=name,data=data} end
function CreateCam() nextCamera=nextCamera+1 cameras[nextCamera]=true return nextCamera end
function DestroyCam(id) check(cameras[id],'Destroy only a live camera') cameras[id]=nil end
function RenderScriptCams() end
function SetCamFov(_,fov) lastFov=fov end
function SetCamCoord() end
function SetCamRot() end
function PointCamAtPedBone() end
function HideHudAndRadarThisFrame() end
local pose=false
PhoneMotion={cameraAnchor=function() return 321,ped end,cameraPose=function(v) pose=v end}
function GetFrameTime() return 0.016 end
function GetDisabledControlNormal() return 0 end
function GetEntityHeading() return 10 end
function SetCamNearClip() end
function PointCamAtCoord() end
function StopCamPointing() end
function SetEntityLocallyInvisible() end
function GetGameplayCamRot() return vec(0,0,0) end
function GetOffsetFromEntityInWorldCoords(entity,x,y,z) lastLens={entity,x,y,z} return vec(x,1+y,1+z) end
function GetPedBoneCoords() return vec(0,0,1) end
dofile('server-data/resources/[custom]/rp_phone/shared/config.lua')
dofile('server-data/resources/[custom]/rp_phone/client/camera.lua')
dofile(path)
PhoneApps.register(function(d) return type(d)=='table' and d.session=='owned-session' end)
check(not routes['rp_phone:action']({session='stolen',action='home',data={}}).ok,'Invalid session refused')
check(not routes['rp_phone:camera']({session='stolen',mode='selfie'}).ok,'Invalid camera session refused')
check(routes['rp_phone:typing']({session='owned-session',active=true}).ok and typing,'Text fields capture game keys')
check(routes['rp_phone:typing']({session='owned-session',active=false}).ok and not typing,'Restore walking')
tick(1) check(syncs==1,'One presence sync on ownership transition')
tick(500) check(syncs==1,'No database/RPC polling every client tick')
local function camera(mode) return routes['rp_phone:camera']({session='owned-session',mode=mode}).ok end
check(camera('rear') and PhoneCamera.active(),'Rear camera opened') tick(1)
source=65535 events['rp_phone:update']({kind='call',call=false})
check(PhoneCamera.active(),'Idle presence sync must not interrupt standalone camera')
local first=PhoneCamera.active()
check(camera('selfie') and PhoneCamera.active()==first,'Lens switch reuses the camera') tick(1)
check(lastLens[1]==321 and lastLens[3]==PhoneConfig.camera.lens.selfie.y,'Selfie lens is anchored to the held prop')
check(pose,'Camera holding pose active')
local count=#threads
check(routes['rp_phone:camera']({session='owned-session',mode='selfie',zoom=3}).ok,'Bounded zoom accepted') tick(1)
check(#threads==count and PhoneCamera.active()==first,'Zoom adds no camera or frame thread')
check(not routes['rp_phone:camera']({session='owned-session',mode='selfie',zoom=100}).ok,'Unbounded zoom rejected')
check(not routes['rp_phone:camera']({session='owned-session',mode='selfie',zoom=0/0}).ok,'NaN zoom rejected')
hasPhone=false tick(500)
check(not PhoneCamera.active() and not next(cameras),'Item loss destroys camera')
check(not camera('rear'),'No camera without phone')
hasPhone=true tick(500)
check(syncs==2,'Regained phone synchronizes presence')
check(camera('selfie'),'Selfie restored') ped=20 tick(1)
check(not PhoneCamera.active(),'Ped replacement cancels camera loop') ped=10
local call={id='call-test',self=1,backend='mumble',members={
    {id=1,joined=false,muted=false},{id=8,joined=true,muted=false}}}
source=0 events['rp_phone:update']({kind='call',call=call})
check(not PhoneApps.call,'Local forged call ignored')
source=65535 events['rp_phone:update']({kind='call',call=call}) tick(500)
check(rings==1 and target==0,'Ringing never joins voice')
call.members[1].joined=true tick(500)
check(target==30 and targets['server:8'] and volumes[8]==1,'Accepted call gets distant voice target')
check(targets['local:1'] and not targets['local:2'],'Nearby game voice retained; far unrelated player excluded')
call.members[1].muted=true tick(500)
check(not targets['server:8'] and targets['local:1'],'Call mute stops sending to caller, preserves world speech')
check(not routes['rp_phone:signal']({call='other'}).ok,'Cross-call signalling rejected')
check(routes['rp_phone:signal']({call='call-test'}).ok,'Bound signalling forwarded')
check(camera('selfie'),'Camera during call')
PhoneApps.close()
check(not PhoneCamera.active() and not typing and PhoneApps.call,'Putting phone away ends video, keeps audio call')
check(serverEvents[#serverEvents].name=='rp_phone:cameraOff','Server told to remove outgoing video')
events['rp_phone:update']({kind='call',call=false})
check(target==0 and volumes[8]==-1 and not PhoneApps.call,'Hangup restores Mumble target/volume')
check(camera('rear'),'Camera can reopen') dead=true tick(1)
check(not PhoneCamera.active(),'Death cancels capture') dead=false
events['esx:onPlayerLogout']()
check(lastEvent.kind=='reset' and not PhoneApps.call,'Logout resets browser call state')
check(camera('rear'),'Camera before resource stop')
events['onResourceStop']('rp_phone') tick(500)
check(not next(cameras) and target==0,'Resource stop has no camera/voice leaks')
print(('phone-apps-client: %d assertions passed'):format(tests))
