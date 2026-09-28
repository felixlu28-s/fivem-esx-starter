-- Deterministic 2,000-session workload of the real ammo handlers.
-- In-memory transaction stub: operation counts, NOT an FXServer/SQL/network load test.
local base='server-data/resources/[custom]/rp_inventory/'
dofile(base..'shared/items.lua') dofile(base..'shared/model.lua')
local M=Inventory.model
local callbacks,events,threads,challenges,logs={},{},{},{},{}
local clock,writes,serial,cancelled=10000,0,0,false
local S={players={},cache={}}
Inventory.store=S
function S.player(id) return S.players[id] end
function S.live(id,session) return S.players[id]==session end
function S.playable(id) return S.players[id]~=nil end
function S.token(prefix) serial=serial+1 return prefix..'-'..serial end
function S.mutate(ids,_,_,_,_,guard,transform)
    if not guard() then return false end
    local row=S.cache[ids[1]]
    local copies={[ids[1]]=M.copy(row.data)}
    local ok,err=transform(copies)
    if not ok or not guard() then return false,err end
    row.data=copies[ids[1]] row.revision=row.revision+1 writes=writes+1
    S.weaponState(tonumber(ids[1]))
    return true
end
function GetGameTimer() return clock end
function joaat(name) return name=='WEAPON_PISTOL' and 11 or 12 end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) return coroutine.yield(ms) end
function CancelEvent() cancelled=true end
function TriggerClientEvent(name,id,gen,nonce)
    if name=='rp_inventory:ammoAudit' then challenges[id]={generation=gen,nonce=nonce,at=clock} end
end
function TriggerEvent(name,id,reason) logs[#logs+1]={name=name,id=id,reason=reason} end
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
dofile(base..'server/weapons.lua')
local passed=0
local function check(value,message) assert(value,message) passed=passed+1 end
local function emit(name,id,...) source=id events[name](...) end
local batches={}
for id=1,2000 do
    local key=tostring(id)
    S.players[id]={id=key,identifier='char1:fixture'..id,generation='session'..id}
    local data=M.empty()
    assert(M.add(data,'WEAPON_CARBINERIFLE',1))
    assert(M.add(data,'ammo_rifle',90))
    S.cache[key]={revision=0,data=data}
    S.weaponState(id)
end
local begun=os.clock()
for magazine=1,2 do
    for id=1,2000 do
        local prior=batches[id]
        batches[id]=callbacks['rp_inventory:ammoBatch'](id,'WEAPON_CARBINERIFLE','load-'..magazine..'-'..id,
            prior and {ammo='ammo_rifle',token=prior.token,spent=30})
        check(batches[id].ok and batches[id].count==30,'whole server can prepay magazine')
    end
    for round=1,30 do
        clock=clock+100
        for id=1,2000 do
            cancelled=false events.weaponDamageEvent(id,{weaponType=12,hitGlobalIds={1,2}})
            check(not cancelled,'paid damage allowed including event with multiple victims')
        end
    end
end
check(writes==4000,'120,000 damage events use 4,000 commits instead of 120,000')
local elapsed=os.clock()-begun
local before=writes
cancelled=false events.weaponDamageEvent(1,{weaponType=12})
check(cancelled and logs[#logs].reason=='damage_without_paid_ammo','unpaid damage cancelled and flagged')
local function step(ms)
    clock=clock+ms
    local ok,err=coroutine.resume(threads[1]) assert(ok,err)
end
step(0)
local histogram={}
for _=1,35 do
    step(1000)
    local n=0
    for id,challenge in pairs(challenges) do
        if challenge.at==clock then n=n+1 end
        local batch=batches[id]
        emit('rp_inventory:ammoReport',id,challenge.generation,
            {ammo_rifle={ammo='ammo_rifle',token=batch.token,spent=30}},
            {ammo_pistol=0,ammo_rifle=30},challenge.nonce,S.cache[tostring(id)].revision,0)
    end
    histogram[#histogram+1]=n
end
local peak,total=0,0
for _,n in ipairs(histogram) do peak=math.max(peak,n) total=total+n end
check(total>=2000 and peak<400,'random audit deadlines distribute 2,000 sessions')
check(writes==before,'all periodic reports and audits perform zero transactions')
-- Find a fresh scheduled challenge; test excess, replay, stale revisions, malformed counts.
local function challengeFor(id)
    local previous=challenges[id] and challenges[id].nonce
    for _=1,36 do
        step(1000)
        if challenges[id] and challenges[id].nonce~=previous then return challenges[id] end
    end
    error('no challenge')
end
-- Silence normal sessions in this synthetic portion so their intentionally missing replies do not flood logs.
for id=2,2000 do S.clearWeapons(id) end
local challenge=challengeFor(1)
local logBefore=#logs
emit('rp_inventory:ammoReport',1,challenge.generation,{}, {ammo_pistol=0,ammo_rifle=999},
    challenge.nonce,S.cache['1'].revision,0)
check(#logs==logBefore+1 and logs[#logs].reason=='native_excess','same-revision native excess is flagged')
emit('rp_inventory:ammoReport',1,challenge.generation,{}, {ammo_pistol=0,ammo_rifle=999},
    challenge.nonce,S.cache['1'].revision,0)
check(#logs==logBefore+1,'nonce replay cannot issue another audit result')
challenge=challengeFor(1) logBefore=#logs
emit('rp_inventory:ammoReport',1,challenge.generation,{}, {ammo_pistol=0,ammo_rifle=999},
    challenge.nonce,S.cache['1'].revision-1,0)
check(#logs==logBefore,'stale inventory revision is not accused of native mismatch')
local count=M.count(S.cache['1'].data,'ammo_rifle')
clock=clock+1000
emit('rp_inventory:ammoReport',1,'session1',{ammo_rifle={ammo='ammo_rifle',token=batches[1].token,spent=-30}})
check(M.count(S.cache['1'].data,'ammo_rifle')==count and writes==before,'negative/spoofed reports never create refunds')
print(('PASS: %d ammo checks; 2,000 sessions, 120,000 damage events, 4,000 commits; RAM fixture %.3fs, audit peak %d/s')
    :format(passed,elapsed,peak))
