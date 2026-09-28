local S, M, C = Inventory.store, Inventory.model, Clothing
local pending, published, requests = {}, {}, {}

-- Existing creator clothes become owned items once, in the same durable payload.
-- users.skin remains the ESX identity/face baseline; worn items are the clothes authority.
function S.initializeClothing(source)
    local session = S.player(source)
    local row = session and S.cache[session.id]
    if not row or row.data.clothing then return row ~= nil end
    local raw = MySQL.scalar.await('SELECT skin FROM users WHERE BINARY identifier = BINARY ?', { session.identifier })
    local decoded, skin = pcall(json.decode, raw or '{}')
    if not decoded or type(skin) ~= 'table' or not S.live(source, session) then return false end
    local sex = tonumber(skin.sex) == 1 and 1 or 0
    local ok, reason = S.forPlayer(source, 'clothing:initial-outfit', function(data)
        if data.clothing then return true end
        data.clothing = { version = 1, sex = sex, worn = {} }
        for _, category in ipairs(C.order) do
            local cat = C.categories[category]
            local drawable = skin[cat.prefix .. '_1']
            if type(drawable) == 'number' and drawable ~= cat.empty[sex] and drawable >= 0 then
                local patch = C.patch(category, skin)
                if not patch then return false, 'invalid_garment' end
                local id = S.token('garment')
                local product = C.products[('%s_%d_%d'):format(category, sex, drawable)]
                local added, err = M.add(data, 'clothing_' .. category, 1, { garment = {
                    id = id, sex = sex, skin = patch, product = product and product.id,
                    label = product and product.label or ('Einreise · ' .. cat.label)
                } })
                if not added then return false, err end
                data.clothing.worn[category] = id
            end
        end
        return true
    end)
    if not ok then print(('[rp_inventory] Clothing initialization deferred (%s). Existing outfit retained.'):format(tostring(reason))) end
    return ok
end

function S.prepareClothing(copies, ids)
    for _, id in ipairs(ids) do
        local data = copies[id]
        for _, entry in pairs(data.items) do
            local def = Inventory.items[entry.name]
            if def.clothing then
                local garment = entry.metadata.garment
                if garment == nil then
                    -- Standard xPlayer.addInventoryItem remains usable. Generic grants use
                    -- a server catalog default; shops supply the selected product metadata.
                    local sex = data.clothing and data.clothing.sex or 0
                    local product
                    for _, p in pairs(C.products) do
                        if p.category == def.clothing and p.sex == sex and (not product or p.id < product.id) then product = p end
                    end
                    if not product then return false, 'invalid_garment' end
                    garment = { sex = sex, product = product.id, label = product.label, skin = M.copy(product.skin) }
                    entry.metadata.garment = garment
                end
                if type(garment) ~= 'table' then return false, 'invalid_garment' end
                garment.id = garment.id or S.token('garment')
                if entry.count ~= 1 or not M.garment(entry) then return false, 'invalid_garment' end
            end
        end
        if not M.clothingNormalize(data) then return false, 'invalid_garment' end
    end
    return true
end

function S.clothingState(source, force)
    local session = S.player(source)
    local data = session and S.cache[session.id] and S.cache[session.id].data
    local skin = data and M.clothingSkin(data)
    if not skin then return end
    local signature = session.generation .. M.canonical(skin)
    if force or published[source] ~= signature then
        published[source] = signature
        TriggerClientEvent('rp_inventory:clothingState', source, { skin = skin, sex = data.clothing.sex, generation = session.generation })
    end
end

-- Called while *all* store locks are held, before the SQL commit. Moving an item
-- to another slot doesn't change the worn-ID map and never starts an animation.
function S.animateClothing(copies, ids, tickets, guard)
    for _, id in ipairs(ids) do
        local before, after = S.cache[id].data, copies[id]
        if before.clothing and M.canonical(before.clothing.worn) ~= M.canonical(after.clothing.worn) then
            local source = S.owners[id]
            local session = source and S.player(source)
            if session and session.id == id then
                if not S.playable(source) then return false, 'player_unavailable' end
                local category = 'top'
                for _, cat in ipairs(C.order) do
                    if before.clothing.worn[cat] ~= after.clothing.worn[cat] then category = cat break end
                end
                local duration = (C.animations[category] or C.animations.default).duration
                local ticket = { token = S.token('dress'), source = source, session = session, earliest = GetGameTimer() + duration,
                    deadline = GetGameTimer() + 7000, category = category }
                pending[source] = ticket
                tickets[#tickets + 1] = ticket
                TriggerClientEvent('rp_inventory:clothingAnimate', source, ticket.token, category, session.generation)
            end
        end
    end
    for _, ticket in ipairs(tickets) do
        while GetGameTimer() < ticket.deadline do
            if not S.live(ticket.source, ticket.session) or not S.playable(ticket.source) or (guard and not guard())
                or ticket.failed then return false, 'clothing_interrupted' end
            if ticket.done and GetGameTimer() >= ticket.earliest then break end
            Wait(50)
        end
        if not ticket.done then return false, 'clothing_interrupted' end
    end
    return true
end
function S.finishClothing(tickets)
    for _, ticket in ipairs(tickets) do
        if pending[ticket.source] == ticket then pending[ticket.source] = nil end
        if S.live(ticket.source, ticket.session) then
            S.clothingState(ticket.source, true)
            TriggerClientEvent('rp_inventory:clothingFinish', ticket.source, ticket.token)
        end
    end
end
RegisterNetEvent('rp_inventory:clothingAck', function(token, ok)
    local ticket = pending[source]
    if not ticket or token ~= ticket.token or ticket.done or ticket.failed then return end
    if ok == true then ticket.done = true else ticket.failed = true end
end)
RegisterNetEvent('rp_inventory:clothingRequest', function()
    local source = source
    if (requests[source] or 0) > GetGameTimer() then return end
    requests[source] = GetGameTimer() + 2000
    if S.player(source) then
        S.initializeClothing(source)
        S.clothingState(source, true)
    end
end)
local function cleanup(source) pending[source], published[source], requests[source] = nil, nil, nil end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('esx:playerLogout', cleanup)
exports('rpClothingState', function(source)
    local session = S.player(source)
    local data = session and S.cache[session.id] and S.cache[session.id].data
    if not data or not data.clothing then return nil end
    local current = {}
    for _, entry in pairs(data.items) do
        local display = M.clothingDisplay(data, entry)
        if display and display.worn then current[#current + 1] = display end
    end
    return { sex = data.clothing.sex, skin = M.clothingSkin(data), current = current }
end)
exports('rpResolveClothing', function(identifier, skin)
    if type(identifier) ~= 'string' or type(skin) ~= 'table' then return skin end
    local id = 'player:' .. identifier
    local row = S.cache[id]
    local data = row and row.data
    if not data then
        -- Character selection can inspect unused slots. Do not retain every
        -- offline character inventory in the live provider cache.
        local raw = MySQL.scalar.await('SELECT payload FROM rp_inventory_stores WHERE id = ?', { id })
        if raw then data = json.decode(raw) assert(M.valid(data), 'Invalid saved clothing inventory') end
    end
    local patch = data and M.clothingSkin(data)
    local result = M.copy(skin)
    if patch then for k, v in pairs(patch) do result[k] = v end end
    return result
end)
