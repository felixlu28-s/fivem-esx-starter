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
local networkEvents = {}
function RegisterNetEvent(name, fn) networkEvents[name] = true AddEventHandler(name, fn) end
function RegisterCommand(name, fn) commands[name] = fn end
function CreateThread(fn) threads[#threads + 1] = fn end
function TriggerEvent() end
function TriggerClientEvent(name, source, payload) grants[#grants + 1] = { name = name, source = source, payload = payload } end
function GetGameTimer() return clock end
function GetPlayerPed(source) return players[source] and source or 0 end
function GetEntityHealth(source) return players[source] and 200 or 0 end
function GetEntityCoords(source) return coords[source] end
function GetEntityHeading() return 0 end
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
dofile(base .. 'server/bridge.lua') dofile(base .. 'server/ground.lua') dofile(base .. 'server/actions.lua')
dofile(base .. 'server/stashes.lua') dofile(base .. 'server/weapons.lua')
local function player(sourceId, character)
    local id = 'player:' .. character
    players[sourceId] = { identifier = character, source = sourceId, spawned = true, syncInventory = function() end }
    coords[sourceId] = { x = 0, y = 0, z = 0 }
    S.players[sourceId] = { id = id, identifier = character, generation = 'gen' .. sourceId }
    db[id] = { id = id, kind = 'player', label = character, context = {}, revision = 0, data = M.empty() }
    S.load(id)
    return id
end
local a, b = player(1, 'char1:same-license'), player(2, 'char2:same-license')
check(api.AddItem(1, 'rp_water', 4), 'standard ESX AddItem bridge')
check(api.GetItem(1, 'rp_water').count == 4 and api.GetItem(2, 'rp_water').count == 0, 'same account different characters isolated')
check(not api.AddItem(1, 'rp_water', -2) and not api.RemoveItem(1, 'rp_water', -2), 'ESX bridge rejects negative values')
check(api.CanCarryItem(1, 'rp_water', 1) and not api.CanCarryItem(1, 'rp_water', 1000), 'ESX capacity bridge')
local kitBefore = mutateCount
commands.rp_inventory_test(1, {})
check(mutateCount == kitBefore, 'test kit denied without ACE')
commands.rp_inventory_test(0, {'1'})
check(api.GetItem(1, 'WEAPON_PISTOL').count == 1, 'console test kit delivered through atomic inventory path')
local function open(sourceId) clock = clock + 2000 return callbacks['rp_inventory:open'](sourceId) end
local function packet(sourceId, action, values)
    local snap = S.snapshot(sourceId)
    local p = { session = snap.session, action = action, ownRevision = snap.own.revision,
        externalRevision = snap.external and snap.external.revision, request = S.token('request'), from = 'own', slot = 1, count = 1 }
    for key, value in pairs(values or {}) do p[key] = value end
    return p
end
local function action(sourceId, p) clock = clock + 2000 return callbacks['rp_inventory:action'](sourceId, p) end
check(open(1).ok and open(2).ok, 'valid players may open inventory')
check(not open(99).ok, 'unknown player cannot open')
do
    local id=player(93,'char1:slot-sort-regression')
    coords[93]={x=2000,y=0,z=0}
    check(api.AddItem(93,'rp_water',6) and api.AddItem(93,'rp_sandwich',1),'sort fixture')
    open(93)
    local move=packet(93,'move',{slot=1.0,to='own',target=4.0,count=2.0})
    move.ownRevision=move.ownRevision+0.0
    check(action(93,move).ok,'NUI float slot numbers support partial same-inventory move')
    check(S.cache[id].data.items['1'].count==4 and S.cache[id].data.items['4'].count==2,'split keeps exact quantity')
    check(action(93,move).ok and api.GetItem(93,'rp_water').count==6,'sort request replay does not copy items')
    check(action(93,packet(93,'move',{slot=1.0,to='own',target=4.0,count=4.0})).ok,'same-store merge through real server action')
    check(action(93,packet(93,'move',{slot=4.0,to='own',target=2.0,count=6.0})).ok,'same-store occupied-slot swap')
    check(S.cache[id].data.items['2'].name=='rp_water' and S.cache[id].data.items['4'].name=='rp_sandwich','swap preserves both items')
    check(not action(93,packet(93,'move',{slot=2.5,to='own',target=5,count=1})).ok,'fractional slots still rejected, never rounded')
end
for _, value in ipairs({ -2, 0, 1.5, math.huge, 0/0, '3', {} }) do
    check(not action(1, packet(1, 'drop', { count = value })).ok, 'network malformed quantity rejected')
end
local foreign = packet(2, 'drop')
check(not action(1, foreign).ok, 'another player session token does not authorize access')
local p = packet(1, 'drop', { count = 2 })
local before = api.GetItem(1, 'rp_water').count
local result = action(1, p)
check(result.ok and not result.inventory.external, 'drop never creates an external inventory')
check(api.GetItem(1, 'rp_water').count == before - 2, 'drop debits owned inventory exactly once')
check(action(1, p).ok and api.GetItem(1, 'rp_water').count == before - 2, 'network replay does not drop twice')
local function ground(sourceId)
    S.publishGround()
    for i=#grants,1,-1 do
        if grants[i].name=='rp_inventory:ground' and grants[i].source==sourceId then return grants[i].payload end
    end
    return {}
end
local function pickup(sourceId,id)
    clock=clock+1000
    return callbacks['rp_inventory:pickupStart'](sourceId,id)
end
local drop=ground(2)[1]
check(drop and drop.count==2 and drop.label==Inventory.items.rp_water.label, 'nearby player sees item label and stack')
do
    local pos={x=drop.pos.x+0.1,y=drop.pos.y,z=drop.pos.z+0.1}
    local rot={x=10,y=20,z=30}
    local writes=mutateCount
    emit('rp_inventory:groundSettled',2,drop.id,pos,rot)
    check(not ground(2)[1].visual,'another player cannot set drop resting pose')
    clock=clock+1000
    emit('rp_inventory:groundSettled',1,drop.id,{x=pos.x+10,y=pos.y,z=pos.z},rot)
    check(not ground(2)[1].visual,'out-of-bounds resting pose rejected')
    clock=clock+1000
    emit('rp_inventory:groundSettled',1,drop.id,{x=0/0,y=pos.y,z=pos.z},rot)
    check(not ground(2)[1].visual,'NaN resting pose rejected')
    clock=clock+1000
    emit('rp_inventory:groundSettled',1,drop.id,pos,rot)
    local visible=ground(2)[1]
    check(visible.visual and visible.visual.pos.x==pos.x and visible.visual.rot.z==30,'bounded owner pose reaches nearby clients')
    check(visible.pos.x==pos.x and visible.pos.z==pos.z and visible.pos.bucket==drop.pos.bucket,'validated owner landing becomes pickup anchor while retaining server bucket')
    clock=clock+1000
    emit('rp_inventory:groundSettled',1,drop.id,drop.pos,{x=0,y=0,z=0})
    check(ground(2)[1].visual.rot.z==30 and mutateCount==writes,'pose accepted once only, with zero inventory/SQL writes')
end
check(not open(2).inventory.external, 'ground prop does not open a second inventory')
local claim=pickup(2,drop.id)
check(claim.ok and not pickup(1,drop.id).ok, 'exclusive pickup reservation prevents competing pickup')
check(callbacks['rp_inventory:pickupFinish'](2,claim.token).ok and api.GetItem(2,'rp_water').count==2, 'pickup uses reserved server item')
clock=clock+1000
check(not callbacks['rp_inventory:pickupFinish'](2,claim.token).ok and #ground(2)==0, 'pickup replay cannot duplicate item')
check(not action(1, packet(1, 'move', { from = 'external', to = 'own', target = 15 })).ok, 'ground is not addressable as container')
for _,row in pairs(db) do check(row.kind~='drop','no durable ground row created') end
local invalid = packet(1, 'unequip', { from = { injected = 'untrusted' }, to = { nested = true } })
check(not action(1, invalid).ok, 'unused nested fields cannot cause an equipment operation')
coords[2] = { x = 100, y = 0, z = 0 }
check(not action(2, packet(2, 'move', { from = 'external', to = 'own', target = 2 })).ok, 'distance checked again on action')
coords[2] = { x = 0, y = 0, z = 0 }
buckets[2] = 3
check(not open(2).inventory.external, 'other routing bucket cannot see drop')
buckets[2] = 0

-- Container capability belongs to the registering server resource. ACL is rechecked on every move.
local authorized = true
local box = api.rpRegisterContainer('box1', { label = 'Box', slots = 8, capacity = 20000, coords = { x = 0, y = 0, z = 0 },
    authorize = function(sourceId) return authorized and sourceId == 1 end })
check(type(box) == 'string' and api.rpOpenContainer(1, box), 'trusted resource may open authorized container')
owner = 'rp_other'
check(not api.rpOpenContainer(1, box), 'foreign resource cannot open another resource capability')
owner = 'rp_test'
p = packet(1, 'move', { to = 'external', target = 1 })
authorized = false
check(not action(1, p).ok, 'revoked container permission blocks transfer even with an open UI')
authorized = true
check(api.rpOpenContainer(1, box), 'authorized reopen')
p = packet(1, 'move', { to = 'external', target = 1 })
check(action(1, p).ok, 'player to container transfer')
emit('onResourceStop', 0, 'rp_test')
check(not action(1, packet(1, 'move', { from = 'external', to = 'own', target = 15 })).ok, 'container owner stop revokes access')

-- ESX addoninventory's actual startup branch must resolve the provider alias.
local stashExport
emit('__cfx_export_ox_inventory_RegisterStash', 0, function(fn) stashExport = fn end)
check(stashExport == api.RegisterStash, 'RegisterStash available through real ox alias event')
owner = 'esx_addoninventory'
local addon = io.open('server-data/resources/[esx]/esx_addoninventory/server/main.lua', 'r')
if addon then
    local startup = assert(addon:read('*a'):match('^(.-)\nItems ='), 'installed addon startup branch')
    addon:close()
    local startHandler, calls = nil, 0
    local env = setmetatable({ ESX = { GetConfig = function() return { OxInventory = true } end },
        GetCurrentResourceName = function() return 'esx_addoninventory' end,
        AddEventHandler = function(name, handler) assert(name == 'onServerResourceStart') startHandler = handler end,
        MySQL = { query = { await = function() return {
            { name = 'society_police', label = 'Police', shared = 1 },
            { name = 'property', label = 'Property', shared = 0 },
        } end } },
        exports = { ox_inventory = { RegisterStash = function(_, ...)
            calls = calls + 1
            assert(stashExport(...))
        end } },
    }, { __index = _G })
    assert(load(startup, '@installed-addon-startup', 't', env))()
    startHandler('esx_addoninventory')
    check(calls == 2, 'installed ESX addon registers shared job and private stashes at startup')
else
    -- CI does not download vendor dependencies.
    check(stashExport('society_police', 'Police', 100, 200000, false, 'police'), 'addon job-string registration')
    check(stashExport('property', 'Property', 100, 200000, true, false), 'addon private registration')
end
check(not api.RegisterStash('bad', 'Bad', 0, 200000), 'invalid stash capacity rejected')
check(not api.RegisterStash('bad', 'Bad', 20, 200000, 'license:account'), 'fixed stash owner requires full character identifier')
check(not api.RegisterStash('bad', 'Bad', 20, 200000, false, { police = -1 }), 'invalid job grade rejected')
check(not api.RegisterStash('bad', 'Bad', 20, 200000, false, false, { x = 0/0, y = 0, z = 0 }), 'non-finite location rejected')
check(not api.RegisterStash('bad', 'Bad', 20, 200000, false, false, { { x = 0, y = 0, z = 0 } }), 'unsupported location arrays fail closed')
player(51, 'char1:stash-account')
local stashB = player(52, 'char2:stash-account')
coords[51], coords[52] = { x = 200, y = 0, z = 0 }, { x = 200, y = 0, z = 0 }
players[51].job, players[52].job = { name = 'police', grade = 2 }, { name = 'unemployed', grade = 0 }
check(api.AddItem(51, 'rp_water', 3), 'stash fixture funded')
owner = 'rp_test'
local stashOk, stashError = api.rpOpenStash(51, 'society_police')
check(not stashOk and stashError == 'stash_location_required', 'coordinate-less addon definition cannot open remotely')
check(not api.RegisterStash('society_police', 'Hijack', 100, 200000), 'registration cannot overwrite another resource definition')
check(api.rpSetStashLocation('society_police', coords[51]), 'trusted domain binds fixed stash location')
check(api.rpSetStashLocation('property', coords[51]), 'private stash location bound')
local scalarBeforeStash, legacyCount = MySQL.scalar.await, 0
MySQL.scalar.await = function(sql, params)
    if sql:find('FROM addon_inventory_items', 1, true) then return legacyCount end
    return scalarBeforeStash(sql, params)
end
legacyCount = 2
stashOk, stashError = api.rpOpenStash(51, 'society_police')
check(not stashOk and stashError == 'stash_migration_required', 'existing legacy stock never silently replaced')
legacyCount = 0
check(not api.rpOpenStash(52, 'society_police'), 'non-member denied society stash')
check(api.rpOpenStash(51, 'society_police'), 'job member opens persistent society stash')
local stashMove = packet(51, 'move', { to = 'external', target = 1 })
check(action(51, stashMove).ok, 'stash deposit uses existing atomic coordinator')
check(action(51, stashMove).ok and api.GetItem(51, 'rp_water').count == 2, 'stash transfer replay cannot duplicate')
stashMove = packet(51, 'move', { from = 'external', to = 'own', target = 2 })
players[51].job.name = 'unemployed'
check(not action(51, stashMove).ok, 'job removal immediately revokes already-open stash')
players[51].job.name = 'police'
coords[51].x = 250
check(not api.rpOpenStash(51, 'society_police'), 'stash distance enforced')
coords[51].x = 200
buckets[51] = 10
check(not api.rpOpenStash(51, 'society_police'), 'stash routing bucket enforced')
buckets[51] = 0
check(api.rpOpenStash(51, 'property'), 'character-owned addon stash opens')
check(action(51, packet(51, 'move', { to = 'external', target = 1 })).ok, 'private stash funded')
check(api.rpOpenStash(52, 'property') and #S.snapshot(52).external.items == 0, 'same account different character has separate private stash')
check(api.rpOpenStash(51, 'property') and S.snapshot(51).external.items[1].count == 1, 'original character retains private stock')
local privateRow = 'container:rp_inventory:stash:property:owner:char1:stash-account'
S.cache[privateRow] = nil
check(api.rpOpenStash(51, 'property') and S.snapshot(51).external.items[1].count == 1, 'stash restored from durable store after cache loss')
emit('onResourceStop', 0, 'rp_test')
check(not S.snapshot(51).external, 'location resource stop revokes access to loaded stash')
check(api.rpSetStashLocation('property', coords[51]) and api.rpOpenStash(51, 'property'), 'location resource may bind again on restart')
owner = 'esx_addoninventory'
check(api.RegisterStash('property', 'Property', 1, 200000, true, false), 'stash definition reload accepted')
owner = 'rp_test'
check(api.rpSetStashLocation('property', coords[51]), 'reloaded definition rebound')
stashOk, stashError = api.rpOpenStash(51, 'property')
check(not stashOk and stashError == 'stash_migration_required', 'capacity change requires explicit migration without item loss')
check(not open(51).inventory.external, 'normal inventory opening cannot bypass blocked capacity migration')
emit('onResourceStop', 0, 'esx_addoninventory')
check(not api.rpOpenStash(51, 'property'), 'registrar stop revokes definitions')
check(M.count(db[privateRow].data, 'rp_water') == 1 and db[stashB].data.items['1'] == nil, 'revocation preserves durable stock and character isolation')
MySQL.scalar.await = scalarBeforeStash

check(api.RegisterStash('ranked', 'Ranked', 12, 20000, false, { police = 3 }, coords[51]), 'job grade map accepted')
check(not api.rpOpenStash(51, 'ranked'), 'below minimum job grade denied')
players[51].job.grade = 3
check(api.rpOpenStash(51, 'ranked'), 'required job grade accepted')
players[51].job.grade = 0
check(not S.snapshot(51).external, 'demotion revokes already-open ranked stash')
check(api.RegisterStash('fixed', 'Fixed', 12, 20000, 'char1:stash-account', false, coords[51]), 'fixed character stash registered')
check(not api.rpOpenStash(52, 'fixed') and api.rpOpenStash(51, 'fixed'), 'fixed owner excludes another character on same account')
check(api.RegisterStash('await', 'Await', 12, 20000, true, false, coords[51]), 'async fixture registered')
local insertBeforeStash, beforeSession = MySQL.insert.await, S.players[51]
MySQL.insert.await = function(...)
    S.players[51] = nil
    return insertBeforeStash(...)
end
check(not api.rpOpenStash(51, 'await'), 'disconnect during first stash load cannot open stale session')
MySQL.insert.await, S.players[51] = insertBeforeStash, beforeSession
check(api.RegisterStash('sqlfail', 'SQL failure', 12, 20000, false, false, coords[51]), 'SQL failure fixture registered')
MySQL.insert.await = function() error('injected stash SQL failure') end
stashOk, stashError = api.rpOpenStash(51, 'sqlfail')
check(not stashOk and stashError == 'database_error', 'stash SQL failure fails closed and returns an error')
MySQL.insert.await = insertBeforeStash
emit('onResourceStop', 0, 'rp_test')

-- Context-menu giving: server-issued recipient capabilities and atomic transfers.
local giver, receiver = player(41, 'char1:give-test'), player(42, 'char1:receive-test')
coords[41], coords[42] = { x = 500, y = 0, z = 0 }, { x = 501, y = 0, z = 0 }
check(api.AddItem(41, 'rp_water', 6), 'give fixture created through provider')
check(open(41).ok and open(42).ok, 'give views loaded')
local function recipients(sourceId)
    clock = clock + 600
    return callbacks['rp_inventory:recipients'](sourceId, S.snapshot(sourceId).session)
end
local function givePacket()
    local list = recipients(41)
    check(list.ok and #list.recipients == 1 and list.recipients[1].distance == 1, 'only nearby other player offered')
    local r = list.recipients[1]
    check(r.identifier == nil and r.source == nil and r.token ~= nil, 'recipient payload contains no character/database identifiers')
    return packet(41, 'give', { recipient = r.token })
end
local gp = givePacket()
check(not callbacks['rp_inventory:recipients'](41, gp.session).ok, 'recipient queries rate limited')
local resultGive = action(41, gp)
check(resultGive.ok and api.GetItem(41, 'rp_water').count == 5 and api.GetItem(42, 'rp_water').count == 1, 'give credits recipient and debits giver atomically')
check(action(41, gp).ok and api.GetItem(42, 'rp_water').count == 1, 'give request replay never duplicates')
gp.count = 2
check(action(41, gp).error == 'request_reused', 'altered give replay refused')
check(not action(41, packet(41, 'give', { recipient = 'forged-recipient' })).ok, 'arbitrary recipient token refused')
gp = givePacket()
check(not action(42, packet(42, 'give', { recipient = gp.recipient })).ok, 'capability cannot be borrowed by another sender')
gp = givePacket()
coords[42].x = 510
check(not action(41, gp).ok and #recipients(41).recipients == 0, 'moving out of range revokes giving and listing')
coords[42].x = 501
gp = givePacket()
buckets[42] = 9
check(not action(41, gp).ok and #recipients(41).recipients == 0, 'routing bucket change refused')
buckets[42] = 0
gp = givePacket()
players[42].spawned = false
check(not action(41, gp).ok and #recipients(41).recipients == 0, 'unspawned recipient refused')
players[42].spawned = true
gp = givePacket()
local recipientSession = S.players[42]
S.players[42] = { id = receiver, identifier = recipientSession.identifier, generation = 'reconnected' }
check(not action(41, gp).ok, 'recycled ID even for same character cannot inherit old capability')
S.players[42] = recipientSession
gp = givePacket()
clock = clock + 16000
check(not action(41, gp).ok, 'recipient choice expires')
gp = givePacket()
check(api.SetMaxWeight(42, 500), 'recipient capacity restricted to current weight')
local giverBefore, receiverBefore = M.canonical(db[giver].data), M.canonical(db[receiver].data)
check(action(41, gp).error == 'too_heavy', 'recipient weight limit applies')
check(M.canonical(db[giver].data) == giverBefore and M.canonical(db[receiver].data) == receiverBefore, 'failed give changes neither inventory')
check(api.SetMaxWeight(42, 25000), 'recipient capacity restored')
gp = givePacket()
S.locks[receiver] = true
check(action(41, gp).error == 'busy', 'concurrent receiver mutation prevents giving')
S.locks[receiver] = nil
gp = givePacket()
local originalScalar = MySQL.scalar.await
MySQL.scalar.await = function(...)
    S.players[42] = nil
    return originalScalar(...)
end
check(not action(41, gp).ok, 'disconnect during database await refused before commit')
MySQL.scalar.await, S.players[42] = originalScalar, recipientSession
gp = givePacket()
local originalQuery = MySQL.query.await
MySQL.query.await = function() error('injected give SQL failure') end
local countBefore = api.GetItem(41, 'rp_water').count
check(action(41, gp).error == 'database_error', 'SQL give failure returned')
MySQL.query.await = originalQuery
check(api.GetItem(41, 'rp_water').count == countBefore and api.GetItem(42, 'rp_water').count == 1, 'SQL failure cannot lose or mint items')
gp = givePacket()
gp.from = 'external'
check(action(41, gp).error == 'invalid_request', 'give cannot take items directly from external store')
gp = givePacket()
gp.count = 100000
check(not action(41, gp).ok, 'give cannot exceed actual stack count')
gp = givePacket()
open(41)
check(not action(41, gp).ok, 'reopening inventory revokes previous view and recipient capabilities')

-- Volatile ground ownership: capacity, claims, ambiguous commits, lifetime and restart.
do
local aa,bb=player(80,'char1:ground-a'),player(81,'char1:ground-b')
coords[80],coords[81]={x=1000,y=0,z=0},{x=1000,y=0,z=0}
check(api.AddItem(80,'rp_water',6),'ground fixture')
local function dropOne()
    open(80)
    return action(80,packet(80,'drop',{slot=1,count=1}))
end
check(dropOne().ok,'single ground item created')
local id=ground(81)[1].id
coords[81].x=1020
check(not pickup(81,id).ok,'pickup distance authoritative')
coords[81].x=1000 buckets[81]=7
check(#ground(81)==0 and not pickup(81,id).ok,'ground routing bucket isolation')
buckets[81]=0
local claim=pickup(81,id)
clock=clock+400
check(callbacks['rp_inventory:pickupFinish'](81,claim.token).error=='not_ready','animation cannot be skipped')
db[bb].data=M.empty(1,1) S.load(bb)
clock=clock+500
check(not callbacks['rp_inventory:pickupFinish'](81,claim.token).ok and #ground(80)==1,'full inventory leaves ground item intact')
db[bb].data=M.empty() S.load(bb)
claim=pickup(81,id)
local oldSession=S.players[81]
S.players[81]=M.copy(oldSession) S.players[81].generation='recycled'
clock=clock+1000
check(not callbacks['rp_inventory:pickupFinish'](81,claim.token).ok,'character session switch invalidates claim')
S.players[81]=oldSession
claim=pickup(81,id)
emit('playerDropped',81)
S.players[81]=oldSession S.load(bb)
check(pickup(80,id).ok,'disconnect releases noncommitting reservation')
clock=clock+7000
-- Run only the ground maintenance threads with a cooperative Wait stub.
local originalWait=Wait
Wait=function(ms) coroutine.yield(ms) end
local periodic={}
for _,fn in ipairs(threads) do
    if debug.getinfo(fn,'S').short_src:find('server/ground.lua',1,true) then
        local co=coroutine.create(fn)
        local ok,delay=coroutine.resume(co) assert(ok,delay)
        periodic[delay]=co
    end
end
local function tick(delay)
    local ok,err=coroutine.resume(assert(periodic[delay]))
    assert(ok,err)
end
tick(2000)
claim=pickup(81,id) clock=clock+1000
check(callbacks['rp_inventory:pickupFinish'](81,claim.token).ok,'expired reservation becomes available')
check(#ground(80)==0,'collected prop removed for all nearby players')
local originalQuery,originalScalar=MySQL.query.await,MySQL.scalar.await
local lost=false
MySQL.query.await=function(query,params) originalQuery(query,params) lost=true error('expected lost ground commit acknowledgement') end
MySQL.scalar.await=function(query,params) if lost then error('expected unreadable receipt') end return originalScalar(query,params) end
local result=dropOne()
check(not result.ok and #ground(80)==0 and api.GetItem(80,'rp_water').count==4,'ambiguous drop stays hidden without restoring debit')
MySQL.query.await,MySQL.scalar.await=originalQuery,originalScalar
tick(2000)
check(#ground(80)==1,'recovered receipt publishes exactly one ground item')
id=ground(80)[1].id
claim=pickup(81,id) clock=clock+1000
local before=api.GetItem(81,'rp_water').count
lost=false
MySQL.query.await=function(query,params) originalQuery(query,params) lost=true error('expected lost pickup acknowledgement') end
MySQL.scalar.await=function(query,params) if lost then error('expected unreadable pickup receipt') end return originalScalar(query,params) end
result=callbacks['rp_inventory:pickupFinish'](81,claim.token)
check(not result.ok and api.GetItem(81,'rp_water').count==before+1,'pickup commit survives lost acknowledgement')
check(not pickup(80,id).ok,'ambiguous pickup cannot be picked again')
MySQL.query.await,MySQL.scalar.await=originalQuery,originalScalar
tick(2000)
check(#ground(80)==0 and api.GetItem(81,'rp_water').count==before+1,'recovered pickup receipt deletes ground without a second grant')
check(dropOne().ok,'expiry fixture')
local timeFn,now=os.time,os.time()
os.time=function() return now end
now=now+1799 tick(60000)
check(#ground(80)==1,'item remains before thirty minutes')
now=now+2 tick(60000)
check(#ground(80)==0,'minute sweep removes items older than thirty minutes')
os.time=timeFn
check(dropOne().ok,'restart fixture')
local count=api.GetItem(80,'rp_water').count
dofile(base..'server/ground.lua')
check(#ground(80)==0 and api.GetItem(80,'rp_water').count==count,'new resource runtime has no world items and never restores dropped inventory')
for _,row in pairs(db) do check(row.kind~='drop','ground rows never persisted') end
Wait=originalWait
end

-- Batched durable prepayment: no per-shot transaction, no refunds, bounded remote damage.
do
clock=clock+2000
local reserve=api.GetItem(1,'ammo_pistol').count
local transactions=mutateCount
local grant=callbacks['rp_inventory:ammoBatch'](1,'WEAPON_PISTOL','batch-request-1')
check(grant.ok and grant.count==12 and grant.remaining==reserve-12,'one magazine debited durably')
check(mutateCount==transactions+1,'one transaction per magazine')
local again=callbacks['rp_inventory:ammoBatch'](1,'WEAPON_PISTOL','batch-request-1')
check(again.ok and again.token==grant.token and mutateCount==transactions+1,'retry recovers same budget without SQL')
clock=clock+2000
check(not callbacks['rp_inventory:ammoBatch'](1,'WEAPON_PISTOL','batch-request-2',{ammo='ammo_pistol',token='forged',spent=12}).ok,'forged report cannot finish budget')
local function damageAllowed(id)
    cancelled=false
    emit('weaponDamageEvent',0,id,{weaponType=joaat('WEAPON_PISTOL')})
    return not cancelled
end
transactions=mutateCount
for _=1,12 do check(damageAllowed(1),'paid magazine accepts damage without requests') end
check(not damageAllowed(1) and mutateCount==transactions,'exhausted damage budget rejected with zero SQL')
check(not damageAllowed(2),'unowned damage rejected')
clock=clock+2000
emit('rp_inventory:ammoReport',1,grant.generation,{ammo_pistol={ammo='ammo_pistol',token=grant.token,spent=12}})
check(mutateCount==transactions,'periodic consumption report is RAM-only')
local nextGrant=callbacks['rp_inventory:ammoBatch'](1,'WEAPON_PISTOL','batch-request-2')
check(nextGrant.ok and api.GetItem(1,'ammo_pistol').count==reserve-24,'second magazine paid once')
clock=clock+2000
check(not callbacks['rp_inventory:ammoBatch'](1,'WEAPON_PISTOL','batch-request-1',
    {ammo='ammo_pistol',token=nextGrant.token,spent=12}).ok,'old receipt cannot mint fresh budget')
check(api.RemoveItem(1,'WEAPON_PISTOL',1),'weapon removed through ESX')
check(not damageAllowed(1),'weapon transfer revokes paid damage budget')
check(networkEvents['esx:onPlayerSpawn'],'spawn remains network safe')
player(71,'char1:spawn-test') player(72,'char1:spawn-other')
for _,id in ipairs({71,72}) do
    check(api.AddItem(id,'WEAPON_PISTOL',1) and api.AddItem(id,'ammo_pistol',60),'spawn fixture')
    check(callbacks['rp_inventory:ammoBatch'](id,'WEAPON_PISTOL','spawn-paid-1').ok,'spawn prepaid fixture')
end
local beforeSpawn=api.GetItem(71,'ammo_pistol').count
emit('esx:onPlayerSpawn',0,71) emit('esx:onPlayerSpawn',999,71)
emit('esx:onPlayerSpawn',71,72)
check(not damageAllowed(71) and damageAllowed(72),'spawn trusts source only')
check(api.GetItem(71,'ammo_pistol').count==beforeSpawn,'spawn cannot refund magazine')
check(not callbacks['rp_inventory:ammoBatch'](71,'WEAPON_PISTOL','spawn-paid-2').ok,'spawn retains request rate')
clock=clock+2000
check(callbacks['rp_inventory:ammoBatch'](71,'WEAPON_PISTOL','spawn-paid-2').ok,'new budget after cooldown')
emit('esx:onPlayerSpawn',71)
check(not damageAllowed(71),'respawn revokes credits')
clock=clock+2000
local originalQuery=MySQL.query.await
MySQL.query.await=function(query,params) originalQuery(query,params) emit('esx:onPlayerSpawn',71) end
local waiting=callbacks['rp_inventory:ammoBatch'](71,'WEAPON_PISTOL','spawn-during-sql')
MySQL.query.await=originalQuery
check(not waiting.ok and not damageAllowed(71),'respawn during SQL discards in-flight reply')
clock=clock+2000
check(not callbacks['rp_inventory:ammoBatch'](71,'WEAPON_PISTOL','spawn-during-sql').ok,'receipt prevents recreation')
-- Lost commit acknowledgements are fail-closed and never restore the durable debit.
player(73,'char1:lost-ammo')
check(api.AddItem(73,'WEAPON_PISTOL',1) and api.AddItem(73,'ammo_pistol',30),'lost ack fixture')
MySQL.query.await=function(query,params) originalQuery(query,params) error('simulated lost batch acknowledgement') end
local lost=callbacks['rp_inventory:ammoBatch'](73,'WEAPON_PISTOL','lost-ack-batch')
MySQL.query.await=originalQuery
check(not lost.ok and api.GetItem(73,'ammo_pistol').count==18,'lost ack does not refund spent inventory')
clock=clock+2000
check(not callbacks['rp_inventory:ammoBatch'](73,'WEAPON_PISTOL','lost-ack-batch').ok and api.GetItem(73,'ammo_pistol').count==18,'lost-ack replay neither grants nor debits again')
check(not damageAllowed(73),'lost acknowledgement has no damage credit')
end
-- Run the installed vendor override itself against this provider (no vendor edits).
local vendor = 'server-data/resources/[esx]/es_extended/server/classes/overrides/oxinventory.lua'
local file = io.open(vendor)
if file then
    file:close()
    Config, Core = { CustomInventory = 'ox' }, { PlayerFunctionOverrides = {} }
    _G.ESX = ESX
    function GetResourceState() return 'started' end
    function GetConvar(name)
        assert(name == 'inventory:accounts', 'ESX reads only its configured account bridge')
        return json.encode({})
    end
    local proxiedCalls = 0
    exports.ox_inventory = setmetatable({}, { __index = function(_, name) return function(_, ...)
        if name == 'Inventory' then
            -- Cfx serializes functions nested in exported tables as callable refs.
            -- ESX's strict function check deliberately selects its public-export proxy.
            local module = { accounts = {} }
            for method, fn in pairs(api.Inventory()) do
                if type(fn) == 'function' then
                    module[method] = setmetatable({ __cfx_functionReference = method }, { __call = function(_, ...) return fn(...) end })
                end
            end
            return module
        end
        proxiedCalls = proxiedCalls + 1
        return api[name](...)
    end end })
    dofile(vendor)
    local c = player(3, 'char3:same-license')
    for name, make in pairs(Core.PlayerFunctionOverrides.OxInventory) do players[3][name] = make(players[3]) end
    check(players[3].addInventoryItem('rp_water', 7), 'installed ESX override routes additions into durable provider')
    check(players[3].getInventoryItem('rp_water').count == 7, 'installed ESX override gets aggregate counts')
    local minimal = players[3].getInventory(true)
    check(#minimal == 2 and minimal[1].count + minimal[2].count == 7, 'installed ESX saver sees per-slot mirror')
    check(players[3].removeInventoryItem('rp_water', 3), 'installed ESX override removes through same authority')
    check(M.count(db[c].data, 'rp_water') == 4, 'actual stock method committed inventory')
    check(players[3].canCarryItem('rp_water', 1) and not players[3].canCarryItem('rp_water', 100000), 'installed capacity methods obey slots and grams')
    check(players[3].getLoadout() and not players[3].hasWeapon('WEAPON_PISTOL'), 'standard custom-inventory weapon semantics retained')
    check(proxiedCalls > 0, 'logged direct-export fallback actually routes ESX calls to provider successfully')
else print('SKIP: installed ESX provider integration (vendor resources not installed)') end
-- Actual administrative RPCs use the same durable coordinator as the ESX bridge.
local adminId, targetId = player(21, 'char1:admin'), player(22, 'char1:recipient')
local role = 'owner'
players[21].getGroup = function() return role end
players[22].getGroup = function() return 'user' end
ESX.RegisterCommand = function(name, groups, handler)
    check(name == 'rp_items' and groups[3] == 'owner', 'admin command includes ESX owner')
    commands[name] = handler
end
dofile(base .. 'server/admin.lua')
local function adminCall(action, sourceId, ...)
    clock = clock + 1500
    return callbacks['rp_inventory:' .. action](sourceId, ...)
end
check(not adminCall('adminCatalog', 22).ok, 'ordinary players cannot retrieve admin catalog')
commands.rp_items(players[21])
check(grants[#grants].name == 'rp_inventory:adminOpen' and grants[#grants].source == 21, 'ESX command targets only requesting admin')
local catalog = adminCall('adminCatalog', 21)
check(catalog.ok and #catalog.items >= 12 and catalog.target == 21, 'catalog includes all registered items and defaults to self')
local ticket = catalog.ticket
local result = adminCall('adminGive', 21, catalog.token, ticket, 'rp_water', 2)
check(result.ok and M.count(db[adminId].data,'rp_water') == 2, 'owner receives requested amount')
local committed = mutateCount
local replay = adminCall('adminGive', 21, catalog.token, ticket, 'rp_water', 2)
check(replay.ok and replay.ticket == result.ticket and mutateCount == committed, 'same grant replayed without second addition')
check(not adminCall('adminGive', 21, catalog.token, ticket, 'rp_water', 3).ok, 'changed replay rejected')
check(not adminCall('adminGive', 22, catalog.token, result.ticket, 'rp_water', 1).ok, 'foreign caller cannot reuse admin token')
for _, amount in ipairs({0,-1,100,1.5,'2',math.huge,0/0}) do
    check(not adminCall('adminGive',21,catalog.token,result.ticket,'rp_water',amount).ok, 'invalid admin quantity rejected')
end
check(not adminCall('adminGive',21,catalog.token,result.ticket,'nonexistent',1).ok, 'unknown catalog item rejected')
local selected = adminCall('adminTarget',21,catalog.token,22)
check(selected.ok and selected.target == 22, 'admin explicitly selects online recipient')
check(not adminCall('adminTarget',21,catalog.token,999).ok, 'offline target rejected')
local full = adminCall('adminGive',21,catalog.token,selected.ticket,'WEAPON_CARBINERIFLE',99)
check(not full.ok and M.count(db[targetId].data,'WEAPON_CARBINERIFLE') == 0, '99-item capacity failure has no partial grant')
role='user'
check(not adminCall('adminGive',21,catalog.token,selected.ticket,'rp_water',1).ok, 'revoked admin right checked on every grant')
role='owner'
local scalarBefore = MySQL.scalar.await
MySQL.scalar.await = function(...)
    local value = scalarBefore(...)
    role='user'
    return value
end
check(not adminCall('adminGive',21,catalog.token,selected.ticket,'rp_water',1).ok
    and M.count(db[targetId].data,'rp_water') == 0, 'permission revocation during await prevents commit')
MySQL.scalar.await, role = scalarBefore, 'owner'
local queryBefore = MySQL.query.await
MySQL.query.await = function(...)
    queryBefore(...)
    error('expected lost admin commit acknowledgement')
end
check(not adminCall('adminGive',21,catalog.token,selected.ticket,'rp_water',1).ok, 'ambiguous commit reports failure')
MySQL.query.await = queryBefore
result = adminCall('adminGive',21,catalog.token,selected.ticket,'rp_water',1)
check(result.ok and M.count(db[targetId].data,'rp_water') == 1, 'durable receipt handles retry after lost commit acknowledgement')
player(22, 'char2:replacement')
players[22].getGroup = function() return 'user' end
check(not adminCall('adminGive',21,catalog.token,result.ticket,'rp_water',1).ok, 'reused server ID cannot receive a grant for former character')
emit('esx:playerLogout',21,21)
check(not adminCall('adminGive',21,catalog.token,result.ticket,'rp_water',1).ok, 'admin logout invalidates menu session')

local saved = M.canonical(db[a].data)
emit('playerDropped', 1)
check(S.players[1] == nil and M.canonical(db[a].data) == saved, 'disconnect cleanup does not overwrite durable state')
do
    local first, second = player(94, 'char1:attachments'), player(95, 'char2:attachments')
    coords[94],coords[95]={x=8000,y=0,z=0},{x=8000,y=0,z=0}
    local extra={serial='second',durability=73,custom={ownerNote='keep me',values={1,2,3}}}
    check(api.AddItem(94,'WEAPON_PISTOL',1,{serial='first'},1),'first gun')
    check(api.AddItem(94,'WEAPON_PISTOL',1,extra,2),'second gun with arbitrary metadata')
    check(api.AddItem(94,'rp_pistol_suppressor',2,{serial='component',quality=81},3),'attachment metadata fixture')
    open(94)
    check(action(94,packet(94,'use',{slot=2})).ok,'select exact second weapon instance')
    local beforeWeight=M.weight(S.cache[first].data)
    local install=packet(94,'use',{slot=3})
    check(action(94,install).ok,'install uses held instance')
    local weapon=S.cache[first].data.items['2']
    check(not S.cache[first].data.items['1'].metadata.components and #weapon.metadata.components==1,'never mount on the other copy')
    check(weapon.metadata.serial=='second' and weapon.metadata.durability==73 and weapon.metadata.custom.ownerNote=='keep me','other weapon metadata retained')
    check(weapon.metadata.componentItems.COMPONENT_AT_PI_SUPP_02.metadata.quality==81,'attachment itself retains original metadata')
    check(M.weight(S.cache[first].data)==beforeWeight,'mounted attachment weight retained')
    check(action(94,install).ok and api.GetItem(94,'rp_pistol_suppressor').count==1,'install replay is idempotent')
    check(action(94,packet(94,'use',{slot=3})).error=='no_compatible_weapon','duplicate on held weapon does not redirect to first copy')
    local shown=S.snapshot(94).own.items[2]
    check(#shown.attachments==1 and shown.attachments[1].name=='rp_pistol_suppressor' and not shown.metadata,'UI gets only component display projection')
    local detach=packet(94,'detach',{slot=2,attachment='rp_pistol_suppressor'})
    check(action(94,detach).ok and api.GetItem(94,'rp_pistol_suppressor',{serial='component',quality=81}).count==2,'removal returns original attachment metadata')
    check(action(94,detach).ok and api.GetItem(94,'rp_pistol_suppressor').count==2,'removal replay cannot duplicate')
    check(action(94,packet(94,'detach',{slot=2,attachment='rp_pistol_suppressor'})).error=='component_missing','already removed component refused')
    check(not action(94,packet(94,'detach',{slot=2,attachment='rp_rifle_scope'})).ok,'incompatible return refused')
    check(not action(94,packet(94,'detach',{slot=2,attachment={},count=999})).ok,'malformed detach refused')
    check(action(94,packet(94,'use',{slot=3})).ok,'reinstall')
    local preserved=M.canonical(S.cache[first].data.items['2'].metadata)
    local originalQuery=MySQL.query.await
    MySQL.query.await=function() error('injected attachment SQL failure') end
    check(not action(94,packet(94,'detach',{slot=2,attachment='rp_pistol_suppressor'})).ok,'attachment SQL failure reports failure')
    MySQL.query.await=originalQuery
    check(M.canonical(S.cache[first].data.items['2'].metadata)==preserved and api.GetItem(94,'rp_pistol_suppressor').count==1,'failed detach keeps item and installed attachment together')
    local list=recipients(94)
    check(#list.recipients==1,'second character recipient')
    check(action(94,packet(94,'give',{slot=2,recipient=list.recipients[1].token})).ok,'give mounted gun')
    check(M.canonical(S.cache[second].data.items['1'].metadata)==preserved,'give preserves every nested metadata value')
    local box=api.rpRegisterContainer('attachment_box',{label='Attachments',slots=4,capacity=20000,coords=coords[95]})
    check(api.rpOpenContainer(95,box),'open external container')
    check(action(95,packet(95,'move',{slot=1,to='external',target=1})).ok,'store gun externally')
    check(M.canonical(S.cache[box].data.items['1'].metadata)==preserved,'external store preserves metadata')
    check(action(95,packet(95,'move',{from='external',slot=1,to='own',target=1})).ok,'retrieve mounted gun')
    check(action(95,packet(95,'drop',{slot=1})).ok,'drop mounted gun')
    local drop=ground(94)[1]
    check(drop.components[1]=='COMPONENT_AT_PI_SUPP_02' and not drop.metadata,'world projection includes components without private metadata')
    local claim=pickup(94,drop.id) clock=clock+1000
    check(callbacks['rp_inventory:pickupFinish'](94,claim.token).ok,'another character picks up gun')
    local picked
    for _,entry in pairs(S.cache[first].data.items) do if entry.metadata.serial=='second' then picked=entry end end
    check(picked and M.canonical(picked.metadata)==preserved,'ground roundtrip keeps full metadata and attachments')
    S.cache[first]=nil S.load(first)
    local restored
    for _,entry in pairs(S.cache[first].data.items) do if entry.metadata.serial=='second' then restored=entry end end
    check(restored and M.canonical(restored.metadata)==preserved,'durable reload preserves full item metadata')
    local full=player(96,'char1:full-attachment')
    db[full].data=M.empty(1,2000) S.load(full)
    check(api.AddItem(96,'WEAPON_PISTOL',1,{components={'COMPONENT_AT_PI_FLSH'}},1),'full inventory fixture')
    open(96)
    local before=M.canonical(S.cache[full].data)
    check(action(96,packet(96,'detach',{attachment='rp_pistol_light'})).error=='no_slots','no return slot refuses removal')
    check(M.canonical(S.cache[full].data)==before,'capacity failure cannot lose installed part')
    local broken=packet(94,'detach',{slot=2,attachment='rp_pistol_suppressor'})
    open(94) -- invalidate old view to ensure cross-session detach stays rejected
    check(not action(94,broken).ok,'old view cannot remove components')
    -- Standard ESX usable-item entry point uses the same installation and presentation.
    check(api.AddItem(94,'rp_pistol_light',1),'ESX item fixture')
    usable.rp_pistol_light(94)
    local last=grants[#grants]
    check(last.name=='rp_inventory:effect' and last.payload.kind=='attachment' and last.payload.weaponId,'ESX usable item emits exact-instance animation effect')
end
print(('PASS: %d inventory server/ESX/network/ammo assertions'):format(passed))
