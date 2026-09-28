local S, M = { cache = {}, locks = {}, players = {}, owners = {}, ready = false }, Inventory.model
Inventory.store = S
local ESX = exports.es_extended:getSharedObject()
local sequence = 0
local boot = ('%x-%x'):format(os.time(), math.random(0, 0x7fffffff))
function S.token(prefix)
    sequence = sequence + 1
    return ('%s-%s-%x'):format(prefix or 'op', boot, sequence)
end
function S.player(source)
    local session, player = S.players[source], ESX.GetPlayerFromId(source)
    if session and player and player.identifier == session.identifier then
        S.owners[session.id] = source
        return session, player
    end
end
function S.live(source, session)
    return session and S.player(source) == session
end
function S.load(id)
    local row = MySQL.single.await('SELECT id, kind, label, payload, context, revision FROM rp_inventory_stores WHERE id = ?', { id })
    if not row then return nil end
    row.data, row.context = json.decode(row.payload), json.decode(row.context)
    row.payload = nil
    if not M.valid(row.data) then error('Invalid persisted inventory: ' .. id .. '; original data retained, repair required') end
    M.repackAmmo(row.data)
    S.cache[id] = row
    return row
end
function S.create(id, kind, label, data, context, backup)
    MySQL.insert.await('INSERT IGNORE INTO rp_inventory_stores (id, kind, label, payload, context, legacy_backup) VALUES (?, ?, ?, ?, ?, ?)',
        { id, kind, label, json.encode(data), json.encode(context or {}), backup or '' })
    return S.load(id)
end
function S.entries(data)
    local items = {}
    for slot, entry in pairs(data.items) do
        local def = Inventory.items[entry.name]
        local garment = M.garment and M.garment(entry)
        items[tonumber(slot)] = { name = entry.name, label = garment and garment.label or def.label, count = entry.count, slot = tonumber(slot),
            weight = def.weight, stack = def.maxStack > 1, usable = def.use ~= nil or ESX.GetUsableItems()[entry.name] ~= nil,
            metadata = M.copy(entry.metadata), description = def.description }
    end
    -- ESX mirror includes the equipment item at a reserved slot. The provider owns its interpretation.
    if data.backpack then
        local e, def = data.backpack, Inventory.items[data.backpack.name]
        items[1000] = { name = e.name, label = def.label, count = 1, slot = 1000, weight = def.weight,
            stack = false, usable = true, metadata = M.copy(e.metadata) }
    end
    return items
end
function S.sync(source)
    local session, player = S.player(source)
    local row = session and S.cache[session.id]
    if not row then return end
    local _, capacity = M.limits(row.data)
    local entries = S.entries(row.data)
    player.syncInventory(M.weight(row.data), capacity, entries)
    if S.weaponState then S.weaponState(source) end
    if S.clothingState then S.clothingState(source) end
    TriggerClientEvent('esx:setInventory', source, entries)
    TriggerClientEvent('esx:setMaxWeight', source, capacity)
    TriggerClientEvent('rp_inventory:state', source, entries, { revision = row.revision, generation = session.generation })
end
function S.changed(ids)
    for _, id in ipairs(ids) do
        local source = S.owners[id]
        local session = source and S.player(source)
        if session and session.id == id then S.sync(source) end
    end
    if S.publish then S.publish(ids) end
