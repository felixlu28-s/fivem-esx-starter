local base='server-data/resources/[custom]/rp_phone/'
local passed=0
local function check(v,message) assert(v,message) passed=passed+1 end
local now, count, online, health=0,0,true,200
local callbacks, events={},{}
local kvp={} function GetResourceKvpString(k) return kvp[k] end function SetResourceKvp(k,v) kvp[k]=v end
function GetGameTimer() return now end
function GetPlayerPed() return online and 100 or 0 end
function GetEntityHealth() return health end
function AddEventHandler(name,fn) events[name]=fn end
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
exports={es_extended={getSharedObject=function() return {GetPlayerFromId=function(id)
    return online and id==7 and {identifier='char1:test',getInventoryItem=function(name) check(name=='phone','standard ESX phone item checked') return {count=count} end} or nil
end} end}}
MySQL={ready=function() end}
dofile(base..'server/service.lua')
dofile(base..'server/main.lua')
check(not callbacks['rp_phone:open'](7).ok,'cannot open without actual server inventory item')
count=1 now=1000
local first=callbacks['rp_phone:open'](7)
check(first.ok and type(first.session)=='string','possessed phone creates presentation session')
check(callbacks['rp_phone:open'](7).error=='rate_limited','spam open throttled before further work')
now=2000 count=0
check(callbacks['rp_phone:open'](7).error=='phone_missing','discarded phone cannot reuse an earlier open')
now=3000 count=1 health=0
check(not callbacks['rp_phone:open'](7).ok,'dead character cannot open')
now=4000 health=200
check(not callbacks['rp_phone:open'](8).ok,'client cannot pick another source as identity')
local second=callbacks['rp_phone:open'](7)
check(second.ok and second.session~=first.session,'open nonces are not reused')
source=7 events.playerDropped() count=0
check(callbacks['rp_phone:open'](7).error=='phone_missing','disconnect clears source rate record')

-- Real client UI bridge and animations under a deterministic native scheduler.
local threads, routes, commands, handlers, objects={}, {}, {}, {}, {}
local loaded, male, vehicle, dead, ragdoll, ready=true,true,false,false,false,true
local view, ui, focuses, anims, disableCalls=nil,nil,{}, {}, 0
local phoneGestures,activeGesture,stoppedAnims={},nil,0
local objectId, requests, itemCount=0,0,0
local weapon,hasWeapon='WEAPON_PISTOL',true
local invoking='rp_phone'
function GetCurrentResourceName() return 'rp_phone' end
function PlayerPedId() return 100 end
function PlayerId() return 0 end
function DoesEntityExist(id) return id==100 or objects[id]~=nil end
function IsEntityDead() return dead end
function IsPedMale() return male end
function IsPedRagdoll() return ragdoll end
function IsPedInAnyVehicle() return vehicle end
function GetSelectedPedWeapon() return weapon end
function HasPedGotWeapon() return hasWeapon end
function SetCurrentPedWeapon(_,value) weapon=value end
function IsNuiFocused() return view~=nil end
function IsPauseMenuActive() return false end
function IsScreenFadedOut() return false end
function joaat(s) return s end
function GetEntityCoords() return {x=0,y=0,z=1} end
function RequestModel() end
function RequestAnimDict() end
function RemoveAnimDict() end
function SetModelAsNoLongerNeeded() end
function HasModelLoaded() return ready end
function HasAnimDictLoaded() return ready end
function GetPedBoneIndex(_,id) check(id==28422,'phone attaches to physical right hand') return 42 end
function CreateObjectNoOffset(_,_,_,_,networked)
    check(networked,'one visible network phone prop is created while equipped')
    objectId=objectId+1 objects[objectId]=true return objectId
