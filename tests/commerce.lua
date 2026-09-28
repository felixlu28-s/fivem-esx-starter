-- Actual ESX bridge + network handlers + transaction coordinator with a deterministic host.
local base, passed = 'server-data/resources/[custom]/rp_inventory/', 0
local function check(v, message) assert(v, message) passed = passed + 1 end
dofile(base .. 'shared/items.lua') dofile(base .. 'shared/model.lua')
dofile(base .. 'shared/clothing_catalog.lua') dofile(base .. 'shared/clothing.lua')
local M, db, receipts, callbacks, events, api, commands, threads = Inventory.model, {}, {}, {}, {}, {}, {}, {}
local players, coords, buckets, grants, usable = {}, {}, {}, {}, {}
local clock, owner, acl, cancelled, fingerprint = 10000, 'rp_test', false, false, nil
local mutateCount, serial, jsonValues = 0, 0, {}
json = { encode = function(v) serial = serial + 1 jsonValues[tostring(serial)] = M.copy(v) return tostring(serial) end,
    decode = function(v) return M.copy(jsonValues[v]) end }
local ESX = { GetPlayerFromId = function(source) return players[source] and M.copy(players[source]) end,
    GetUsableItems = function() return usable end,
    RegisterUsableItem = function(name, fn) usable[name] = fn end,
    UseItem = function(source, name) if usable[name] then usable[name](source) end end }
exports = setmetatable({ es_extended = { getSharedObject = function() return ESX end } }, { __call = function(_, name, fn) api[name] = fn end })
MySQL = { ready = function() end, single = {}, scalar = {}, query = {}, insert = {} }
MySQL.single.await = function(_, p)
    local r = db[p[1]]
    if r then return { id = r.id, kind = r.kind, label = r.label, payload = json.encode(r.data), context = json.encode(r.context), revision = r.revision } end
end
MySQL.scalar.await = function(_, p) return receipts[p[1] .. ':' .. p[2]] end
MySQL.insert.await = function(_, p)
    if not db[p[1]] then db[p[1]] = { id = p[1], kind = p[2], label = p[3], data = json.decode(p[4]), context = json.decode(p[5]), revision = 0 } end
end
MySQL.query.await = function(_, p)
    mutateCount, fingerprint = mutateCount + 1, p[3]
    assert(db[p[4]].revision == p[5])
    if p[7] then assert(db[p[7]].revision == p[8]) end
    db[p[4]].data, db[p[4]].revision = json.decode(p[6]), p[5] + 1
    if p[7] then db[p[7]].data, db[p[7]].revision = json.decode(p[9]), p[8] + 1 end
    receipts[p[1] .. ':' .. p[2]] = p[3]
