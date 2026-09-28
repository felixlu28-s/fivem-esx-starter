-- Run with Lua 5.4. Real domain logic and server transaction coordinator, mocked host/SQL.
local base, passed = 'server-data/resources/[custom]/rp_inventory/', 0
local function check(value, message) assert(value, message) passed = passed + 1 end
dofile(base .. 'shared/items.lua')
dofile(base .. 'shared/model.lua')
local M = Inventory.model
do
    local d=M.empty()
    check(M.add(d,'rp_water',4,nil,1.0),'whole float preferred slot normalizes to canonical key')
    check(M.move(d,d,1.0,3.0,2.0),'float slot move stays in same inventory')
    check(d.items['1'].count==2 and d.items['3'].count==2 and not d.items['3.0'],'slot keys stay canonical')
    check(M.remove(d,'rp_water',1,nil,3.0),'float preferred removal')
end
local function seeded()
    local data = M.empty()
    assert(M.add(data, 'rp_water', 8))
    assert(M.add(data, 'rp_backpack_small', 1))
    assert(M.add(data, 'WEAPON_PISTOL', 1))
    return data
end
local data = seeded()
check(data.items['1'].count == 6 and data.items['2'].count == 2, 'per-slot stack maximum splits stacks')
check(M.weight(data) == 6200, 'integer gram weight includes all items')
for _, value in ipairs({ -1, 0, 0.5, math.huge, -math.huge, 0/0, '2', {}, true }) do
    check(not M.add(M.copy(data), 'rp_water', value), 'invalid quantity add rejected')
    check(not M.remove(M.copy(data), 'rp_water', value), 'invalid quantity remove rejected')
    check(not M.move(M.copy(data), M.empty(), 1, 1, value), 'invalid transfer count rejected')
end
check(not M.add(M.copy(data), 'not_registered', 1), 'unknown items rejected')
check(not M.remove(M.copy(data), 'rp_water', 9), 'insufficient stack amount rejected')
check(not M.move(M.copy(data), M.empty(), -1, 1, 1), 'negative slot rejected')
check(not M.move(M.copy(data), M.empty(), 1, 25, 1), 'out of range destination rejected')
check(not M.add(M.empty(1, 25000), 'rp_water', 7), 'capacity in slots enforced')
check(not M.add(M.empty(24, 400), 'rp_water', 1), 'weight enforced')
local copy = M.copy(data)
check(M.move(copy, copy, 1, 2, 3), 'stack merge succeeds')
check(copy.items['1'].count == 3 and copy.items['2'].count == 5, 'split preserves quantities')
check(not M.move(M.copy(data), M.copy(data), 1, 2, 5), 'overfull stack cannot silently overflow')
copy = M.copy(data)
check(M.move(copy, copy, 1, 4, 6), 'full stacks swap')
check(copy.items['1'].name == 'WEAPON_PISTOL' and copy.items['4'].count == 6, 'swap preserves identities')
check(not M.move(M.copy(data), M.empty(), 1, 1, 7), 'cannot transfer more than selected stack')
check(not M.move(copy, copy, 4, 1, 2), 'partial stack cannot replace different item')
check(M.equip(data, 3), 'backpack equips atomically')
local slots, capacity = M.limits(data)
check(slots == 32 and capacity == 35000 and M.weight(data) == 6200, 'equipped bag grants slots and weight, itself still weighs')
check(M.count(data, 'rp_backpack_small') == 1, 'equipped backpack remains owned to ESX')
check(M.add(data, 'rp_bandage', 1, {}, 32), 'expanded slot usable')
check(not M.unequip(M.copy(data)), 'cannot unequip while expanded slots occupied')
check(not M.remove(M.copy(data), 'rp_backpack_small', 1), 'ESX cannot bypass bag capacity protection')
check(M.remove(data, 'rp_bandage', 1), 'remove overflow item')
check(M.unequip(data) and M.count(data, 'rp_backpack_small') == 1, 'unequip preserves bag')
copy = M.empty()
check(M.add(copy, 'rp_water', 2, { serial = 'A' }) and M.add(copy, 'rp_water', 2, { serial = 'B' }), 'metadata items inserted')
check(copy.items['1'].count == 2 and copy.items['2'].count == 2, 'distinct metadata never merge')
check(M.count(copy, 'rp_water', { serial = 'A' }) == 2, 'metadata-filtered count')
check(not M.remove(M.copy(copy), 'rp_water', 3, { serial = 'A' }), 'metadata-filtered removal cannot consume other stack')
check(M.canonical({ a = 1, b = 2 }) == M.canonical({ b = 2, a = 1 }), 'metadata order irrelevant')

