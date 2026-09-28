local S, M, ESX = Inventory.store, Inventory.model, exports.es_extended:getSharedObject()
local views, containers, rates = {}, {}, {}
local weaponChoices = {}
function S.weaponEffect(source, data, slot, kind)
    local entry = data.items[tostring(slot)]
    entry.metadata.weaponId = entry.metadata.weaponId or S.token('weapon')
    return { kind = kind or 'weapon', name = entry.name, weaponId = entry.metadata.weaponId,
        generation = S.player(source).generation }
end
function S.installAttachment(source, data, slot)
    local item = data.items[tostring(slot)]
    local def = item and Inventory.items[item.name]
    local choices = weaponChoices[source]
    local ok, reason, weaponSlot = M.installComponent(data, slot, choices and def and choices[def.weaponName])
    if not ok then return false, reason end
    local effect = S.weaponEffect(source, data, weaponSlot, 'attachment')
    effect.component, effect.install = def.component, true
    return true, nil, effect
end
function S.sendWeaponEffect(source, effect)
    if effect.weaponId then
        weaponChoices[source] = weaponChoices[source] or {}
        weaponChoices[source][effect.name] = effect.weaponId
    end
    TriggerClientEvent('rp_inventory:effect', source, effect)
end
local function playable(source)
    local session, player = S.player(source)
    local ped = GetPlayerPed(source)
    return session and player and player.spawned and ped ~= 0 and GetEntityHealth(ped) > 0
