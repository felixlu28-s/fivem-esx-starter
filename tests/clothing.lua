-- Real clothing + inventory coordinator. Deterministic SQL host exercises failures,
-- animation acknowledgements, lock contention and character changes during awaits.
local root, checks = 'server-data/resources/[custom]/rp_inventory/', 0
local function check(v, message) assert(v, message) checks = checks + 1 end
for _, file in ipairs({'items','model','clothing_catalog','clothing'}) do dofile(root..'shared/'..file..'.lua') end
local M, db, receipts, skins, api, events, players = Inventory.model, {}, {}, {}, {}, {}, {}
local jsonValues, serial, clock, committed, animations = {}, 0, 0, 0, 0
local mode, onWait, sqlFailure = 'ack', nil, nil
json = { encode=function(value) serial=serial+1 jsonValues[tostring(serial)]=M.copy(value) return tostring(serial) end,
    decode=function(value) return M.copy(jsonValues[value]) end }
local ESX={GetPlayerFromId=function(id) return players[id] and M.copy(players[id]) end, GetUsableItems=function() return {} end}
exports=setmetatable({es_extended={getSharedObject=function() return ESX end}}, {__call=function(_,name,fn) api[name]=fn end})
function GetGameTimer() return clock end
function GetPlayerPed(id) return players[id] and id or 0 end
function GetEntityHealth(id) return players[id] and 200 or 0 end
function GetInvokingResource() return 'rp_test' end
function GetCurrentResourceName() return 'rp_inventory' end
function CreateThread() end
function SetTimeout() end
function DropPlayer() end
function AddEventHandler(name,fn) events[name]=fn end
function RegisterNetEvent(name,fn) events[name]=fn end
function TriggerClientEvent(name,id,token)
    if name=='rp_inventory:clothingAnimate' then
        animations=animations+1
        if mode=='ack' then source=id events['rp_inventory:clothingAck'](token,true)
        elseif mode=='fail' then source=id events['rp_inventory:clothingAck'](token,false)
        elseif mode=='foreign' then source=99 events['rp_inventory:clothingAck'](token,true) end
    end
end
function Wait(ms) clock=clock+ms if onWait then local fn=onWait onWait=nil fn() end end
MySQL={ready=function() end,single={},scalar={},query={}}
MySQL.single.await=function(_,p)
    local row=db[p[1]]
    return row and {id=p[1],kind=row.kind or 'player',label='Test',context=json.encode(row.context or {}),payload=json.encode(row.data),revision=row.revision}
end
MySQL.scalar.await=function(query,p)
    if query:find('SELECT skin') then return skins[p[1]] end
    if query:find('SELECT payload') then return db[p[1]] and json.encode(db[p[1]].data) end
    return receipts[p[1]..':'..p[2]]
end
MySQL.query.await=function(_,p)
    if sqlFailure=='before' then error('expected precommit failure') end
    assert(db[p[4]].revision==p[5])
    if p[7] then assert(db[p[7]].revision==p[8]) end
    db[p[4]].data,db[p[4]].revision=json.decode(p[6]),p[5]+1
    if p[7] then db[p[7]].data,db[p[7]].revision=json.decode(p[9]),p[8]+1 end
    receipts[p[1]..':'..p[2]]=p[3] committed=committed+1
    if sqlFailure=='after' then error('expected lost commit acknowledgement') end
end
dofile(root..'server/store.lua') dofile(root..'server/clothing.lua') dofile(root..'server/exchange.lua')
local S=Inventory.store S.ready=true
S.playable=function(id) return S.player(id)~=nil end
local function player(id,sex,slots,legacy)
    local identifier='char'..id..':same-license'
    players[id]={identifier=identifier,spawned=true,syncInventory=function() end}
    local key='player:'..identifier
    S.players[id]={id=key,identifier=identifier,generation='generation'..id}
    db[key]={revision=0,data=M.empty(slots or 24,25000)}
    if not legacy then db[key].data.clothing={version=1,sex=sex or 0,worn={}} end
    S.load(key) S.player(id)
    return key
end
local a,b=player(1),player(2,1)
local function add(id,product)
    local p=Clothing.products[product]
    return S.forPlayer(id,'clothing:add',function(data) return M.add(data,'clothing_'..p.category,1,{garment={sex=p.sex,label=p.label,product=p.id,skin=M.copy(p.skin)},custom={serial='kept'}}) end)
end
local function use(id,slot)
    return S.forPlayer(id,'clothing:use',function(data) return M.clothingUse(data,slot) end)
