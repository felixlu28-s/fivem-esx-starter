-- Actual common controller and protection API; no server/network activity.
math.randomseed(42)
local base = 'server-data/resources/[custom]/rp_core/'
local passed, now, owner = 0, 0, 'rp_shop_test'
local function check(v, label) assert(v, label) passed = passed + 1 end
local api, events, threads, peds, speech, motions = {}, {}, {}, {}, {}, {}
local loaded, paused, ready = true, false, true
local player = { pos = {x=0,y=0,z=0}, model='player', player=true, male=true, interior=1 }
peds[1] = player
function GetCurrentResourceName() return 'rp_core' end
function GetInvokingResource() return owner end
function GetGameTimer() return now end
function PlayerPedId() return 1 end
function DoesEntityExist(ped) return peds[ped] ~= nil end
function GetEntityModel(ped) return peds[ped].model end
function GetEntityCoords(ped) return peds[ped].pos end
function IsEntityAPed(ped) return peds[ped] ~= nil end
function IsPedAPlayer(ped) return peds[ped].player == true end
function NetworkGetEntityIsNetworked(ped) return peds[ped].network == true end
function IsEntityDead(ped) return peds[ped].dead == true end
function IsPedMale(ped) return peds[ped].male == true end
function IsPauseMenuActive() return paused end
function GetInteriorFromEntity(ped) return peds[ped].interior end
function HasEntityClearLosToEntity(ped) return not peds[ped].hidden end
function IsAnySpeechPlaying(ped) return peds[ped].speaking == true end
function PlayPedAmbientSpeechNative(ped, line, params)
    speech[#speech+1] = {ped=ped,line=line,time=now}
    check(params=='SPEECH_PARAMS_STANDARD','speech does not force-interrupt existing ambient dialogue')
end
function TaskLookAtEntity(ped, target, duration) check(target==1 and duration<=2500,'brief eye contact targets local visitor') end
function TaskClearLookAt() end
function RequestAnimDict() end
function HasAnimDictLoaded() return ready end
function RemoveAnimDict() end
function StopAnimTask(ped) if peds[ped] then peds[ped].motion=nil end end
function TaskPlayAnim(ped, dict, clip, _, _, duration, flags)
    check(peds[ped] and flags==48 and duration<=3000,'bounded upper-body gesture preserves primary idle and anchor')
    local m={ped=ped,dict=dict,clip=clip,time=now}
    motions[#motions+1]=m peds[ped].motion=m
end
function DeleteEntity(ped) peds[ped]=nil end
function AddEventHandler(name, fn) events[name]=events[name] or {} table.insert(events[name],fn) end
local function emit(name, arg) for _,fn in ipairs(events[name] or {}) do fn(arg) end end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) return coroutine.yield(ms) end
local function advance(ms)
    local untilAt=now+ms
    repeat
        now=now+50
        for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and now>=t.wake then
            local ok, delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
        end end
    until now>=untilAt
end
exports=setmetatable({es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end}},
    {__call=function(_,name,fn) api[name]=fn end})
dofile(base..'shared/npcs.lua')
dofile(base..'client/npcs.lua')
-- Load real protection API; ambient density/cleanup loops are outside this test.
local scheduler=CreateThread
CreateThread=function() end
dofile(base..'client/world.lua')
CreateThread=scheduler
local function npc(id, male)
    peds[id]={pos={x=2,y=0,z=0},model='clerk_'..id,male=male,interior=1}
    check(api.rpProtectPed(id),'normal/future protected NPC automatically registered')
end
local function greeted(id)
    local n=0 for _,s in ipairs(speech) do if s.ped==id and s.line=='GENERIC_HI' then n=n+1 end end return n
