local S, M, ESX = Inventory.store, Inventory.model, exports.es_extended:getSharedObject()
local function metadataValid(value)
    if value == nil then return true end
    if type(value) ~= 'table' then return false end
    local ok, encoded = pcall(json.encode, value)
    return ok and #encoded <= 4096
end
local api = { accounts = {} }
function api.Items(name) return M.copy(name and Inventory.items[name] or Inventory.items) end
function api.GetItem(source, name, metadata, returnsCount)
    local session, def = S.player(source), Inventory.items[name]
    if not session or not def or not metadataValid(metadata) then return returnsCount and 0 or nil end
    local row = S.cache[session.id]
    local item = M.copy(def)
    item.count = row and M.count(row.data, name, metadata) or 0
    item.usable = def.use ~= nil or ESX.GetUsableItems()[name] ~= nil
    item.metadata = metadata or {}
    return returnsCount and item.count or item
end
function api.AddItem(source, name, count, metadata, slot)
    if not metadataValid(metadata) then return false, 'invalid_metadata' end
    return S.forPlayer(source, 'esx:add:' .. tostring(name), function(data) return M.add(data, name, count, metadata, slot) end)
end
function api.RemoveItem(source, name, count, metadata, slot)
    if not metadataValid(metadata) then return false, 'invalid_metadata' end
    return S.forPlayer(source, 'esx:remove:' .. tostring(name), function(data) return M.remove(data, name, count, metadata, slot) end)
end
function api.SetItem(source, name, count, metadata)
    if not M.integer(count, 0, 100000) or not metadataValid(metadata) then return false, 'invalid_item' end
    return S.forPlayer(source, 'esx:set:' .. tostring(name), function(data)
        local difference = count - M.count(data, name, metadata)
        if difference > 0 then return M.add(data, name, difference, metadata) end
        if difference < 0 then return M.remove(data, name, -difference, metadata) end
        return true
    end)
end
function api.CanCarryItem(source, name, count, metadata)
    local session = S.player(source)
    local row = session and S.cache[session.id]
    if not row or not metadataValid(metadata) then return false end
    return M.add(M.copy(row.data), name, count, metadata) == true
end
function api.CanSwapItem(source, first, firstCount, second, secondCount)
    local session = S.player(source)
    local row = session and S.cache[session.id]
    if not row then return false end
    local data = M.copy(row.data)
    return M.remove(data, first, firstCount) and M.add(data, second, secondCount) == true
end
function api.SetMaxWeight(source, weight)
    if not M.integer(weight, 0, 10000000) then return false end
    local ok, err = S.forPlayer(source, 'esx:weight', function(data)
        local bag = data.backpack and Inventory.items[data.backpack.name]
        data.capacity = weight - (bag and bag.capacity or 0)
        return M.valid(data), 'too_heavy'
    end)
    -- Stock bridge writes maxWeight before calling the provider; restore the true value on refusal.
    S.sync(source)
    return ok, err