-- Random successful and refused moves conserve all inventory, including swapped metadata.
math.randomseed(73)
local a, b = seeded(), seeded()
for _ = 1, 600 do
    local ac, bc = M.copy(a), M.copy(b)
    local from, to = math.random(2) == 1 and ac or bc, math.random(2) == 1 and ac or bc
    local slot, target, amount = math.random(24), math.random(24), math.random(6)
    if M.move(from, to, slot, target, amount) then a, b = ac, bc end
    check(M.count(a, 'rp_water') + M.count(b, 'rp_water') == 16, 'random transfers conserve consumables')
    check(M.count(a, 'WEAPON_PISTOL') + M.count(b, 'WEAPON_PISTOL') == 2, 'random transfers conserve weapons')
    check(M.valid(a) and M.valid(b), 'random resulting stores valid')
end

-- Execute actual server coordinator with SQL failures, replay, liveness changes and contention.
local db, receipts, events, player, updateCalls = {}, {}, {}, nil, 0
local copiedJson, nextJson = {}, 0
json = { encode = function(v) nextJson = nextJson + 1 copiedJson[tostring(nextJson)] = M.copy(v) return tostring(nextJson) end,
    decode = function(v) return M.copy(copiedJson[v]) end }
local failCall, beforeReceipt, afterCommit = false, nil, nil
MySQL = { ready = function() end, single = {}, scalar = {}, query = {}, insert = {} }
MySQL.single.await = function(_, params)
    local row = db[params[1]]
    if not row then return nil end
    return { id = row.id, kind = 'player', label = row.id, payload = json.encode(row.data), context = json.encode({}), revision = row.revision }
end
MySQL.scalar.await = function(_, params)
    if beforeReceipt then local fn = beforeReceipt beforeReceipt = nil fn() end
    return receipts[params[1] .. ':' .. params[2]]
end
MySQL.query.await = function(_, p)
    if failCall then error('simulated database failure') end
    updateCalls = updateCalls + 1
    assert(db[p[4]].revision == p[5], 'SQL CAS')
    if p[7] then assert(db[p[7]].revision == p[8], 'SQL second CAS') end
    db[p[4]].data, db[p[4]].revision = json.decode(p[6]), p[5] + 1
    if p[7] then db[p[7]].data, db[p[7]].revision = json.decode(p[9]), p[8] + 1 end
    receipts[p[1] .. ':' .. p[2]] = p[3]
    if afterCommit then afterCommit() end
end
exports = { es_extended = { getSharedObject = function() return { GetPlayerFromId = function() return player end } end } }
function AddEventHandler(name, fn) events[name] = fn end
function SetTimeout() end
function GetCurrentResourceName() return 'rp_inventory' end
function DropPlayer() end
dofile(base .. 'server/store.lua')
local S = Inventory.store
S.ready = true
S.changed = function() end
db['player:char1:account'] = { id = 'player:char1:account', data = seeded(), revision = 0 }
db['player:char2:account'] = { id = 'player:char2:account', data = M.empty(), revision = 0 }
local first, second = 'player:char1:account', 'player:char2:account'
S.load(first) S.load(second)
local live = true
local function transfer(request, fingerprint, revA, revB)
    return S.mutate({ first, second }, 'char1:account', request, fingerprint or request,
        { [first] = revA or 0, [second] = revB or 0 }, function() return live end,
        function(copies) return M.move(copies[first], copies[second], 1, 1, 2) end)
end
check(transfer('test-one'), 'atomic two-store mutation')
check(M.count(db[first].data, 'rp_water') == 6 and M.count(db[second].data, 'rp_water') == 2, 'character identifiers isolate storage')
local ok, err, replayed = transfer('test-one')
check(ok and replayed and updateCalls == 1, 'same request never executes twice even with old revisions')
check(not transfer('test-one', 'changed'), 'reused request with different fingerprint rejected')
ok, err = transfer('test-stale')
check(not ok and err == 'stale_inventory' and updateCalls == 1, 'stale UI cannot overwrite state')
failCall = true
ok, err = transfer('test-db-failure', nil, 1, 1)
check(not ok and err == 'database_error', 'failed SQL operation rejected')
check(M.count(S.cache[first].data, 'rp_water') == 6 and M.count(S.cache[second].data, 'rp_water') == 2, 'failed SQL cannot modify cache')
check(not S.locks[first] and not S.locks[second], 'failure releases both locks')
failCall = false
beforeReceipt = function()
    local concurrent, reason = transfer('test-concurrent', nil, 1, 1)
    check(not concurrent and reason == 'busy', 'concurrent mutation cannot enter held locks')
end
check(transfer('test-lock', nil, 1, 1), 'first lock holder commits')
beforeReceipt = function() live = false end
ok, err = transfer('test-disconnect', nil, 2, 2)
check(not ok and err == 'session_expired' and updateCalls == 2, 'disconnect across SQL await prevents mutation')
live = true
afterCommit = function() live = false end
check(transfer('test-commit-disconnect', nil, 2, 2), 'already committed inventory survives disconnect before acknowledgement')
check(M.count(db[first].data, 'rp_water') == 2 and M.count(db[second].data, 'rp_water') == 6, 'committed conservation after disconnect')
check(not S.locks[first] and not S.locks[second], 'all locks released after disconnect')
print(('PASS: %d inventory assertions (including 600 randomized transfers)'):format(passed))