end
npc(2,true)
advance(3000)
check(greeted(2)==1 and motions[1].clip=='gesture_hello','future NPC receives generic greeting without commerce-specific setup')
advance(6000)
check(greeted(2)==1 and peds[2].motion==nil,'one greeting per visit and temporary gesture ends')
local before=#motions
advance(66000)
check(#motions>before and greeted(2)==1,'lingering visitor gets occasional gestures without repeated greetings')

owner='rp_other'
check(not api.rpReactNpc(2,'acknowledge'),'another resource cannot force service dialogue')
check(not api.rpProtectPed(2) and not api.rpConfigureNpc(2,{paused=true}) and not api.rpReleasePed(2),'another resource cannot steal or alter a protected NPC')
owner='rp_shop_test'
check(not api.rpReactNpc(2,'arbitrary'),'unknown dialogue action rejected')
check(api.rpReactNpc(2,'acknowledge'),'owner can queue service acknowledgement')
advance(12000)
check(speech[#speech].line=='GENERIC_THANKS','service gesture and speech use shared controller')
check(not api.rpConfigureNpc(2,{profile='missing'}) and not api.rpConfigureNpc(2,{paused=1}),'invalid profile/options rejected')
check(not api.rpProtectPed(1),'player is never a social NPC')
peds[3]={pos={x=2,y=0,z=0},model='network',network=true}
check(not api.rpProtectPed(3),'network-owned peds are not locally re-tasked') peds[3]=nil

check(api.rpConfigureNpc(2,{profile='shop',key='store:stable',paused=true}),'normal shop profile configurable by its owner')
before=#motions local said=#speech
advance(70000)
check(#motions==before and #speech==said,'editor pause suppresses social activity')
api.rpConfigureNpc(2,{paused=false})
advance(3000)
check(greeted(2)==2,'normal shop greets after leaving editor')
check(api.rpReleasePed(2),'release unregisters social presentation') peds[2]=nil
npc(4,false)
api.rpConfigureNpc(4,{profile='shop',key='store:stable'})
advance(3000)
check(greeted(4)==0,'stable key retains greeting cooldown across stream/model replacement')
api.rpReleasePed(4) peds[4]=nil

npc(5,false)
peds[5].hidden=true
said=#speech advance(3000)
check(#speech==said,'no greeting through a wall')
peds[5].hidden=false peds[5].interior=2
advance(3000) check(#speech==said,'different interiors do not greet through a shop wall')
peds[5].interior=1
advance(3000)
check(greeted(5)==1 and motions[#motions].dict=='gestures@f@standing@casual','female shopkeeper uses female gesture set')
player.pos.x=7 -- five metres from ped; still inside
advance(3000)
check(greeted(5)==1,'small movements inside radius do not retrigger greeting')
player.pos.x=11 advance(1500) player.pos.x=0 advance(3000)
check(greeted(5)==1,'brief leave and return respect per-NPC greeting cooldown')
api.rpReleasePed(5) peds[5]=nil

npc(6,true) npc(7,true) peds[7].pos.x=3
advance(9000)
check(greeted(6)==1 and greeted(7)==0,'only nearest visible NPC addresses player instead of a chorus')
player.pos.x=4 advance(9000)
check(greeted(7)==1,'other NPC responds when approached as nearest')
api.rpReleasePed(6) api.rpReleasePed(7) peds[6],peds[7]=nil,nil player.pos.x=0

npc(8,true) ready=false
before=#motions advance(1800)
check(#motions==before,'pending animation load does not apply a nonexistent clip')
api.rpReleasePed(8) peds[8]=nil ready=true advance(3000)
check(#motions==before,'release cancels pending dictionary task without touching deleted ped')
npc(9,true) api.rpConfigureNpc(9,{profile='ammunation'})
advance(9000)
check(motions[#motions].dict=='random@shop_gunstore','Ammu-Nation uses shared controller with its own animation set')
player.dead=true said=#speech before=#motions advance(70000)
check(#speech==said and #motions==before,'dead player is not addressed') player.dead=false
paused=true advance(3000) check(#speech==said,'pause menu suppresses greetings') paused=false
loaded=false emit('esx:onPlayerLogout') advance(3000)
check(#speech==said and peds[9].motion==nil,'logout stops animation and social scheduling')
loaded=true emit('onResourceStop','rp_shop_test') advance(3000)
check(not peds[9] and #speech==said,'owner stop cleans social records and protected peds')
owner='rp_future' npc(10,true) advance(3000)
emit('onResourceStop','rp_core') said=#speech advance(3000)
check(#speech==said and peds[10].motion==nil,'core stop cancels remaining social work')
print(('PASS: %d shared NPC interaction/ownership/cleanup assertions'):format(passed))