end
-- A mutation owns every involved lock until SQL finishes. ESX exports use the same path.
function S.mutate(ids, actor, request, fingerprint, revisions, guard, transform, clothingAlreadyPreviewed)
    if not S.ready then return false, 'server_starting' end
    local unique, sorted = {}, {}
    for _, id in ipairs(ids) do if not unique[id] then unique[id] = true sorted[#sorted + 1] = id end end
    table.sort(sorted)
    if #sorted < 1 or #sorted > 2 then return false, 'invalid_state' end
    for _, id in ipairs(sorted) do if S.locks[id] then return false, 'busy' end end
    for _, id in ipairs(sorted) do S.locks[id] = true end
    local committed, replayed = false, false
    local clothingTickets = {}
    local ran, success, reason = xpcall(function()
        if guard and not guard() then return false, 'session_expired' end
        local receipt = MySQL.scalar.await('SELECT fingerprint FROM rp_inventory_operations WHERE actor = ? AND request_id = ?', { actor, request })
        if receipt then
            if receipt ~= fingerprint then return false, 'request_reused' end
            for _, id in ipairs(sorted) do S.load(id) end
            replayed = true
            return true
        end
        local copies, versions = {}, {}
        for _, id in ipairs(sorted) do
            local row = S.cache[id] or S.load(id)
            if not row then return false, 'not_found' end
            if revisions and revisions[id] ~= row.revision then return false, 'stale_inventory' end
            versions[id], copies[id] = row.revision, M.copy(row.data)
        end
        if guard and not guard() then return false, 'session_expired' end
        local ok, err = transform(copies)
        if not ok then return false, err end
        if S.prepareClothing then
            local prepared, prepareError = S.prepareClothing(copies, sorted)
            if not prepared then return false, prepareError end
        end
        for _, id in ipairs(sorted) do
            M.repackAmmo(copies[id])
            if not M.valid(copies[id]) then return false, 'invalid_inventory' end
        end
        if guard and not guard() then return false, 'session_expired' end
        if S.animateClothing and not clothingAlreadyPreviewed then
            local animated, animationError = S.animateClothing(copies, sorted, clothingTickets, guard)
            if not animated then return false, animationError end
        end
        if guard and not guard() then return false, 'session_expired' end
        local a, b = sorted[1], sorted[2]
        local params = { actor, request, fingerprint, a, versions[a], json.encode(copies[a]) }
        if b then
            params[7], params[8], params[9] = b, versions[b], json.encode(copies[b])
            MySQL.query.await('CALL rp_inventory_commit(?, ?, ?, ?, ?, ?, ?, ?, ?)', params)
        else MySQL.query.await('CALL rp_inventory_commit(?, ?, ?, ?, ?, ?, NULL, NULL, NULL)', params) end
        -- Read committed authority, including a receipt replay from another runtime.
        committed = true
        for _, id in ipairs(sorted) do S.load(id) end
        return true
    end, debug.traceback)
    if not ran then
        print(('[rp_inventory] Transaction failed: %s'):format(tostring(success)))
        for _, id in ipairs(sorted) do
            S.cache[id] = nil
            pcall(S.load, id)
        end
    end
    for _, id in ipairs(sorted) do S.locks[id] = nil end
    if S.finishClothing then S.finishClothing(clothingTickets) end
    if committed or replayed then S.changed(sorted) end
    if not ran then return false, 'database_error', replayed end
    if success == true then return true, nil, replayed end
    return false, reason or 'invalid_state', replayed
end
function S.forPlayer(source, description, transform)
    local session = S.player(source)
    if not session then return false, 'player_unavailable' end
    return S.mutate({ session.id }, session.identifier, S.token(), description, nil,
        function() return S.live(source, session) end,
        function(copies) return transform(copies[session.id]) end)
end

MySQL.ready(function()
    local ok, err = pcall(function()
        assert(GetConvar('inventory:accounts', '') == '[]', 'Set inventory:accounts "[]" before starting ESX')
        assert(ESX.GetConfig().CustomInventory == 'ox', 'Full FXServer restart required: ESX custom-inventory bridge not active')
        MySQL.query.await('SELECT id FROM rp_inventory_stores LIMIT 1')
        assert(MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME = 'rp_inventory_commit'") == 1,
            'Apply rp_inventory migrations first')
        for _, def in ipairs(MySQL.query.await('SELECT name, label, weight FROM items')) do
            if not Inventory.items[def.name] then
                Inventory.items[def.name] = { name = def.name, label = def.label, weight = math.max(0, math.floor((def.weight or 0) * Inventory.legacyWeightMultiplier)),
                    maxStack = 20, stack = true, icon = 'item', description = def.label, dropModel = Inventory.ground.model }
            end
        end
        S.ready = true
        TriggerEvent('ox_inventory:itemList', Inventory.items)
        TriggerEvent('ox_inventory:loadInventory', Inventory.bridge)
        print('[rp_inventory] Durable inventory provider ready.')
    end)
    if not ok then print('[rp_inventory] NOT READY: ' .. tostring(err)) end
end)

local function cleanup(source)
    local session = S.players[source]
    if session and S.owners[session.id] == source then S.owners[session.id] = nil end
    S.players[source] = nil
    if S.cleanup then S.cleanup(source) end
    -- Transactions persist before acknowledgements; no asynchronous disconnect save can overwrite them.
    if session then SetTimeout(30000, function()
        for _, current in pairs(S.players) do if current.id == session.id then return end end
        if not S.locks[session.id] then S.cache[session.id] = nil end
    end) end
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('esx:playerLogout', cleanup)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    S.ready = false
    for source in pairs(S.players) do DropPlayer(source, 'Inventar wird neu gestartet. Bitte erneut verbinden.') end
end)