end
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
function AddEventHandler(name, fn) events[name] = events[name] or {} table.insert(events[name], fn) end
function RegisterNetEvent(name, fn) AddEventHandler(name, fn) end
function RegisterCommand(name, fn) commands[name] = fn end
function CreateThread(fn) threads[#threads + 1] = fn end
function TriggerEvent() end
function TriggerClientEvent(name, source, payload) grants[#grants + 1] = { name = name, source = source, payload = payload } end
function GetGameTimer() return clock end
function GetPlayerPed(source) return players[source] and source or 0 end
function GetEntityHealth(source) return players[source] and 200 or 0 end
function GetEntityCoords(source) return coords[source] end
function GetPlayerRoutingBucket(source) return buckets[source] or 0 end
function GetInvokingResource() return owner end
function GetCurrentResourceName() return 'rp_inventory' end
function IsPlayerAceAllowed() return acl end
function SetTimeout() end
function DropPlayer() end
function Wait(ms) clock = clock + ms end
function joaat(name) return name == 'WEAPON_PISTOL' and 453432689 or 2210333304 end
function CancelEvent() cancelled = true end
local function emit(name, sourceId, ...)
    source = sourceId
    for _, handler in ipairs(events[name] or {}) do handler(...) end
end
dofile(base .. 'server/store.lua')
local S = Inventory.store
S.ready = true
dofile(base .. 'server/bridge.lua') dofile(base .. 'server/actions.lua')
dofile(base .. 'server/stashes.lua') dofile(base .. 'server/exchange.lua') dofile(base .. 'server/weapons.lua')
local function player(sourceId, character)
    local id = 'player:' .. character
    players[sourceId] = { identifier = character, source = sourceId, spawned = true, syncInventory = function() end }
    coords[sourceId] = { x = 0, y = 0, z = 0 }
    S.players[sourceId] = { id = id, identifier = character, generation = 'gen' .. sourceId }
    db[id] = { id = id, kind = 'player', label = character, context = {}, revision = 0, data = M.empty() }
    S.load(id)
    return id
end

-- Real inventory coordinator + commerce callbacks; SQL and the ESX host are deterministic.
owner = 'rp_commerce'
exports.rp_inventory = setmetatable({}, { __index = function(_, name)
    return function(_, ...) return assert(api[name], name)(...) end
end })
local orders, balances, persisted, debits = {}, {}, {}, 0
local failSave, failCommit, loseCommitReply, dropOnSave, pendingSave = false, false, false, false, nil
local oldSingle, oldScalar, oldInsert, oldQuery = MySQL.single.await, MySQL.scalar.await, MySQL.insert.await, MySQL.query.await
MySQL.update = { await = function(sql, p)
    if sql:find('review_note', 1, true) then
        local row = orders[p[3] .. ':' .. p[4]]
        if row and row.status == 'intent' then row.status, row.review_note = p[1], p[2] return 1 end
        return 0
    end
    local row = assert(orders[p[2] .. ':' .. p[3]]) row.status = p[1] return 1
end }
MySQL.single.await = function(sql, p)
    if sql:find('rp_commerce_orders', 1, true) then
        if p[2] then return M.copy(orders[p[1] .. ':' .. p[2]]) end
        for _, row in pairs(orders) do if row.actor == p[1] and (row.status == 'intent' or row.status == 'paid') then return M.copy(row) end end
        return nil
    end
    return oldSingle(sql, p)
end
MySQL.scalar.await = function(sql, p)
    if sql:find('SELECT accounts FROM users', 1, true) then return persisted[p[1]] and json.encode(persisted[p[1]]) end
    return oldScalar(sql, p)
end
MySQL.insert.await = function(sql, p)
    if sql:find('rp_commerce_orders', 1, true) then
        assert(not orders[p[1] .. ':' .. p[2]], 'duplicate order')
        orders[p[1] .. ':' .. p[2]] = { actor = p[1], request_id = p[2], fingerprint = p[3], payload = p[4], status = 'intent' }
        return 1
    end
    return oldInsert(sql,p)
end
MySQL.query.await = function(sql,p)
    if sql:find('rp_commerce_orders', 1, true) then return {} end
    if failCommit then error('injected commit failure') end
    local result = oldQuery(sql,p)
    if loseCommitReply then loseCommitReply = false error('injected lost commit acknowledgement') end
    return result
end
local ready
MySQL.ready = function(fn) ready = fn end
function GetCurrentResourceName() return 'rp_commerce' end
function ExecuteCommand(command)
    local id = tonumber(command:match('^save (%d+)$'))
    assert(id and players[id], 'standard ESX save command')
    pendingSave = id
end
function Wait(ms)
    clock = clock + ms
    if pendingSave and not failSave then
        local id = pendingSave
        pendingSave = nil
        persisted[players[id].identifier] = M.copy(balances[id])
        local caller = owner owner = 'es_extended'
        emit('esx:playerSaved', 0, id, players[id])
        owner = caller
        if dropOnSave then emit('playerDropped', id) players[id] = nil end
    end
end
local commerceBase = 'server-data/resources/[custom]/rp_commerce/'
dofile(commerceBase .. 'shared/config.lua')
dofile(commerceBase .. 'shared/esx_shops.lua')
dofile(commerceBase .. 'server/service.lua')
dofile(commerceBase .. 'server/purchases.lua')
dofile(commerceBase .. 'server/main.lua')
ready()
check(Commerce.ready, 'catalog and migration readiness checked')
local C = Commerce
local function customer(id, identifier)
    local key = player(id, identifier)
    balances[id] = { money = 1000, bank = 2000 }
    persisted[identifier] = M.copy(balances[id])
    players[id].getAccount = function(account) return { money = balances[id][account] } end
    players[id].removeAccountMoney = function(account, amount)
        assert(amount > 0 and amount <= balances[id][account])
        balances[id][account], debits = balances[id][account] - amount, debits + 1
    end
    players[id].getJob = function() return { name = 'unemployed', grade = 0 } end
    coords[id] = M.copy(C.Config.venues.strawberry.coords)
    return key
end
local a, b = customer(1,'char1:commerce-license'), customer(2,'char2:commerce-license')
local function open(id, venue)
    clock = clock + 1000
    return callbacks['rp_commerce:open'](id, venue or 'strawberry')
end
local function action(id, values)
    clock = clock + 500
    local p = { session = C.views[id] and C.views[id].token, action = 'buy', offer = 'water', quantity = 2,
        account = 'money', request = S.token('purchase') }
    for k,v in pairs(values or {}) do p[k] = v end
    return callbacks['rp_commerce:action'](id,p), p
end
check(not open(99).ok, 'unloaded character cannot shop')
coords[1].x = 1000
check(not open(1).ok, 'remote open denied')
coords[1] = M.copy(C.Config.venues.strawberry.coords)
buckets[1] = 1
check(not open(1).ok, 'other routing bucket denied')
buckets[1] = 0
check(open(1).ok and open(2).ok, 'nearby spawned players may open')
for _, quantity in ipairs({ 0, -1, 1.5, 21, math.huge, '2', {} }) do
    check(not action(1,{quantity=quantity}).ok, 'malformed purchase quantity refused')
end
check(not action(1,{offer='WEAPON_PISTOL'}).ok, 'arbitrary item not in shop refused')
check(not action(1,{account='black_money'}).ok, 'unknown payment account refused')
check(not action(1,{session=C.views[2].token}).ok, 'foreign session cannot authorize payment')
local reply, purchase = action(1,{price=0,total=-100,quantity=2})
check(reply.ok and balances[1].money == 976 and api.GetItem(1,'rp_water').count == 2, 'server price debited via ESX before delivery')
check(api.GetItem(2,'rp_water').count == 0 and balances[2].money == 1000, 'same account different characters remain isolated')
check(action(1,purchase).ok and debits == 1 and api.GetItem(1,'rp_water').count == 2, 'purchase replay charges and delivers only once')
purchase.account = 'bank'
check(action(1,purchase).error == 'request_reused', 'same request with changed payment rejected')
local packet = {session=C.views[1].token,action='buy',offer='water',quantity=1,account='money',request='request-rate-test'}
check(callbacks['rp_commerce:action'](1,packet).error == 'rate_limited', 'purchase rate limit enforced')
check(action(1,{offer='backpack',quantity=4}).error == 'not_enough_money', 'insufficient balance cannot create items')
check(debits == 1, 'failed funds check does not debit')
check(api.SetMaxWeight(1,1000), 'capacity test prepared')
check(not action(1).ok and debits == 1, 'full inventory checked before charging')
check(api.SetMaxWeight(1,25000), 'capacity restored')
check(action(1,{account='bank',quantity=1}).ok and balances[1].bank == 1988, 'bank payment uses ESX bank account')

-- A paid purchase can recover after SQL failure or a lost commit acknowledgement.
failCommit = true
local beforeDebit, beforeCount = debits, api.GetItem(1,'rp_water').count
reply, purchase = action(1,{quantity=1})
check(not reply.ok and C.pending(players[1].identifier).status == 'paid', 'failed item commit retains confirmed paid order')
failCommit = false
check(debits == beforeDebit+1 and api.GetItem(1,'rp_water').count == beforeCount, 'failed commit creates no items')
check(action(1,{action='recover'}).ok and debits == beforeDebit+1 and api.GetItem(1,'rp_water').count == beforeCount+1, 'paid recovery delivers once without charging again')
loseCommitReply = true
beforeDebit, beforeCount = debits, api.GetItem(1,'rp_water').count
reply = action(1,{quantity=1})
check(not reply.ok and api.GetItem(1,'rp_water').count == beforeCount+1, 'lost commit reply can still have durable items')
check(action(1,{action='recover'}).ok and debits == beforeDebit+1 and api.GetItem(1,'rp_water').count == beforeCount+1, 'recovery checks provider receipt and never duplicates delivered items')

-- Unconfirmed money outcomes are held, never automatically refunded or recharged.
failSave = true
beforeDebit, beforeCount = debits, api.GetItem(1,'rp_water').count
reply, purchase = action(1,{quantity=1})
check(reply.error == 'payment_review' and debits == beforeDebit+1 and api.GetItem(1,'rp_water').count == beforeCount, 'missing save confirmation blocks item grant')
check(action(1,purchase).error == 'payment_review' and debits == beforeDebit+1, 'retry of uncertain debit never charges twice')
check(action(1,{action='recover'}).error == 'payment_review', 'client cannot approve ambiguous payment')
check(action(1).error == 'pending_purchase', 'new requests cannot bypass payment hold')
commands.rp_commerce_resolve(1,{'1',purchase.request,'paid','fake admin approval'})
check(C.pending(players[1].identifier).status == 'intent', 'player cannot run console reconciliation')
failSave = false Wait(50)
commands.rp_commerce_resolve(0,{'1',purchase.request,'paid','Verified persisted debit in test'})
check(action(1,{action='recover'}).ok and debits == beforeDebit+1, 'audited operator confirmation releases paid order')

-- Crafting grants only after server time, with all materials in one transaction.
coords[1] = M.copy(C.Config.venues.strawberry_workbench.coords)
check(open(1,'strawberry_workbench').ok, 'workbench opens')
check(action(1,{action='craft',offer='bandage',quantity=1}).error == 'not_enough', 'missing materials denied')
check(api.AddItem(1,'rp_fabric',8), 'crafting materials added through provider')
reply = action(1,{action='craft',offer='bandage',quantity=2})
check(reply.ok and reply.commerce.job.quantity == 2, 'server issues timed craft job')
local jobToken = reply.commerce.job.token
check(action(1,{action='finish',token=jobToken}).error == 'craft_not_ready', 'client cannot skip crafting duration')
check(action(1,{action='finish',token='forged'}).error == 'invalid_state', 'forged completion token refused')
check(action(1,{action='cancel'}).ok and api.GetItem(1,'rp_fabric').count == 8, 'cancellation does not consume materials')
check(not action(1,{action='finish',token=jobToken}).ok, 'cancelled job cannot complete later')
reply = action(1,{action='craft',offer='bandage',quantity=2})
jobToken = reply.commerce.job.token
clock = clock + 6000
beforeCount = api.GetItem(1,'rp_water').count
reply = action(1,{action='finish',token=jobToken})
check(reply.ok and api.GetItem(1,'rp_bandage').count == 2 and api.GetItem(1,'rp_fabric').count == 4
    and api.GetItem(1,'rp_water').count == beforeCount-2, 'recipe removes all inputs and grants exact output atomically')
check(not action(1,{action='finish',token=jobToken}).ok and api.GetItem(1,'rp_bandage').count == 2, 'duplicate finish cannot mint crafted items')
reply = action(1,{action='craft',offer='bandage',quantity=1})
jobToken = reply.commerce.job.token
check(api.RemoveItem(1,'rp_fabric',4), 'materials removed during crafting')
clock = clock + 3000
beforeCount = api.GetItem(1,'rp_water').count
check(action(1,{action='finish',token=jobToken}).error == 'not_enough' and api.GetItem(1,'rp_water').count == beforeCount, 'finish revalidates materials without partial consumption')
action(1,{action='cancel'})
api.AddItem(1,'rp_fabric',2)
reply = action(1,{action='craft',offer='bandage',quantity=1})
coords[1].x = 999
clock = clock + 4000
check(not action(1,{action='finish',token=reply.commerce.job.token}).ok, 'remote craft completion rejected')
coords[1] = M.copy(C.Config.venues.strawberry.coords)
check(open(1).ok, 'shop reopened')
dropOnSave = true
beforeCount = api.GetItem(1,'rp_water').count
reply = action(1,{quantity=1})
check(not reply.ok and M.count(db[a].data,'rp_water') == beforeCount, 'disconnect during payment never grants to a stale player')
check(C.pending('char1:commerce-license').status == 'paid', 'confirmed payment survives disconnect for later recovery')
check(api.GetItem(2,'rp_water').count == 0, 'other character never receives disconnected order')
print(('PASS: %d commerce/ESX/payment/crafting assertions'):format(passed))

-- Persistent Ammu-Nation uses the same real payment and inventory coordinator above.
dropOnSave, failSave, pendingSave = false, false, nil
dofile(commerceBase .. 'shared/weapons.lua')
local W, shopRows, sqlFault = C.Weapons, {}, false
local catalogQuery, catalogInsert, catalogUpdate, catalogSingle = MySQL.query.await,MySQL.insert.await,MySQL.update.await,MySQL.single.await
local catalogScalar = MySQL.scalar.await
MySQL.scalar.await = function(sql,p)
    if sql:find('SELECT COUNT(*) FROM rp_commerce_orders',1,true) then
        local n=0
        for _,row in pairs(orders) do
            if (row.status=='intent' or row.status=='paid') and json.decode(row.payload).venue==p[1] then n=n+1 end
        end
        return n
    end
    return catalogScalar(sql,p)
end
MySQL.query.await = function(sql,p)
    if sql:find('rp_commerce_weaponshops',1,true) then
        local result={} for _,row in pairs(shopRows) do if row.deleted==0 then result[#result+1]=M.copy(row) end end return result
    end
    return catalogQuery(sql,p)
end
MySQL.insert.await = function(sql,p)
    if sql:find('rp_commerce_weaponshops',1,true) then
        assert(not shopRows[p[1]],'unique shop ID')
        shopRows[p[1]]={id=p[1],payload=p[2],revision=1,deleted=0}
        if sqlFault then sqlFault=false error('lost shop creation acknowledgement') end
        return 1
    end
    return catalogInsert(sql,p)
end
MySQL.update.await = function(sql,p)
    if sql:find('rp_commerce_weaponshops',1,true) then
        local row=shopRows[p[4]]
        if not row or row.deleted~=0 or row.revision~=p[5] then return 0 end
        row.payload,row.deleted,row.revision=p[1],p[2],row.revision+1 return 1
    end
    return catalogUpdate(sql,p)
end
MySQL.single.await = function(sql,p)
    if sql:find('rp_commerce_weaponshops',1,true) then return shopRows[p[1]] and M.copy(shopRows[p[1]]) end
    return catalogSingle(sql,p)
end
local role, licenseState, licensed = 'owner','missing',false
ESX.RegisterCommand=function(name,groups,fn) commands[name]=fn check(groups[3]=='owner','owner may open weaponshop editor') end
function GetResourceState() return licenseState end
function TriggerEvent(name,id,kind,cb) if name=='esx_license:checkLicense' then check(kind=='weapon','ESX standard weapon licence type') cb(licensed) end end
players[2].getGroup=function() return role end
local c=customer(3,'char3:shop-customer')
players[3].getGroup=function() return 'user' end
coords[3]=M.copy(coords[2])
dofile(commerceBase .. 'server/shop_editor_store.lua')
dofile(commerceBase .. 'server/weaponshops.lua') ready()
local function call(name,id,...)
    clock=clock+1600
    return callbacks['rp_commerce:'..name](id,...)
end
check(not call('weaponEditorOpen',3).ok,'ordinary customer cannot access editor')
local access=call('weaponEditorOpen',2)
check(access.ok and #access.shops==0,'owner editor loads durable catalogue')
local raw=W.newShop(coords[2]) raw.coords.bucket=0
raw.displays={{id='test_pistol',catalog='pistol',type='counter',pos=M.copy(coords[2]),rot={x=90,y=0,z=0},heading=0,scale=1,height=0}}
raw.displays[2]={id='test_rifle',catalog='rifle',type='wall',pos=M.copy(coords[2]),rot={x=0,y=0,z=0},heading=0,scale=1,height=0}
local oldPricing=M.copy(raw) oldPricing.ammoPricing=nil oldPricing.prices.pistol_ammo=8 oldPricing.prices.rifle_ammo=15
local converted=W.validate(oldPricing)
check(converted.prices.pistol_ammo==96 and converted.prices.rifle_ammo==450,'legacy cartridge prices convert once to magazine prices')
check(W.validate(converted).prices.pistol_ammo==96,'saving/reloading magazine prices never multiplies twice')
raw.prices.pistol,raw.prices.pistol_light=100,25
local bad=M.copy(raw) bad.displays[1].catalog='client_chosen_weapon'
check(not call('weaponEditorSave',2,access.token,false,0,bad,false).ok,'unknown catalogue rejected')
bad=M.copy(raw) bad.displays[1].pos.z=0/0
check(not W.validate(bad),'NaN coordinate rejected')
bad=M.copy(raw) bad.prices.pistol=-1
check(not W.validate(bad),'negative price rejected')
bad=M.copy(raw) bad.npc={model='s_m_y_cop_01',pos=coords[2],heading=0,scenario=W.scenarios[1]}
check(not W.validate(bad),'NPC model allowlist enforced')
bad=M.copy(raw) bad.displays[2]=M.copy(bad.displays[1])
check(not W.validate(bad),'duplicate display IDs rejected')
bad=M.copy(raw) bad.displays[1].id='payment'
check(not W.validate(bad),'reserved navigation IDs rejected')
bad=M.copy(raw) bad.coords.x=bad.coords.x+100
check(not call('weaponEditorSave',2,access.token,false,0,bad,false).ok,'remote placement denied')
local created=call('weaponEditorSave',2,access.token,false,0,raw,false)
check(created.ok and created.shop.revision==1,'owner creates durable shop')
check(not call('weaponEditorSave',2,access.token,false,0,raw,false).ok,'lost creation response cannot duplicate shop with same capability')
access.token=created.token
local shop=created.shop local venue='weapon_'..shop.id
check(call('weaponshops',3).shops[1].displays[1].catalog=='pistol','nearby customer receives presentation')
buckets[3]=8 check(#call('weaponshops',3).shops==0,'shops scoped to routing bucket') buckets[3]=0
check(open(3,venue).ok,'Ammu-Nation opens via existing shop callback')
local oldDebit=debits
check(action(3,{offer='bandage',quantity=1}).error=='invalid_request','unstocked weapon cannot be bought')
reply,purchase=action(3,{offer='pistol',quantity=1,price=0,item='WEAPON_CARBINERIFLE'})
check(reply.ok and balances[3].money==900 and api.GetItem(3,'WEAPON_PISTOL').count==1,'server catalogue chooses price and delivered weapon')
check(action(3,purchase).ok and debits==oldDebit+1 and api.GetItem(3,'WEAPON_PISTOL').count==1,'weapon replay is idempotent')
check(action(3,{offer='pistol_light',quantity=1}).ok,'compatible attachment purchased through provider')
local beforeAmmo=api.GetItem(3,'ammo_pistol').count
local beforeMoney=balances[3].money
local ammoReply,ammoRequest=action(3,{offer='pistol_ammo',quantity=2,count=999,packSize=999,price=0})
check(ammoReply.ok and api.GetItem(3,'ammo_pistol').count==beforeAmmo+24 and balances[3].money==beforeMoney-192,'server delivers two magazines at server pack price, ignores forged size')
check(action(3,ammoRequest).ok and api.GetItem(3,'ammo_pistol').count==beforeAmmo+24,'magazine purchase replay never duplicates rounds')
for _,entry in pairs(db[c].data.items) do if entry.name=='ammo_pistol' then check(entry.count==12,'fresh purchased ammo forms magazine-sized full stacks') end end
local rifleRounds=api.GetItem(3,'ammo_rifle').count
check(action(3,{offer='rifle_ammo',quantity=1}).ok and api.GetItem(3,'ammo_rifle').count==rifleRounds+30,'rifle magazine delivers thirty rounds')
local inv=callbacks['rp_inventory:open'](3).inventory
local slot for _,entry in ipairs(inv.own.items) do if entry.name=='rp_pistol_light' then slot=entry.slot end end
local weightBefore=inv.own.weight
clock=clock+2000
local use={session=inv.session,request='install-pistol-light-001',action='use',from='own',slot=slot,count=1,ownRevision=inv.own.revision}
local installed=callbacks['rp_inventory:action'](3,use)
check(installed.ok and api.GetItem(3,'rp_pistol_light').count==0,'attachment consumed atomically through inventory use')
local weapon for _,entry in pairs(db[c].data.items) do if entry.name=='WEAPON_PISTOL' then weapon=entry end end
check(weapon.metadata.components[1]=='COMPONENT_AT_PI_FLSH','installed component persists on weapon metadata')
check(M.weight(db[c].data)==weightBefore,'installed attachment retains its weight')
clock=clock+2000
check(callbacks['rp_inventory:action'](3,use).ok and #weapon.metadata.components==1,'inventory use replay never adds a second component')
local standalone=M.empty()
M.add(standalone,'rp_pistol_light',1)
check(not M.installComponent(standalone,1) and M.count(standalone,'rp_pistol_light')==1,'no compatible weapon leaves attachment intact')
api.AddItem(3,'rp_rifle_scope',1)
ESX.UseItem(3,'rp_rifle_scope')
check(api.GetItem(3,'rp_rifle_scope').count==1,'standard ESX use cannot consume an incompatible attachment')
api.AddItem(3,'WEAPON_CARBINERIFLE',1)
ESX.UseItem(3,'rp_rifle_scope')
local rifle for _,entry in pairs(db[c].data.items) do if entry.name=='WEAPON_CARBINERIFLE' then rifle=entry end end
check(api.GetItem(3,'rp_rifle_scope').count==0 and rifle.metadata.components[1]=='COMPONENT_AT_SCOPE_MEDIUM','ESX usable callback performs the same atomic attachment installation')
shop.license=true
C.busy[C.views[3].actor]=true
check(call('weaponEditorSave',2,access.token,shop.id,shop.revision,shop,false).error=='purchase_in_progress','editor cannot race an active purchase')
C.busy[C.views[3].actor]=nil
local saved=call('weaponEditorSave',2,access.token,shop.id,shop.revision,shop,false)
check(saved.ok and saved.shop.revision==2 and not C.views[3],'edit invalidates older purchase sessions')
check(not call('weaponEditorSave',2,access.token,shop.id,1,shop,false).ok,'stale admin revision cannot overwrite another edit')
check(open(3,venue).ok,'licensed shop can be browsed')
check(action(3,{offer='pistol_ammo',quantity=1}).error=='license_unavailable','missing licence resource fails closed')
licenseState='started'
check(action(3,{offer='pistol_ammo',quantity=1}).error=='weapon_license_required','unlicensed customer denied')
licensed=true
check(action(3,{offer='pistol_ammo',quantity=1}).ok,'ESX licence permits authoritative ammunition purchase')
check(C.views[3].licenseUntil==nil,'short purchase permit is cleared after action')
role='user'
check(call('weaponEditorSave',2,access.token,shop.id,2,shop,false).error=='forbidden','revoked admin rights checked on every save')
role='owner'
sqlFault=true
local second=call('weaponEditorSave',2,access.token,false,0,raw,false)
check(second.ok and second.shop.id~=shop.id,'lost SQL acknowledgement reloads committed creation')
check(not call('weaponEditorSave',2,access.token,false,0,raw,false).ok,'ambiguous creation old capability cannot duplicate')
access.token=second.token
orders['held-shop-order']={status='paid',payload=json.encode({venue=venue})}
check(call('weaponEditorSave',2,access.token,shop.id,2,false,true).error=='pending_orders','cannot delete a shop with undelivered paid orders')
orders['held-shop-order']=nil
local deleted=call('weaponEditorSave',2,access.token,shop.id,2,false,true)
check(deleted.ok and shopRows[shop.id].deleted==1 and not C.Config.venues[venue],'delete archives definition and removes buy access')
check(not open(3,venue).ok,'deleted shop cannot be opened')
emit('esx:playerLogout',0,2)
check(not call('weaponEditorSave',2,access.token,second.shop.id,1,raw,false).ok,'logout invalidates editor capability')
print(('PASS: %d commerce + Ammu-Nation security / persistence / attachment assertions'):format(passed))

-- Ordinary shops share the same repository, ESX accounts and durable exchanges.
S.players[2]={id=b,identifier=players[2].identifier,generation='normal-editor-test'}
dofile(commerceBase .. 'shared/shops.lua')
local G=C.Shops
local normalRows,normalFault={},false
local nq,ni,nu,ns=MySQL.query.await,MySQL.insert.await,MySQL.update.await,MySQL.single.await
MySQL.query.await=function(sql,p)
    if sql:find('rp_commerce_shops',1,true) then local rows={} for _,r in pairs(normalRows) do rows[#rows+1]=M.copy(r) end return rows end
    return nq(sql,p)
end
MySQL.insert.await=function(sql,p)
    if sql:find('rp_commerce_shops',1,true) then
        if normalRows[p[1]] then assert(sql:find('IGNORE',1,true),'normal shop unique ID') return 0 end
        normalRows[p[1]]={id=p[1],payload=p[2],revision=1,deleted=0}
        if normalFault then normalFault=false error('lost normal shop acknowledgement') end
        return 1
    end
    return ni(sql,p)
end
MySQL.update.await=function(sql,p)
    if sql:find('rp_commerce_shops',1,true) then
        local row=normalRows[p[4]]
        if not row or row.deleted~=0 or row.revision~=p[5] then return 0 end
        row.payload,row.deleted,row.revision=p[1],p[2],row.revision+1 return 1
    end
    return nu(sql,p)
end
MySQL.single.await=function(sql,p)
    if sql:find('rp_commerce_shops',1,true) then return normalRows[p[1]] and M.copy(normalRows[p[1]]) end
    return ns(sql,p)
end
dofile(commerceBase .. 'server/shops.lua') ready()
check(normalRows.strawberry and C.Config.venues.strawberry.normalshop,'existing ESX Strawberry zone imported under original venue ID')
check(not call('shopEditorOpen',3).ok,'ordinary player cannot open normal editor')
local normalAccess=call('shopEditorOpen',2)
check(normalAccess.ok and #normalAccess.shops>=1 and #normalAccess.catalog>0,'owner gets existing shops and ESX item catalogue')
for _,item in ipairs(normalAccess.catalog) do check(not item.name:find('WEAPON_',1,true),'normal catalogue excludes weapons') end
local normal=G.newShop(coords[2]) normal.coords.bucket=0
normal.offers={{id='water',item='rp_water',price=17,count=2,category='Drinks'}}
normal.npc={pos=M.copy(coords[2]),model=G.clerkModels[1],scenario=G.scenarios[1],heading=90}
local invalid=M.copy(normal) invalid.offers[1].item='not_an_item'
check(not call('shopEditorSave',2,normalAccess.token,false,0,invalid,false).ok,'unknown ESX item rejected server-side')
for _,item in ipairs({'WEAPON_PISTOL','ammo_pistol','rp_pistol_light','money'}) do
    invalid=M.copy(normal) invalid.offers[1].item=item
    check(not G.validate(invalid),'ordinary shops cannot bypass weapon/licence catalogue or sell money')
end
invalid=M.copy(normal) invalid.offers[1].price=-1 check(not G.validate(invalid),'negative normal price rejected')
invalid=M.copy(normal) invalid.offers[1].count=0.5 check(not G.validate(invalid),'fractional pack size rejected')
invalid=M.copy(normal) invalid.blip.sprite=1001 check(not G.validate(invalid),'invalid blip rejected')
invalid=M.copy(normal) invalid.npc.model='s_m_y_cop_01' check(not G.validate(invalid),'normal clerk allowlist enforced')
invalid=M.copy(normal) invalid.coords.x=0/0 check(not G.validate(invalid),'nonfinite normal coordinates rejected')
invalid=M.copy(normal) invalid.offers[2]=M.copy(invalid.offers[1]) check(not G.validate(invalid),'duplicate normal offers rejected')
invalid=M.copy(normal) invalid.coords.x=invalid.coords.x+100 invalid.npc=false
check(call('shopEditorSave',2,normalAccess.token,false,0,invalid,false).error=='out_of_range','remote normal shop creation denied')
normalFault=true
local normalCreated=call('shopEditorSave',2,normalAccess.token,false,0,normal,false)
check(normalCreated.ok and normalRows[normalCreated.shop.id],'uncertain normal creation recovers committed row')
check(not call('shopEditorSave',2,normalAccess.token,false,0,normal,false).ok,'old creation token cannot duplicate normal shop')
normalAccess.token=normalCreated.token normal=normalCreated.shop
local list=call('shops',3)
check(list.ok and not list.shops[1].offers and not list.shops[1].updated_by,'public normal locations contain no editor or database metadata')
clock=clock+1000 buckets[3]=9 check(#call('shops',3).shops==0,'normal locations bucket-scoped') buckets[3]=0
balances[3].money=1000
check(open(3,normal.id).ok,'ordinary edited shop uses existing customer UI callback')
local prior=api.GetItem(3,'rp_water').count
local result,request=action(3,{offer='water',quantity=1,price=0,count=999})
check(result.ok and balances[3].money==983 and api.GetItem(3,'rp_water').count==prior+2,'normal shop derives price and pack size only from saved server offer')
check(action(3,request).ok and api.GetItem(3,'rp_water').count==prior+2,'normal purchase replay does not duplicate items')
C.busy[C.views[3].actor]=true
check(call('shopEditorSave',2,normalAccess.token,normal.id,normal.revision,normal,false).error=='purchase_in_progress','normal editor cannot race active purchase')
C.busy[C.views[3].actor]=nil
normal.offers[1].price=22
local normalSaved=call('shopEditorSave',2,normalAccess.token,normal.id,normal.revision,normal,false)
check(normalSaved.ok and not C.views[3],'saved normal price closes stale customer sessions')
check(not call('shopEditorSave',2,normalAccess.token,normal.id,1,normal,false).ok,'normal revisions prevent lost admin edits')
normal=normalSaved.shop
role='user' check(call('shopEditorSave',2,normalAccess.token,normal.id,normal.revision,normal,false).error=='forbidden','normal save rechecks owner role') role='owner'
orders['normal-pending']={actor='held',status='paid',payload=json.encode({venue=normal.id}),request_id='held'}
check(call('shopEditorSave',2,normalAccess.token,normal.id,normal.revision,normal,true).error=='pending_orders','normal pending paid order prevents deletion')
orders['normal-pending']=nil
check(call('shopEditorSave',2,normalAccess.token,normal.id,normal.revision,normal,true).ok,'normal soft deletion succeeds')
check(not C.Config.venues[normal.id] and normalRows[normal.id].deleted==1,'deleted normal shop inaccessible but retained durably')
local reload=C.shopEditors['rp_commerce:shopEditor']
ready()
check(not reload.shops[normal.id] and C.Config.venues.strawberry.normalshop,'normal reload preserves tombstone and saved ESX import')
print(('PASS: %d commerce / both shop editors / ESX / persistence assertions'):format(passed))

-- Clothing uses this exact durable ESX purchase pipeline, never a client price/skin.
dofile(base .. 'server/clothing.lua')
dofile(commerceBase .. 'shared/clothing.lua')
local clothingStore=customer(70,'char1:clothing-commerce')
db[clothingStore].data.clothing={version=1,sex=0,worn={}}
S.load(clothingStore)
coords[70]=M.copy(C.Config.venues.binco_strawberry.coords)
local fitting=open(70,'binco_strawberry')
check(fitting.ok and fitting.commerce.clothing and #fitting.commerce.offers>40,'clothing shop opens with named catalog')
for _,offer in ipairs(fitting.commerce.offers) do
    check(Clothing.products[offer.id].sex==0 and offer.garment~=nil,'catalog contains matching model only')
end
local originalBalance=balances[70].money
check(not action(70,{offer='top_1_0',quantity=1}).ok,'forged opposite-model purchase refused')
check(not action(70,{offer='top_0_0',quantity=2}).ok,'clothing purchase count is exactly one')
check(balances[70].money==originalBalance,'rejected clothes do not debit ESX')
local result,request=action(70,{offer='top_0_0',quantity=1,price=0,metadata={garment={sex=1,skin={torso_1=999}}}})
check(result.ok and balances[70].money==originalBalance-Clothing.products.top_0_0.price,'server clothing price charged through ESX')
local bought=S.cache[clothingStore].data.items['1']
check(bought.metadata.garment.sex==0 and bought.metadata.garment.skin.torso_1==0,'client clothing metadata ignored')
check(not S.cache[clothingStore].data.clothing.worn.top,'purchase does not silently equip preview')
check(action(70,request).ok and M.count(S.cache[clothingStore].data,'clothing_top')==1,'clothing purchase retry is idempotent')
buckets[70]=1
check(not action(70,{offer='top_0_1',quantity=1}).ok,'routing bucket rechecked at clothing purchase')
buckets[70]=0
local function outfit(id, products, equip, extra)
    local values={action='buyOutfit',products=products,equip=equip,account='bank'}
    for k,v in pairs(extra or {}) do values[k]=v end
    return action(id,values)
end
local function worn(id, category)
    local data=S.cache[S.players[id].id].data
    for _,entry in pairs(data.items) do
        local garment,cat=M.garment(entry)
        if cat==category and data.clothing.worn[cat]==garment.id then return garment end
    end
end
local priorDebit, priorBank=debits,balances[70].bank
for _,bad in ipairs({{}, {'top_0_1','top_0_0'}, {'top_0_1','top_0_1'}, {'top_0_1','pants_1_0'},
    {'top_0_1','not_an_offer'}, {[1]='top_0_1',injected='pants_0_1'}, {'rp_water'}}) do
    check(not outfit(70,bad,true).ok,'malformed/duplicate/wrong-model outfit rejected')
end
check(not outfit(70,{'top_0_1'},'true').ok,'equip flag must be boolean')
check(debits==priorDebit and balances[70].bank==priorBank,'invalid outfit never charges')
local originalWear=S.animateClothing
S.animateClothing=function() error('fitting checkout must not start a competing dress animation') end
local firstOutfit,firstRequest=outfit(70,{'top_0_1','pants_0_2'},true,{price=0,skin={torso_1=999}})
check(firstOutfit.ok,'whole outfit purchased and equipped while in preview')
local top,pants=worn(70,'top'),worn(70,'pants')
check(top and top.product=='top_0_1' and pants and pants.product=='pants_0_2','only purchased catalog garments equipped')
check(debits==priorDebit+1 and balances[70].bank==priorBank-Clothing.products.top_0_1.price-Clothing.products.pants_0_2.price,'entire outfit uses one server-priced ESX payment')
check(M.count(S.cache[clothingStore].data,'clothing_top')==2,'older unselected garment remains owned')
check(firstOutfit.commerce.clothingSkin.torso_1==1 and #firstOutfit.commerce.currentClothing==2,'response publishes committed baseline and current cards')
local bankAfter=balances[70].bank
firstRequest.products={'pants_0_2','top_0_1'}
check(action(70,firstRequest).ok and balances[70].bank==bankAfter and worn(70,'top').id==top.id,'outfit replay reordered is idempotent including worn IDs')
firstRequest.equip=false
check(action(70,firstRequest).error=='request_reused','same receipt cannot change autoequip preference')
local single=action(70,{offer='top_0_3',quantity=1,equip=true,account='bank'})
check(single.ok and worn(70,'top').product=='top_0_3' and worn(70,'pants').id==pants.id,'single purchase replaces only its worn category')
local oldTopPresent=false
for _,entry in pairs(S.cache[clothingStore].data.items) do
    if entry.metadata.garment and entry.metadata.garment.id==top.id then
        oldTopPresent=not M.clothingDisplay(S.cache[clothingStore].data,entry).worn
    end
end
check(oldTopPresent,'replaced garment remains in inventory unmarked')
S.animateClothing=originalWear
local topBefore=worn(70,'top').id
check(outfit(70,{'top_0_0','shoes_0_1'},false).ok,'unchecked purchase can buy multiple pieces')
check(worn(70,'top').id==topBefore and not worn(70,'shoes'),'unchecked purchase changes no worn categories')
check(M.count(S.cache[clothingStore].data,'clothing_shoes')==1,'unchecked garment still enters inventory')

-- Capacity/funds reject the whole outfit before payment or any wardrobe change.
local tight=customer(71,'char2:clothing-commerce')
db[tight].data.clothing={version=1,sex=0,worn={}} S.load(tight)
coords[71]=M.copy(C.Config.venues.binco_strawberry.coords)
check(open(71,'binco_strawberry').ok,'second character fitting room opens separately')
check(api.SetMaxWeight(71,600),'prepare capacity allowing only first garment')
priorDebit=debits
check(not outfit(71,{'top_0_0','pants_0_0'},true).ok and debits==priorDebit,'batch exceeding combined capacity rejected before debit')
check(M.count(S.cache[tight].data,'clothing_top')==0 and not worn(71,'top'),'no partial items or outfit on capacity failure')
check(api.SetMaxWeight(71,25000),'restore test capacity')
balances[71].bank=100
check(outfit(71,{'top_0_0','pants_0_0'},true).error=='not_enough_money' and debits==priorDebit,'combined price checked before any delivery')
balances[71].bank=2000
failCommit=true
local failed=outfit(71,{'top_0_0','pants_0_0'},true)
check(not failed.ok and C.pending(players[71].identifier).status=='paid','failed outfit commit retains entire paid order')
check(not worn(71,'top') and M.count(S.cache[tight].data,'clothing_pants')==0,'failed commit equips/delivers nothing')
failCommit=false
local paidDebits=debits
check(action(71,{action='recover',equip=false}).ok,'paid outfit recovery honors saved purchase')
check(debits==paidDebits and worn(71,'top') and worn(71,'pants'),'recovery equips originally requested outfit without second debit')
check(worn(70,'top').id==topBefore,'other character wardrobe is isolated')
loseCommitReply=true
local lost=outfit(71,{'shoes_0_2','glasses_0_0'},true)
check(not lost.ok and worn(71,'shoes'),'lost reply can follow complete outfit commit')
local shoeId=worn(71,'shoes').id
paidDebits=debits
check(action(71,{action='recover'}).ok and worn(71,'shoes').id==shoeId and M.count(S.cache[tight].data,'clothing_shoes')==1 and debits==paidDebits,'recovery does not duplicate clothing or re-equip a different ID')
local female=customer(72,'char1:female-clothing')
db[female].data.clothing={version=1,sex=1,worn={}} S.load(female)
coords[72]=M.copy(C.Config.venues.binco_strawberry.coords)
check(open(72,'binco_strawberry').ok and outfit(72,{'top_1_4','shoes_1_2'},true).ok,'female model supports same outfit checkout')
check(worn(72,'top').sex==1 and not outfit(72,{'pants_0_0'},true).ok,'female wardrobe cannot equip male catalog')
print(('PASS: %d commerce / clothing purchase / both shop editors assertions'):format(passed))