end
check(add(1,'top_0_0'),'catalog garment grant')
local garmentId=S.cache[a].data.items['1'].metadata.garment.id
check(type(garmentId)=='string' and #garmentId>0,'server mints unique item identity')
local beforeClock=clock
check(use(1,1),'wear item')
check(clock-beforeClock>=1800,'early ACK cannot skip minimum animation time')
check(S.cache[a].data.items['1'].count==1 and S.cache[a].data.clothing.worn.top==garmentId,'wear keeps physical item')
check(M.clothingDisplay(S.cache[a].data,S.cache[a].data.items['1']).worn,'equipped badge derives from root map')
local beforeAnimations=animations
check(S.forPlayer(1,'sort',function(data) return M.move(data,data,1,5,1) end),'sort worn item')
check(animations==beforeAnimations and S.cache[a].data.clothing.worn.top==garmentId,'sorting never undresses')
local transferRequest=S.token('transfer')
local function transfer(request,guard)
    return S.mutate({a,b},players[1].identifier,request,'transfer-top',nil,guard or function() return true end,
        function(copies) return M.move(copies[a],copies[b],5,1,1) end)
end
local beforeWrites=committed
onWait=function()
    check(S.cache[a].data.items['5']~=nil and not S.cache[b].data.items['1'],'item remains at source during animation')
    check(S.locks[a] and S.locks[b],'both stores locked throughout animation')
    local ok,reason=S.forPlayer(2,'concurrent',function(data) return M.add(data,'rp_water',1) end)
    check(not ok and reason=='busy','concurrent destination write denied')
    check(committed==beforeWrites,'no commit before animation completes')
end
check(transfer(transferRequest),'transfer commits after animation')
check(not S.cache[a].data.clothing.worn.top and not S.cache[b].data.clothing.worn.top,'sender undressed, recipient not auto-equipped')
local moved=S.cache[b].data.items['1']
check(moved.metadata.garment.id==garmentId and moved.metadata.custom.serial=='kept','full garment metadata preserved across character transfer')
local oldCount=animations
check(transfer(transferRequest),'lost response replay succeeds')
check(animations==oldCount and committed==beforeWrites+1,'replay neither animates nor transfers twice')
local ok,reason=use(2,1)
check(not ok and reason=='clothing_wrong_model','opposite model cannot wear, can still own/trade')
check(S.forPlayer(1,'another',function(data) return M.add(data,'clothing_hat',2) end),'ESX name-only grant assigns catalog variants')
check(S.cache[a].data.items['1'].metadata.garment.id~=S.cache[a].data.items['2'].metadata.garment.id,'multiple nonstacked grants get distinct IDs')
check(use(1,1),'hat equip')
local hatId=S.cache[a].data.clothing.worn.hat
mode='fail'
check(not S.forPlayer(1,'remove-failed',function(data) return M.remove(data,'clothing_hat',1,nil,1) end),'failed animation prevents removal')
check(S.cache[a].data.clothing.worn.hat==hatId and S.cache[a].data.items['1'],'failed animation retains original outfit and item')
mode='foreign'
check(not use(1,1),'another source cannot acknowledge animation')
check(not S.locks[a],'timeout releases lock')
mode='ack'
sqlFailure='before'
check(not use(1,1),'SQL failure rolls outfit back')
check(S.cache[a].data.clothing.worn.hat==hatId,'persisted hat remains authoritative after failure')
sqlFailure='after'
check(not use(1,1),'lost commit acknowledgement reports DB error')
check(not S.cache[a].data.clothing.worn.hat,'ambiguous acknowledgement resolves actual committed outfit')
sqlFailure=nil
check(use(1,1),'hat can be equipped again')
onWait=function() S.players[1]={id=a,identifier=players[1].identifier,generation='new-session'} end
check(not use(1,1),'session change during animation cancels mutation')
check(S.cache[a].data.clothing.worn.hat==hatId,'session change does not strip item')
local c=player(3,0,24,true)
skins[players[3].identifier]=json.encode({sex=0,torso_1=0,torso_2=2,arms=0,tshirt_1=15,pants_1=1,pants_2=3,shoes_1=2,shoes_2=1,helmet_1=-1})
check(S.initializeClothing(3),'one-time creator outfit import')
check(M.count(S.cache[c].data,'clothing_top')==1,'creator top becomes exactly one item')
local initialWrites=committed
check(S.initializeClothing(3) and committed==initialWrites,'repeated login cannot duplicate creator garments')
local resolved=api.rpResolveClothing(players[3].identifier,{sex=0,hair_1=42,nose_1=7})
check(resolved.hair_1==42 and resolved.nose_1==7 and resolved.pants_2==3,'skin overlay retains face/hair and exact garment texture')
S.cache[c]=nil
resolved=api.rpResolveClothing(players[3].identifier,{sex=0,hair_1=42})
check(resolved.torso_2==2,'cold reload derives outfit from durable provider row')
check(not S.cache[c],'offline selection does not retain unused character inventories')
local d=player(4,1,1,true)
skins[players[4].identifier]=json.encode({sex=1,torso_1=0,pants_1=0,shoes_1=0})
check(not S.initializeClothing(4),'full initial inventory defers migration')
check(not S.cache[d].data.clothing and not next(S.cache[d].data.items),'no partial starter grant on capacity failure')
local purchase='clothing_purchase_test'
local p=Clothing.products.glasses_1_0
check(api.rpExchange(2,purchase,{},{{name='clothing_glasses',count=1,metadata={garment={sex=1,label=p.label,product=p.id,skin=p.skin}}}},function() return true end),'commerce exchange retains trusted garment metadata')
local bought=S.cache[b].data.items['2']
check(bought.metadata.garment.product==p.id and bought.metadata.garment.sex==1,'purchase variant preserved')
check(api.rpExchange(2,purchase,{},{{name='clothing_glasses',count=1,metadata={garment={sex=1,label=p.label,product=p.id,skin=p.skin}}}},function() return true end),'purchase receipt idempotent')
check(M.count(S.cache[b].data,'clothing_glasses')==1,'purchase retry grants only one item')
-- Exercise actual NUI routes and their view guards, not only S.forPlayer.
local callbacks, coordinates, health, grants = {}, {}, {}, {}
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
function RegisterCommand() end
function GetEntityCoords(id) return coordinates[id] or {x=0,y=0,z=1} end
function GetEntityHeading() return 0 end
function GetPlayerRoutingBucket() return 0 end
function GetEntityHealth(id) return health[id] or (players[id] and 200 or 0) end
local originalClientEvent = TriggerClientEvent
function TriggerClientEvent(name, id, payload, ...)
    grants[#grants+1] = {name=name,source=id,payload=payload}
    originalClientEvent(name,id,payload,...)
end
dofile(root..'server/ground.lua') dofile(root..'server/actions.lua')
local sender, recipient = player(11), player(12)
check(add(11,'top_0_0') and use(11,1),'network clothing fixture is worn')
local function openView(id)
    clock=clock+2000
    local reply=callbacks['rp_inventory:open'](id)
    assert(reply.ok)
    return reply.inventory
end
local function packet(id, action, extra)
    local snap=S.snapshot(id)
    local result={session=snap.session,request=S.token('ui'),action=action,from='own',slot=1,count=1,
        ownRevision=snap.own.revision,externalRevision=snap.external and snap.external.revision}
    for k,v in pairs(extra or {}) do result[k]=v end
    return result
end
local function action(id,p)
    clock=clock+2000
    return callbacks['rp_inventory:action'](id,p)
end
local function closeView(id) source=id events['rp_inventory:close']() end
openView(11)
local undress=packet(11,'use')
onWait=function()
    closeView(11)
    check(S.snapshot(11)==nil,'I closes the view immediately during clothing animation')
    local forged=M.copy(undress) forged.request=S.token('after-close')
    check(action(11,forged).error=='session_expired','closed view cannot authorize a new action')
    check(S.cache[sender].data.clothing.worn.top~=nil,'old outfit remains until animation commit')
end
check(action(11,undress).ok and not S.cache[sender].data.clothing.worn.top,'closing I does not cancel accepted undress')
openView(11)
local dress=packet(11,'use')
onWait=function()
    closeView(11) openView(11)
    check(action(11,packet(11,'use')).error=='busy','reopening does not bypass active store lock')
end
check(action(11,dress).ok and S.cache[sender].data.clothing.worn.top,'closing and reopening does not cancel dressing')

local receivers=callbacks['rp_inventory:recipients'](11,S.snapshot(11).session)
local receiverToken
for _, candidate in ipairs(receivers.recipients) do if candidate.label:find('#12',1,true) then receiverToken=candidate.token end end
check(receiverToken~=nil,'nearby recipient uses server-issued capability')
local give=packet(11,'give',{recipient=receiverToken})
local originalMetadata=M.copy(S.cache[sender].data.items['1'].metadata)
onWait=function() closeView(11) end
check(action(11,give).ok,'giving worn clothes continues after inventory closes')
check(not S.cache[sender].data.items['1'] and M.canonical(S.cache[recipient].data.items['1'].metadata)==M.canonical(originalMetadata),'give transfers metadata exactly once after undress')

check(add(11,'pants_0_0') and use(11,1),'drop fixture is worn')
local realTime, timeBase, clockBase=os.time,os.time(),clock
os.time=function() return timeBase+math.floor((clock-clockBase)/1000) end
openView(11)
local droppedMetadata=M.copy(S.cache[sender].data.items['1'].metadata)
onWait=function() closeView(11) end
check(action(11,packet(11,'drop')).ok,'drop waits for undress but survives closed view')
local ground
for _,e in ipairs(grants) do if e.name=='rp_inventory:ground' and e.source==11 then ground=e.payload end end
check(ground and #ground==1 and ground[1].model=='prop_ld_jeans_01' and ground[1].fallbackModel=='prop_paper_bag_small','server publishes clothing prop with a small-bag fallback')
check(ground[1].age==0,'clothing drop starts its throw/lifetime after undress, not before animation')
check(ground[1].label==droppedMetadata.garment.label and ground[1].metadata==nil,'public prop contains garment label but no private metadata')
clock=clock+2000
local claim=callbacks['rp_inventory:pickupStart'](11,ground[1].id)
check(claim.ok,'garment drop can be reserved')
clock=clock+2000
check(callbacks['rp_inventory:pickupFinish'](11,claim.token).ok,'garment picked up normally')
check(M.canonical(S.cache[sender].data.items['1'].metadata)==M.canonical(droppedMetadata),'ground roundtrip preserves all garment metadata')
os.time=realTime

check(use(11,1),'rewear pants for interruption checks')
openView(11)
onWait=function() closeView(11) health[11]=0 end
check(not action(11,packet(11,'use')).ok and S.cache[sender].data.clothing.worn.pants,'death still cancels after UI closes')
health[11]=nil
openView(11)
onWait=function() closeView(11) S.players[11]={id=sender,identifier=players[11].identifier,generation='reconnect'} end
check(not action(11,packet(11,'use')).ok and S.cache[sender].data.clothing.worn.pants,'new character session still cancels after UI closes')
local box='container:rp_test:clothes'
db[box]={revision=0,data=M.empty(24,25000),kind='container',context={x=0,y=0,z=1,bucket=0}}
S.load(box).kind='container'
local allowed=true
check(S.registerContainer('rp_test','clothes',{label='Kleiderkiste',slots=24,capacity=25000,coords={x=0,y=0,z=1},
    authorize=function() return allowed end})==box,'trusted external wardrobe fixture')
check(S.openContainer('rp_test',11,box),'open external wardrobe')
onWait=function() closeView(11) end
check(action(11,packet(11,'move',{to='external',target=1})).ok,'external transfer finishes undressing after I closes')
check(not S.cache[sender].data.items['1'] and M.canonical(S.cache[box].data.items['1'].metadata)==M.canonical(droppedMetadata),'external transfer retains garment metadata')
check(S.openContainer('rp_test',11,box),'reopen external wardrobe')
check(action(11,packet(11,'move',{from='external',to='own',target=1})).ok and use(11,1),'return garment and wear again')
onWait=function() closeView(11) coordinates[11]={x=10,y=0,z=1} end
check(not action(11,packet(11,'move',{to='external',target=1})).ok and S.cache[sender].data.clothing.worn.pants,'container distance still enforced after closing')
coordinates[11]=nil
check(S.openContainer('rp_test',11,box),'open authorized wardrobe again')
onWait=function() closeView(11) allowed=false end
check(not action(11,packet(11,'move',{to='external',target=1})).ok and S.cache[sender].data.items['1'],'container permission revocation still enforced after closing')
allowed=true
openView(11)
receivers=callbacks['rp_inventory:recipients'](11,S.snapshot(11).session)
for _,candidate in ipairs(receivers.recipients) do if candidate.label:find('#12',1,true) then receiverToken=candidate.token end end
onWait=function() closeView(11) coordinates[12]={x=10,y=0,z=1} end
check(not action(11,packet(11,'give',{recipient=receiverToken})).ok and S.cache[sender].data.clothing.worn.pants,'recipient distance still enforced after closing')
coordinates[12]=nil
for _,cat in ipairs(Clothing.order) do
    check(Inventory.items['clothing_'..cat].dropModel~='prop_cs_rag_01','clothing never uses generic rag: '..cat)
end
check(Inventory.items.clothing_chain.dropModel=='prop_paper_bag_small','jewelry without matching prop uses a small bag')
print(('PASS: %d clothing ownership / animation / transaction / persistence checks'):format(checks))