end
function api.setPlayerInventory(player, legacy)
    local source, identifier = player.source, player.identifier
    local deadline = GetGameTimer() + 15000
    while not S.ready and GetGameTimer() < deadline do Wait(100) end
    local ok, err = pcall(function()
        assert(S.ready, 'Inventory database unavailable')
        local current = ESX.GetPlayerFromId(source)
        assert(current and current.identifier == identifier, 'Character changed during inventory load')
        local id = 'player:' .. identifier
        assert(not S.players[source], 'Inventory already loaded')
        for other, session in pairs(S.players) do assert(other == source or session.identifier ~= identifier, 'Character already active') end
        local row = S.load(id)
        if not row then
            local user = MySQL.single.await('SELECT inventory, loadout FROM users WHERE identifier = ?', { identifier })
            assert(user, 'Missing ESX character')
            local data, valid = M.empty(), true
            local loadout = json.decode(user.loadout or '{}') or {}
            for key, entry in pairs(legacy or {}) do
                local name, count, metadata = key, entry, {}
                if type(entry) == 'table' then name, count, metadata = entry.name, entry.count, entry.metadata or {} end
                if count ~= 0 and not M.add(data, name, count, metadata) then valid = false end
            end
            for key, weapon in pairs(loadout) do
                local name = type(key) == 'string' and key or weapon.name
                local def = Inventory.items[name]
                -- A thrown weapon's native ammo already counts the objects;
                -- don't import an extra free grenade on top of that count.
                local count = def and def.consumable and def.ammoUnits == 1 and math.max(1, weapon.ammo or 0) or 1
                if not def or not def.weapon or not M.add(data, name, count, { components = weapon.components or {}, tintIndex = weapon.tintIndex or 0 }) then valid = false
                elseif def.ammo and not def.consumable and (weapon.ammo or 0) > 0 and not M.add(data, def.ammo, weapon.ammo) then valid = false end
            end
            -- Failed imports are retained as a blocked row. Never seed again from a later ESX autosave.
            if not valid then data = { slots = 0, capacity = 0, items = {}, migrationRequired = true } end
            row = S.create(id, 'player', 'Deine Taschen', data, {}, json.encode({ inventory = user.inventory, loadout = user.loadout }))
            assert(valid, 'Legacy inventory needs manual migration; backup retained')
        end
        current = ESX.GetPlayerFromId(source)
        assert(current and current.identifier == identifier, 'Character disconnected during inventory load')
        S.players[source] = { id = id, identifier = identifier, generation = S.token('session') }
        if S.initializeClothing then S.initializeClothing(source) end
        S.sync(source)
        TriggerEvent('rp_inventory:loaded', source)
    end)
    if not ok then
        print('[rp_inventory] Load failed: ' .. tostring(err))
        local current = ESX.GetPlayerFromId(source)
        if current and current.identifier == identifier then DropPlayer(source, 'Inventar konnte nicht sicher geladen werden. Bitte die Serververwaltung kontaktieren.') end
    end
end
-- Only this documented subset of the ox protocol is provided. It is not a full ox_inventory replacement API.
for name, handler in pairs(api) do
    if type(handler) == 'function' then
        exports(name, handler)
        AddEventHandler('__cfx_export_ox_inventory_' .. name, function(set) set(handler) end)
    end
end
exports('Inventory', function() return api end)
AddEventHandler('__cfx_export_ox_inventory_Inventory', function(set) set(function() return api end) end)
Inventory.bridge = api
exports('rpIsReady', function(source) return S.ready and S.player(source) ~= nil end)

for name, def in pairs(Inventory.items) do
    if def.use then ESX.RegisterUsableItem(name, function(source)
        local session = S.player(source)
        if not session or not S.playable or not S.playable(source) then return end
        local effect
        local ok = S.forPlayer(source, 'esx:use:' .. name, function(data)
            if def.use == 'clothing' then
                for slot, entry in pairs(data.items) do
                    if entry.name == name then return M.clothingUse(data, tonumber(slot)) end
                end
                return false, 'not_enough'
            end
            if def.use == 'backpack' then
                for slot, e in pairs(data.items) do if e.name == name then return M.equip(data, tonumber(slot)) end end
                return false, 'not_enough'
            end
            if def.use == 'weapon' then
                for slot = 1, M.limits(data) do
                    if data.items[tostring(slot)] and data.items[tostring(slot)].name == name then
                        effect = S.weaponEffect(source, data, slot)
                        return true
                    end
                end
                return false, 'not_enough'
            end
            if def.use == 'component' then
                local slots = M.limits(data)
                for slot = 1, slots do
                    local entry = data.items[tostring(slot)]
                    if entry and entry.name == name then
                        local installed, reason, presentation = S.installAttachment(source, data, slot)
                        effect = presentation
                        return installed, reason
                    end
                end
                return false, 'not_enough'
            end
            return M.remove(data, name, 1)
        end)
        if ok and S.live(source, session) and def.use ~= 'backpack' and def.use ~= 'clothing' then
            S.sendWeaponEffect(source, effect or { kind = def.use, name = name })
        end
    end) end
end