end
function DeleteEntity(id) objects[id]=nil end
function SetEntityCollision() end
function AttachEntityToEntity(_,ped,bone) check(ped==100 and bone==42,'phone prop uses actual bone index') end
function TaskPlayAnim(_,dict,clip,_,_,_,flags)
    check(flags==48 or flags==49,'phone animation retains movement via upper-body secondary task')
    anims[#anims+1]={dict=dict,clip=clip}
end
function StopAnimTask() stoppedAnims=stoppedAnims+1 end
function TaskPlayPhoneGestureAnimation(ped,dict,clip,mask,blendIn,blendOut,looped,holdLast)
    check(ped==100 and next(objects),'gesture uses the existing equipped phone')
    check(mask=='BONEMASK_HEAD_NECK_AND_R_ARM' and blendIn>0 and blendOut>0 and not looped and not holdLast,'gesture blends out on its own without locking movement')
    activeGesture={dict=dict,clip=clip}
    phoneGestures[#phoneGestures+1]=activeGesture
end
function TaskStopPhoneGestureAnimation(ped,blendOut)
    check(ped==100 and blendOut>0,'gesture cleanup blends out on the owning ped')
    activeGesture=nil
end
function PlaySoundFrontend() end
function DisablePlayerFiring() disableCalls=disableCalls+1 end
function DisableControlAction(_,control) check(control~=30 and control~=31,'walking controls never disabled') end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) coroutine.yield(ms) end
function AddEventHandler(name,fn) handlers[name]=handlers[name] or {} table.insert(handlers[name],fn) end
local function emit(name,value) for _,fn in ipairs(handlers[name] or {}) do fn(value) end end
function RegisterCommand(name,fn) commands[name]=fn end
local function advance(ms)
    local deadline=now+ms
    repeat
        now=now+25
        for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and t.wake<=now then
            local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+math.max(25,delay or 0)
        end end
    until now>=deadline
end
json={encode=function(t) return tostring(t.available)..tostring(t.open)..t.session..t.toggleKey end}
exports={
    es_extended={getSharedObject=function() return {
        IsPlayerLoaded=function() return loaded end,
        GetPlayerData=function() return {inventory={{name='phone',count=itemCount}}} end,
    } end},
    rp_core={rpGetBindings=function() return {actions={{id='rp_phone:open',key='UP'}}} end,
        rpRegisterInputAction=function(_,v) check(v.defaultKey=='UP','phone opening uses shared remappable up key') end},
    rp_ui={rpGetView=function() return view end,
        rpOpen=function(_,name,_,lock,options) view=name focuses[#focuses+1]={lock=lock,keyboard=options.keyboardOnly} return true end,
        rpClose=function() view=nil end,
        rpSetPhone=function(_,value) ui=value end,
        rpRegisterAction=function(_,name,fn) routes[name]=fn end},
}
lib={callback={await=function(name)
    check(name=='rp_phone:open','only opening calls server, navigation never does')
    requests=requests+1 return {ok=true,session='client-'..requests}
end}}
dofile(base..'client/animation.lua') dofile(base..'client/main.lua')
advance(300)
check(ui and not ui.available and not ui.open,'no item means no phone preview')
commands.rp_phone() advance(200)
check(requests==0 and not next(objects),'command without item does not animate or open')
itemCount=1 advance(250)
check(ui.available and not ui.open,'owned phone shows only top edge before opening')
emit('rp_core:inputPressed','rp_phone:open') advance(1000)
check(view=='phone' and ui.open and focuses[#focuses].keyboard and focuses[#focuses].lock,'phone takes keyboard-only focus and protects its session')
check(next(objects) and anims[#anims].clip=='cellphone_text_read_base','draw sequence settles into phone idle with one prop')
check(weapon=='WEAPON_UNARMED','phone holsters held weapon instead of overlapping hand props')
local session=ui.session
local n=requests
check(not routes['rp_phone:key']({session='stale',key='left'}).ok,'stale UI navigation rejected')
check(not routes['rp_phone:key']({session=session,key='invalid'}).ok,'unknown gesture rejected')
local holdingCount,stopCount,prop,threadCount=#anims,stoppedAnims,next(objects),#threads
for _,key in ipairs({'left','right','up','down','enter','back'}) do
    check(routes['rp_phone:key']({session=session,key=key}).ok,'direction/tap input accepted') advance(250)
    check(#anims==holdingCount and stoppedAnims==stopCount,'navigation never stops or restarts the holding pose')
    check(next(objects)==prop and objectId==prop,'navigation retains the same attached phone prop')
end
check(#phoneGestures==6 and #threads==threadCount,'navigation uses native gesture layer without idle-restore threads')
routes['rp_phone:key']({session=session,key='left'})
local gestureCount=#phoneGestures
for i=1,15 do routes['rp_phone:key']({session=session,key='right'}) end
check(#phoneGestures==gestureCount,'rapid navigation does not restart gesture every key event')
check(requests==n,'all gestures remain local')
check(routes['rp_phone:close']({session=session}).ok,'back home can close') advance(50)
check(not activeGesture and anims[#anims].clip=='cellphone_text_out','close cancels only gesture before actual put-away')
check(not ui.open and not view,'put-away slides UI down and returns focus')
commands.rp_phone() advance(100)
check(requests==n,'opening during put-away cannot race with prop deletion')
advance(700)
check(not next(objects) and not ui.open,'put-away removes prop after animation')
check(weapon=='WEAPON_PISTOL','put-away restores still-owned original weapon')
local idleWork=disableCalls advance(500)
check(disableCalls==idleWork,'control frame work stops when phone is put away')
male=false commands.rp_phone() advance(1000)
check(anims[#anims].dict=='cellphone@female','female phone idle uses matching dictionary')
holdingCount,stopCount=#anims,stoppedAnims
routes['rp_phone:key']({session=ui.session,key='left'}) advance(250)
check(activeGesture and #anims==holdingCount and stoppedAnims==stopCount and anims[#anims].dict=='cellphone@female','female holding pose survives finger gesture')
itemCount=0 hasWeapon=false advance(300)
check(not ui.available and not view and not next(objects),'losing last phone closes UI and deletes prop')
check(not activeGesture,'item loss stops gesture layer too')
check(weapon=='WEAPON_UNARMED','weapon removed meanwhile is never recreated by phone cleanup')
itemCount=1 vehicle=true commands.rp_phone() advance(1000)
check(anims[#anims].dict=='anim@cellphone@in_car@ps','in-vehicle open selects vehicle animation')
holdingCount,stopCount=#anims,stoppedAnims
routes['rp_phone:key']({session=ui.session,key='enter'}) advance(250)
check(activeGesture and #anims==holdingCount and stoppedAnims==stopCount,'vehicle navigation preserves its seated holding pose')
vehicle=false advance(300)
check(not view and not next(objects),'vehicle transition cannot leave a mismatched phone pose')
check(not activeGesture,'vehicle transition stops gesture layer')
ready=false commands.rp_phone() advance(400)
loaded=false emit('esx:onPlayerLogout') ready=true advance(800)
check(not next(objects) and not view,'logout cancels pending asset load before object creation')
loaded=true ready=false commands.rp_phone() advance(3400)
check(not next(objects) and not view,'missing model/animation times out and releases focus')
ready=true commands.rp_phone() advance(1000)
routes['rp_phone:key']({session=ui.session,key='down'})
emit('onResourceStop','rp_phone') advance(300)
check(not next(objects) and not view,'resource stop removes phone and focus')
check(not activeGesture,'resource stop removes active gesture without delayed idle revival')
print(('PASS: %d phone ownership, keyboard focus, animation and cleanup assertions'):format(passed))
