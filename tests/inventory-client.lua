-- Direct inventory ammo projection and magazine-sized prepayments on the actual client.
local base,passed='server-data/resources/[custom]/rp_inventory/',0
local function check(v,message) assert(v,message) passed=passed+1 end
dofile(base..'shared/items.lua')
local events,threads,weapons,ammo,clips,sent={},{},{},{},{},{}
local loaded,ped,selected,timer=true,1,11,10000
local held,dead,nui,paused,blocked=false,false,false,false,false
local externalBlock=false
local mounted,tints={},{}
local pendingReply,nextReply=false,nil
local hashes={WEAPON_PISTOL=11,WEAPON_CARBINERIFLE=12,AMMO_PISTOL=101,AMMO_RIFLE=102,COMPONENT_AT_PI_FLSH=201,COMPONENT_AT_PI_SUPP_02=202}
local groups={[11]=101,[12]=102}
exports={es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end,SetPlayerData=function() end} end}}
lib={callback={await=function(name)
    check(name=='rp_inventory:ammoBatch','only batch callback used')
    if pendingReply then coroutine.yield('callback') end
    return nextReply
end}}
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn)
    local old=events[name]
    events[name]=function(...) if old then old(...) end fn(...) end
end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function GetGameTimer() return timer end
function PlayerPedId() return ped end
function PlayerId() return 0 end
function joaat(name) return hashes[name] or 999 end
function GetSelectedPedWeapon() return selected end
function IsEntityDead() return dead end
function IsNuiFocused() return nui end
function IsPauseMenuActive() return paused end
function IsControlPressed() return held and not blocked end
function IsDisabledControlPressed() return held end
function IsPedReloading() return false end
-- GTA blocks this frame even when the second argument is false.
-- Match Cfx Player.DisableFiringThisFrame(), not an enable/disable toggle.
function DisablePlayerFiring() blocked=true end
function HasPedGotWeapon(_,hash) return weapons[hash]==true end
function GiveWeaponToPed(_,hash,count) weapons[hash]=true ammo[groups[hash]]=(ammo[groups[hash]] or 0)+count end
function RemoveWeaponFromPed(_,hash) weapons[hash]=nil end
function RemoveAllPedWeapons() weapons,ammo,clips={},{},{} end
function SetPedAmmoByType(_,group,count) ammo[group]=count end
function GetPedAmmoByType(_,group) return ammo[group] or 0 end
function SetAmmoInClip(_,hash,count) clips[hash]=count end
function GetAmmoInClip(_,hash) return true,clips[hash] or 0 end
function SetPedDropsWeaponsWhenDead() end
function SetWeaponsNoAutoswap() end
function DoesWeaponTakeWeaponComponent() return true end
function GiveWeaponComponentToPed(_,hash,component) mounted[hash]=mounted[hash] or {} mounted[hash][component]=true end
function RemoveWeaponComponentFromPed(_,hash,component) if mounted[hash] then mounted[hash][component]=nil end end
function SetPedWeaponTintIndex(_,hash,tint) tints[hash]=tint end
function SetCurrentPedWeapon(_,hash) selected=hash end
function GetCurrentResourceName() return 'rp_inventory' end
function TriggerServerEvent(name,...) sent[#sent+1]={name=name,values={...}} end
local loop
local function resume(thread)
    if thread==loop then blocked=externalBlock end -- New frame, including other resource guards.
    local ok,result=coroutine.resume(thread) assert(ok,result) return result
end
dofile(base..'client/weapons.lua')
local rev,gen=1,'session-1'
local function state(rounds,pistol,rifle)
    local entries={{name='ammo_pistol',count=rounds},{name='ammo_rifle',count=60}}
    if pistol~=false then entries[#entries+1]={name='WEAPON_PISTOL',count=1,metadata={}} end
    if rifle~=false then entries[#entries+1]={name='WEAPON_CARBINERIFLE',count=1,metadata={}} end
    source=65535 events['rp_inventory:state'](entries,{revision=rev,generation=gen})
end
source=3 events['rp_inventory:state']({{name='WEAPON_PISTOL',count=1}},{revision=1,generation=gen})
check(not weapons[11],'foreign state rejected')
state(40)
check(weapons[11] and weapons[12] and ammo[101]==40 and ammo[102]==60,'weapon wheel mirrors totals')
check(clips[11]==12 and clips[12]==30,'no manual ammo use')
loop=threads[1]
resume(loop)
check(blocked and #threads==1,'idle never prepays')
held=true nextReply={ok=true,token='paid-1',count=12,spent=0,revision=2,generation=gen,ammo='ammo_pistol',remaining=28}
clips[11]=0 -- weapon pool has reserve, but GTA's clip can be empty
resume(loop)
local permit=threads[#threads]
check(permit~=loop and blocked,'only initial magazine waits')
resume(permit) resume(loop)
check(ammo[101]==40 and not blocked,'prepaid magazine remains in native pool')
check(clips[11]==12,'disabled attack and empty clip still obtain exactly one paid magazine')
held=false
externalBlock=true resume(loop)
check(blocked,'paid ammo never overrides another resource firing guard')
externalBlock=false nui=true resume(loop)
check(blocked,'open NUI blocks an otherwise authorized weapon')
nui=false paused=true resume(loop)
check(blocked,'pause menu blocks an otherwise authorized weapon')
paused=false resume(loop)
check(not blocked,'closing UI releases our frame guard without another ammo request')
local calls=#threads
for i=1,11 do
    ammo[101]=ammo[101]-1 clips[11]=12-i timer=timer+140 resume(loop)
    check(not blocked and ammo[101]==40-i,'each round consumed locally without disabling automatic fire')
end
check(#threads==calls and #sent<=1,'eleven shots make no new RPC and at most one periodic report')
rev=3 state(20)
check(ammo[101]==21 and not blocked,'inventory removal preserves only the one remaining prepaid round')
rev=4 state(28)
check(ammo[101]==29,'receiving ammo adds loose reserve without resurrecting spent batch rounds')
ammo[101]=ammo[101]-1 timer=timer+140 resume(loop)
check(blocked and ammo[101]==28,'empty budget gates firing before next batch')
rev=4 state(28)
check(ammo[101]==28,'same revision cannot resurrect spent ammo')
rev=1 state(40)
check(ammo[101]==28,'old snapshot ignored')
ammo[101]=999 resume(loop)
check(ammo[101]==28,'modded native excess corrected')
source=65535 events['rp_inventory:ammoAudit'](gen,'audit-1')
local audit=sent[#sent]
check(audit.name=='rp_inventory:ammoReport' and audit.values[2].ammo_pistol.spent==12 and audit.values[6]>0,'challenge includes cumulative count and correction signal')
events['rp_inventory:ammoAuditResult'](gen,'audit-1')
local messages=#sent
source=5 events['rp_inventory:ammoAudit'](gen,'forged')
check(#sent==messages,'foreign audit rejected')
rev=5 state(5)
check(ammo[101]==5,'inventory removal reduces native reserve')
rev=6 state(1)
timer=timer+1000 held=true
nextReply={ok=true,token='last',count=1,spent=0,revision=7,generation=gen,ammo='ammo_pistol',remaining=0}
resume(loop) permit=threads[#threads]
rev=7 state(0) clips[11]=0
resume(permit)
check(ammo[101]==1 and clips[11]>0,'last paid round survives debit snapshot clearing clip')
held=false ammo[101]=0 clips[11]=0 resume(loop)
check(ammo[101]==0 and blocked,'last round exhausted')
rev=8 state(30) timer=timer+1000 held=true pendingReply=true
nextReply={ok=true,token='late',count=12,spent=0,revision=9,generation=gen,ammo='ammo_pistol',remaining=18}
resume(loop) local delayed=threads[#threads]
check(resume(delayed)=='callback','batch may wait for SQL')
events['esx:onPlayerLogout']()
check(not next(weapons),'logout cleans weapons')
gen='session-2' rev=1 state(6)
pendingReply=false resume(delayed)
check(ammo[101]==6,'old character response ignored')
timer=timer+1000 pendingReply=true
nextReply={ok=true,token='removed',count=6,spent=0,revision=2,generation=gen,ammo='ammo_pistol',remaining=0}
resume(loop) delayed=threads[#threads] resume(delayed)
rev=3 state(6,false)
check(not weapons[11] and ammo[101]==0,'weapon removal clears native pool')
rev=4 state(6) pendingReply=false resume(delayed)
check(ammo[101]==6,'remove/reacquire cannot reuse old reply')
selected=12 timer=timer+1000 held=true
nextReply={ok=true,token='rifle',count=30,spent=0,revision=5,generation=gen,ammo='ammo_rifle',remaining=30}
resume(loop) permit=threads[#threads]
check(blocked and permit~=loop,'rifle has its own batch guard')
resume(permit) resume(loop)
check(not blocked and ammo[102]==60,'rifle releases firing after its paid magazine arrives')
held=false
calls=#threads
for i=1,30 do
    check(not blocked,'rifle can fire the next authorized round')
    ammo[102]=ammo[102]-1 clips[12]=30-i timer=timer+85 resume(loop)
end
check(blocked and ammo[102]==30 and #threads==calls,'full rifle magazine fires without per-shot RPCs then gates')
held=true timer=timer+500
nextReply={ok=true,token='rifle-next',count=30,spent=0,revision=6,generation=gen,ammo='ammo_rifle',remaining=0}
resume(loop) permit=threads[#threads] resume(permit) resume(loop)
check(not blocked and ammo[102]==30 and clips[12]==30,'next rifle magazine resumes firing after empty clip')
held=false nui=true resume(loop) check(blocked,'NUI blocks firing')
nui=false dead=true resume(loop) check(blocked,'death blocks firing')
events.onResourceStop('rp_inventory')
check(not next(weapons),'stop cleanup')

dead=false nui=false source=65535
local first={name='WEAPON_PISTOL',count=1,slot=1,metadata={weaponId='A',components={'COMPONENT_AT_PI_FLSH'},tintIndex=2}}
local second={name='WEAPON_PISTOL',count=1,slot=2,metadata={weaponId='B',components={'COMPONENT_AT_PI_SUPP_02'}}}
local function instances(entries,rev)
    events['rp_inventory:state'](entries,{revision=rev,generation='instances'})
end
instances({first,second},1)
check(mounted[11][201] and not mounted[11][202] and tints[11]==2,'default wheel shows first instance only')
local effect={name='WEAPON_PISTOL',weaponId='B',generation='instances',component='COMPONENT_AT_PI_SUPP_02',install=true}
check(Inventory.selectWeapon(effect) and mounted[11][202] and not mounted[11][201] and tints[11]==0,'equip second copy projects only its components and resets previous tint')
first.slot=4 second.slot=8 instances({first,second},2)
check(mounted[11][202] and not mounted[11][201],'slot moves do not change chosen weapon identity')
Inventory.presentAttachment(effect)
check(not mounted[11][202],'component held back until fitting animation')
instances({first,second},3)
check(not mounted[11][202],'snapshot cannot interrupt attachment presentation')
Inventory.presentAttachment(nil)
check(mounted[11][202],'presentation completion applies saved component')
instances({first},4)
check(not Inventory.selectWeapon(effect) and mounted[11][201] and not mounted[11][202],'giving chosen copy away selects remaining copy without leaked attachments')
instances({first,second},5)
check(not Inventory.selectWeapon({name=effect.name,weaponId='B',generation='stale'}),'old character presentation refused')

local ready,ragdoll,playing,lastAnimation=true,false,false,nil
exports.rp_ui={rpGetView=function() return 'inventory' end,rpClose=function() nui=false end}
function RequestAnimDict() end
function HasAnimDictLoaded() return ready end
function RemoveAnimDict() end
function TaskPlayAnim(ped,dict,clip,blendIn,blendOut,duration,flags)
    playing=true lastAnimation={ped=ped,dict=dict,clip=clip,blendIn=blendIn,blendOut=blendOut,duration=duration,flags=flags}
end
function StopAnimTask() playing=false end
function IsPedRagdoll() return ragdoll end
function DisableControlAction() end
dofile(base..'client/attachments.lua')
Inventory.animateAttachment(effect)
local animation=threads[#threads] resume(animation)
check(Inventory.attachmentBusy and playing and selected==11 and not mounted[11][202],'mount animation equips owned weapon and hides component until mid-animation')
timer=timer+1450 resume(animation)
check(mounted[11][202],'mount animation reveals component at work point')
timer=timer+1100 resume(animation)
check(not Inventory.attachmentBusy and not playing,'animation completion cleans up blocking')
local installAnimation=lastAnimation
second.metadata.components={}
instances({first,second},6)
local removeEffect={name=effect.name,weaponId='B',generation='instances',component=effect.component,install=false}
Inventory.animateAttachment(removeEffect) animation=threads[#threads] resume(animation)
check(Inventory.attachmentBusy and playing and mounted[11][202],'removal temporarily displays committed component on the exact equipped weapon')
check(lastAnimation.dict==installAnimation.dict and lastAnimation.clip==installAnimation.clip
    and lastAnimation.duration==installAnimation.duration and lastAnimation.flags==installAnimation.flags,'removal uses same fitting motion and timing as installation')
timer=timer+1450 resume(animation)
check(not mounted[11][202],'removal releases visual component at the work point')
timer=timer+1100 resume(animation)
check(not Inventory.attachmentBusy and not playing and not mounted[11][202],'removal completion restores authoritative weapon appearance')
second.metadata.components={'COMPONENT_AT_PI_SUPP_02'} instances({first,second},7)
Inventory.animateAttachment(effect) animation=threads[#threads] resume(animation)
instances({first},8) resume(animation)
check(not Inventory.attachmentBusy and mounted[11][201] and not mounted[11][202],'weapon transfer during animation cancels without recreating removed instance')
instances({first,second},9) ready=false
Inventory.animateAttachment(effect) animation=threads[#threads] resume(animation)
events['esx:onPlayerLogout']() ready=true resume(animation)
check(not playing and not next(weapons) and not Inventory.attachmentBusy,'logout during asset wait cannot resurrect weapon or animation')
print(('PASS: %d inventory client batch/audit/lifecycle assertions'):format(passed))