end
S.playable = playable
local function position(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return { x = coords.x, y = coords.y, z = coords.z, bucket = GetPlayerRoutingBucket(source) }
end
local function nearby(source, context, distance)
    if not playable(source) or type(context) ~= 'table' or type(context.x) ~= 'number' then return false end
    local p = position(source)
    return p.bucket == context.bucket and (p.x - context.x)^2 + (p.y - context.y)^2 + (p.z - context.z)^2 <= (distance or 3)^2
end
local function access(source, row)
    if not row then return false end
    if row.kind == 'drop' then return false end -- Retired persistent ground containers.
    local def, session = containers[row.id], S.player(source)
    if not def or not session or (def.owner and def.owner ~= session.identifier) then return false end
    local context = def.position and def.position(source) or row.context
    if not nearby(source, context, def.radius) then return false end
    if def.authorize then
        local ok, allowed = pcall(def.authorize, source)
        return ok and allowed == true
    end
    return true
end
S.access = access
local function allowedRate(source, key, delay)
    rates[source] = rates[source] or {}
    local now = GetGameTimer()
    if (rates[source][key] or 0) > now then return false end
    rates[source][key] = now + delay
    return true
end
local function display(row, side)
    local slots, capacity = M.limits(row.data)
    local items = {}
    local function entry(e, slot)
        local def = Inventory.items[e.name]
        local clothing = M.clothingDisplay(row.data, e)
        return { slot = slot, name = e.name, label = clothing and clothing.label or def.label, count = e.count, weight = def.weight,
            artwork = clothing and clothing.artwork or def.artwork, gxt = clothing and clothing.gxt,
            maxStack = def.maxStack, icon = def.icon, description = def.description,
            usable = def.use ~= nil or ESX.GetUsableItems()[e.name] ~= nil,
            bonusSlots = def.slots or 0, bonusWeight = def.capacity or 0, attachments = M.componentList(e), clothing = clothing }
    end
    for slot, e in pairs(row.data.items) do items[#items + 1] = entry(e, tonumber(slot)) end
    table.sort(items, function(a, b) return a.slot < b.slot end)
    return { side = side, label = row.label, revision = row.revision, slots = slots, capacity = capacity,
        weight = M.weight(row.data), items = items, backpack = row.data.backpack and entry(row.data.backpack, 0) or nil }
end
function S.snapshot(source)
    local session, view = S.player(source), views[source]
    if not session or not view or view.generation ~= session.generation then return nil end
    local row = S.cache[session.id]
    if not row then return nil end
    local external = view.external and S.cache[view.external]
    if external and not access(source, external) then view.external, external = nil, nil end
    return { session = view.token, own = display(row, 'own'), external = external and display(external, 'external') or nil }
end
function S.publish(ids)
    for source, view in pairs(views) do
        -- Filter on our session index; only affected viewers need the ESX snapshot/export.
        local session = S.players[source]
        for _, id in ipairs(ids) do
            if session and (session.id == id or view.external == id) then
                local payload = S.snapshot(source)
                if payload then TriggerClientEvent('rp_inventory:refresh', source, payload) end
                break
            end
        end
    end
end
local function open(source, external)
    if not playable(source) then return { ok = false, error = 'player_unavailable' } end
    local session = S.player(source)
    if external and not access(source, S.cache[external]) then return { ok = false, error = 'out_of_range' } end
    if not external then
        local distance = math.huge
        local p = position(source)
        for id, row in pairs(S.cache) do
            if row.kind ~= 'player' and access(source, row) then
                local d = (p.x - row.context.x)^2 + (p.y - row.context.y)^2 + (p.z - row.context.z)^2
                if d < distance then external, distance = id, d end
            end
        end
    end
    views[source] = { token = S.token('view'), generation = session.generation, external = external, expires = os.time() + 600 }
    return { ok = true, inventory = S.snapshot(source) }
end
lib.callback.register('rp_inventory:open', function(source)
    if not allowedRate(source, 'open', 400) then return { ok = false, error = 'rate_limited' } end
    return open(source)
end)
lib.callback.register('rp_inventory:refresh', function(source)
    if not allowedRate(source, 'refresh', 500) then return { ok = false, error = 'rate_limited' } end
    return { ok = S.snapshot(source) ~= nil, inventory = S.snapshot(source) }
end)
RegisterNetEvent('rp_inventory:close', function() views[source] = nil end)

-- Short-lived recipient capabilities are scoped to the sender's inventory view
-- and the recipient's character session. Client IDs never select a destination.
lib.callback.register('rp_inventory:recipients', function(source, token)
    if not allowedRate(source, 'recipients', 500) then return { ok = false, error = 'rate_limited' } end
    local session, view = S.player(source), views[source]
    if not session or not view or token ~= view.token or view.generation ~= session.generation
        or view.expires < os.time() or not playable(source) then return { ok = false, error = 'session_expired' } end
    local candidates, origin = {}, position(source)
    for target in pairs(S.players) do
        if target ~= source and playable(target) and nearby(target, origin, 3) then
            local recipient, player = S.player(target)
            local pos = position(target)
            local name = player.getName and player.getName() or 'Spieler'
            if type(name) ~= 'string' or #name > 120 then name = 'Spieler' end
            candidates[#candidates + 1] = { source = target, session = recipient,
                label = ('%s (#%s)'):format(name, target),
                distance = math.sqrt((pos.x - origin.x)^2 + (pos.y - origin.y)^2 + (pos.z - origin.z)^2) }
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    view.recipients = {}
    local result = {}
    for i = 1, math.min(16, #candidates) do
        local candidate, key = candidates[i], S.token('recipient')
        view.recipients[key] = { source = candidate.source, session = candidate.session, expires = GetGameTimer() + 15000 }
        result[#result + 1] = { token = key, label = candidate.label, distance = math.floor(candidate.distance * 10) / 10 }
    end
    return { ok = true, recipients = result }
end)

local function validRequest(p)
    if type(p) ~= 'table' or type(p.session) ~= 'string' or #p.session > 80 or type(p.request) ~= 'string'
        or #p.request < 8 or #p.request > 80 or not p.request:match('^[%w_-]+$')
        or not ({ move = true, drop = true, use = true, unequip = true, give = true, detach = true })[p.action]
        or not M.integer(p.ownRevision, 0, 9007199254740991) then return false end
    if p.action == 'unequip' then return true end
    if p.from ~= 'own' and p.from ~= 'external' then return false end
    if not M.integer(p.slot, 1, 216) or not M.integer(p.count, 1, 100000) then return false end
    if p.action == 'move' and ((p.to ~= 'own' and p.to ~= 'external') or not M.integer(p.target, 1, 216)) then return false end
    if p.action == 'give' and (p.from ~= 'own' or type(p.recipient) ~= 'string' or #p.recipient > 80) then return false end
    if p.action == 'detach' and (p.from ~= 'own' or p.count ~= 1 or type(p.attachment) ~= 'string' or #p.attachment > 80) then return false end
    if (p.from == 'external' or p.to == 'external') and not M.integer(p.externalRevision, 0, 9007199254740991) then return false end
    return true
end
lib.callback.register('rp_inventory:action', function(source, p)
    if not allowedRate(source, 'action', 120) then return { ok = false, error = 'rate_limited' } end
    if not validRequest(p) then return { ok = false, error = 'invalid_request' } end
    -- Retain only contract fields; unknown nested client payloads cannot enter fingerprints/storage.
    local raw = p
    p = { session = raw.session, request = raw.request, action = raw.action, ownRevision = math.tointeger(raw.ownRevision) }
    -- NUI/MessagePack may deliver whole numbers as floats. Store keys are canonical "1", never "1.0".
    if p.action ~= 'unequip' then p.from, p.slot, p.count = raw.from, math.tointeger(raw.slot), math.tointeger(raw.count) end
    if p.action == 'give' then p.recipient = raw.recipient end
    if p.action == 'detach' then p.attachment = raw.attachment end
    if p.action == 'move' then
        p.to, p.target = raw.to, math.tointeger(raw.target)
        if p.from == 'external' or p.to == 'external' then p.externalRevision = math.tointeger(raw.externalRevision) end
    end
    local session, view = S.player(source), views[source]
    if not session or not view or view.generation ~= session.generation or p.session ~= view.token or view.expires < os.time()
        or not playable(source) then return { ok = false, error = 'session_expired' } end
    -- The view authorizes admission, not the lifetime of an accepted operation.
    -- Closing/reopening I must not cancel an ongoing clothing animation/commit.
    -- Subsequent guards retain character generation, expiry, health and access;
    -- a NEW request still needs the current view token above and all store locks.
    local own, external = session.id, view.external
    if p.action == 'drop' then
        if p.from ~= 'own' then return { ok=false, error='invalid_state' } end
        local ok,err=S.dropItem(source,p,function()
            return S.live(source,session) and view.expires>=os.time() and playable(source)
        end)
        return { ok=ok,error=err,inventory=S.snapshot(source) }
    end
    if p.action == 'give' then
        local choice = view.recipients and view.recipients[p.recipient]
        local function guard()
            return choice and choice.source ~= source and choice.expires >= GetGameTimer()
                and S.live(source, session) and view.expires >= os.time() and playable(source)
                and S.live(choice.source, choice.session) and playable(choice.source)
                and nearby(source, position(choice.source), 3)
        end
        if not guard() then return { ok = false, error = 'recipient_unavailable', inventory = S.snapshot(source) } end
        local target = choice.session.id
        local row = S.cache[target]
        if not row then return { ok = false, error = 'recipient_unavailable' } end
        local ok, err = S.mutate({ own, target }, session.identifier, p.request, M.canonical(p),
            { [own] = p.ownRevision, [target] = row.revision }, guard, function(copies)
                local entry = copies[own].items[tostring(p.slot)]
                if not entry then return false, 'not_enough' end
                local removed, reason = M.remove(copies[own], entry.name, p.count, entry.metadata, p.slot)
                if not removed then return false, reason end
                -- Add automatically; never swap against an unsuspecting recipient's slot.
                return M.add(copies[target], entry.name, p.count, entry.metadata)
            end)
        return { ok = ok, error = err, inventory = S.snapshot(source) }
    end
    local ids, revisions = { own }, { [own] = p.ownRevision }
    if p.from == 'external' or p.to == 'external' then
        if not external or not access(source, S.cache[external]) then return { ok = false, error = 'out_of_range', inventory = S.snapshot(source) } end
        ids[#ids + 1], revisions[external] = external, p.externalRevision
    end
    if (p.action == 'drop' or p.action == 'use') and p.from ~= 'own' then return { ok = false, error = 'invalid_state' } end
    local effect
    local function guard()
        return S.live(source, session) and view.expires >= os.time() and playable(source)
            and (not external or access(source, S.cache[external]))
    end
    local ok, err, replayed = S.mutate(ids, session.identifier, p.request, M.canonical(p), revisions, guard, function(copies)
        local data = copies[own]
        if p.action == 'unequip' then return M.unequip(data) end
        local from = copies[p.from == 'own' and own or external]
        local e = from and from.items[tostring(p.slot)]
        if not e or p.count > e.count then return false, 'not_enough' end
        if p.action == 'move' then return M.move(from, copies[p.to == 'own' and own or external], p.slot, p.target, p.count) end
        local def = Inventory.items[e.name]
        if not allowedRate(source, 'use', 1800) then return false, 'rate_limited' end
        if p.action == 'detach' then
            local removed, reason = M.removeComponent(data, p.slot, p.attachment)
            if not removed then return false, reason end
            effect = S.weaponEffect(source, data, p.slot, 'attachment')
            effect.component, effect.install = Inventory.items[p.attachment].component, false
            return true
        end
        if def.use == 'backpack' then return M.equip(data, p.slot) end
        if def.use == 'clothing' then return M.clothingUse(data, p.slot) end
        if def.use == 'weapon' then effect = S.weaponEffect(source, data, p.slot) return true end
        if def.use == 'component' then
            local installed, reason, presentation = S.installAttachment(source, data, p.slot)
            effect = presentation
            return installed, reason
        end
        if def.use then
            effect = { kind = def.use, name = e.name }
            return M.remove(data, e.name, 1, e.metadata, p.slot)
        end
        if ESX.GetUsableItems()[e.name] then effect = { kind = 'esx', name = e.name } return true end
        return false, 'not_usable'
    end)
    if ok and S.live(source, session) then
        if effect and not replayed then
            if effect.kind == 'esx' then
                -- Receipt is durable before external callback. Callback owns its own consumption.
                local used, useErr = pcall(ESX.UseItem, source, effect.name)
                if not used then print('[rp_inventory] ESX usable callback failed: ' .. tostring(useErr)) end
            else S.sendWeaponEffect(source, effect) end
        end
    end
    return { ok = ok, error = err, inventory = S.snapshot(source) }
end)

function S.registerContainer(resource, id, options)
    if not resource or type(id) ~= 'string' or not id:match('^[%w_:-]+$') or #id > 100 or type(options) ~= 'table'
        or type(options.label) ~= 'string' or #options.label > 80 or not M.integer(options.slots, 1, 200)
        or not M.integer(options.capacity, 1, 10000000) or type(options.coords) ~= 'table' then return false end
    local c = options.coords
    for _, axis in ipairs({ 'x', 'y', 'z' }) do if type(c[axis]) ~= 'number' or c[axis] ~= c[axis] or math.abs(c[axis]) > 20000 then return false end end
    if not M.integer(c.bucket or 0, 0, 2147483647) then return false end
    local key = 'container:' .. resource .. ':' .. id
    if #key > 160 then return false end
    local context = { x = c.x, y = c.y, z = c.z, bucket = c.bucket or 0 }
    local row = S.cache[key] or S.create(key, 'container', options.label, M.empty(options.slots, options.capacity), context)
    row.context = context
    containers[key] = { resource = resource, owner = options.owner, authorize = options.authorize,
        position = options.position, radius = math.min(3, math.max(0.5, tonumber(options.radius) or 3)) }
    return key
end
function S.openContainer(resource, source, id)
    local def = containers[id]
    if not def or def.resource ~= resource then return false end
    local result = open(source, id)
    if result.ok then TriggerClientEvent('rp_inventory:show', source, result.inventory) end
    return result.ok, result.error
end
exports('rpRegisterContainer', function(id, options)
    return S.registerContainer(GetInvokingResource(), id, options)
end)
exports('rpOpenContainer', function(source, id)
    return S.openContainer(GetInvokingResource(), source, id)
end)
-- Atomic player-to-player transfers for future give/trade UIs; server resources only.
exports('rpTransfer', function(source, target, slot, count, targetSlot, request)
    local a, b = S.player(source), S.player(target)
    if not a or not b or source == target or not playable(source) or not nearby(source, position(target), 3)
        or type(request) ~= 'string' or #request < 8 or #request > 64 or not request:match('^[%w_-]+$') then return false, 'invalid_request' end
    return S.mutate({ a.id, b.id }, a.identifier, 'give-' .. request,
        M.canonical({ target = b.identifier, slot = slot, count = count, targetSlot = targetSlot }), nil,
        function() return S.live(source, a) and S.live(target, b) and playable(source) and playable(target) and nearby(source, position(target), 3) end,
        function(copies) return M.move(copies[a.id], copies[b.id], slot, targetSlot, count) end)
end)
RegisterCommand('rp_inventory_test', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'rp.inventory.test') then return end
    local target = source == 0 and tonumber(args[1]) or source
    if not target then return print('rp_inventory_test <player-id>') end
    local ok, err = S.forPlayer(target, 'admin:test-kit', function(data)
        for _, item in ipairs({ { 'rp_water', 4 }, { 'rp_sandwich', 3 }, { 'rp_bandage', 3 }, { 'rp_backpack_small', 1 },
            { 'rp_backpack_large', 1 }, { 'WEAPON_PISTOL', 1 }, { 'WEAPON_CARBINERIFLE', 1 }, { 'ammo_pistol', 60 }, { 'ammo_rifle', 90 } }) do
            local added, reason = M.add(data, item[1], item[2])
            if not added then return false, reason end
        end
        return true
    end)
    print(('[rp_inventory] Test kit target=%s result=%s %s'):format(tostring(target), tostring(ok), err or ''))
end, false)
RegisterCommand('rp_inventory_box', function(source)
    if source == 0 or not IsPlayerAceAllowed(source, 'rp.inventory.test') or not playable(source) then return end
    local session, context = S.player(source), position(source)
    local id = 'testbox:' .. session.identifier
    if not S.cache[id] then S.create(id, 'container', 'Deine Testkiste', M.empty(48, 100000), context) end
    -- A repeat opens the same box at its original location, never moves existing storage remotely.
    containers[id] = { resource = GetCurrentResourceName(), owner = session.identifier, radius = 3 }
    local result = open(source, id)
    if result.ok then TriggerClientEvent('rp_inventory:show', source, result.inventory) end
end, false)

CreateThread(function()
    while not S.ready do Wait(500) end
    while true do
        Wait(2000)
        for source, view in pairs(views) do
            if not playable(source) or view.expires < os.time() then
                views[source] = nil TriggerClientEvent('rp_inventory:hide', source)
            elseif view.external and not access(source, S.cache[view.external]) then
                view.external = nil
                TriggerClientEvent('rp_inventory:refresh', source, S.snapshot(source))
            end
        end
    end
end)
S.cleanup = function(source) views[source], rates[source], weaponChoices[source] = nil, nil, nil if S.clearWeapons then S.clearWeapons(source) end end
AddEventHandler('onResourceStop', function(resource)
    for id, def in pairs(containers) do if def.resource == resource then containers[id] = nil end end
end)
