-- ESX addoninventory uses the ox RegisterStash contract even with a custom provider.
-- Registration is synchronous and independent of database readiness. Contents use
-- the existing durable container coordinator, never the legacy addon item cache.
local S, M = Inventory.store, Inventory.model
local definitions = {}
local provider = GetCurrentResourceName()

local function location(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return nil end
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        if type(value[axis]) ~= 'number' or value[axis] ~= value[axis] or math.abs(value[axis]) > 20000 then return nil end
    end
    local bucket = type(value) == 'table' and value.bucket or 0
    if not M.integer(bucket or 0, 0, 2147483647) then return nil end
    return { x = value.x, y = value.y, z = value.z, bucket = bucket or 0 }
end

local function register(id, label, slots, maxWeight, owner, groups, coords)
    local resource = GetInvokingResource()
    if not resource or type(id) ~= 'string' or #id > 48 or not id:match('^[%w_-]+$')
        or type(label) ~= 'string' or #label == 0 or #label > 80
        or not M.integer(slots, 1, 200) or not M.integer(maxWeight, 1, 10000000) then
        return false, 'invalid_stash'
    end
    if owner ~= nil and type(owner) ~= 'boolean' and (type(owner) ~= 'string'
        or #owner > 80 or not owner:match('^char%d+:[%w:_-]+$')) then return false, 'invalid_owner' end
    -- The installed esx_addoninventory passes a job string (or false), not a map.
    if type(groups) == 'string' then groups = { [groups] = 0 } end
    local jobs = {}
    if groups ~= nil and groups ~= false then
        if type(groups) ~= 'table' then return false, 'invalid_groups' end
        for name, grade in pairs(groups) do
            if type(name) ~= 'string' or #name > 64 or not name:match('^[%w_-]+$')
                or not M.integer(grade, 0, 100000) then return false, 'invalid_groups' end
            jobs[name] = grade
        end
        if not next(jobs) then return false, 'invalid_groups' end
    end
    local point = coords ~= nil and location(coords) or nil
    if coords ~= nil and not point then return false, 'invalid_location' end
    local previous = definitions[id]
    if previous and previous.resource ~= resource then return false, 'stash_registered' end
    definitions[id] = { resource = resource, label = label, slots = slots, capacity = maxWeight,
        owner = owner, jobs = jobs, coords = point, binding = {}, locationResource = point and resource or nil }
    return true
end

exports('RegisterStash', register)
AddEventHandler('__cfx_export_ox_inventory_RegisterStash', function(set) set(register) end)
Inventory.bridge.RegisterStash = register

-- A trusted server domain supplies a fixed location for ESX's coordinate-less
-- definitions. Never pass client coordinates or register a network event for this.
exports('rpSetStashLocation', function(id, coords)
    local resource, def = GetInvokingResource(), type(id) == 'string' and definitions[id]
    local point = location(coords)
    if not resource or not def or not point then return false, 'invalid_stash' end
    if def.locationResource and def.locationResource ~= resource then return false, 'location_registered' end
    def.coords, def.locationResource, def.binding = point, resource, {}
    return true
end)

local function permitted(source, id, def, binding, owner)
    local session, player = S.player(source)
    if definitions[id] ~= def or def.binding ~= binding or not def.coords or not session
        or (owner and owner ~= session.identifier) then return false end
    if not next(def.jobs) then return true end
    local job = player.getJob and player.getJob() or player.job
    local grade = job and tonumber(job.grade)
    return job ~= nil and def.jobs[job.name] ~= nil and M.integer(grade, 0, 100000) and grade >= def.jobs[job.name]
end

exports('rpOpenStash', function(source, id)
    if not GetInvokingResource() then return false, 'invalid_resource' end
    if not S.ready then return false, 'server_starting' end
    local def = type(id) == 'string' and definitions[id]
    local session = S.player(source)
    if not def or not session or not S.playable(source) then return false, 'invalid_stash' end
    if not def.coords then return false, 'stash_location_required' end
    local owner = def.owner == true and session.identifier or (type(def.owner) == 'string' and def.owner or nil)
    local binding, enabled = def.binding, false
    local function allowed(playerSource) return permitted(playerSource, id, def, binding, owner) end
    local function authorize(playerSource) return enabled and allowed(playerSource) end
    if not allowed(source) then return false, 'stash_forbidden' end
    -- A private stash has no caller-selected owner; full ESX character IDs isolate it.
    local key = 'stash:' .. id .. (owner and ':owner:' .. owner or ':shared')
    if #key > 100 then return false, 'stash_identifier_too_long' end
    local ok, handle, reason = pcall(function()
        -- Do not silently replace existing addon stock with a new empty inventory.
        -- Migration must explicitly reconcile old stock before enabling access.
        if def.resource == 'esx_addoninventory' then
            local count = MySQL.scalar.await('SELECT COUNT(*) FROM addon_inventory_items WHERE inventory_name = ? AND count > 0', { id })
            if tonumber(count) ~= 0 then return false, 'stash_migration_required' end
        end
        if not S.live(source, session) or not allowed(source) then return false, 'session_expired' end
        return S.registerContainer(provider, key, { label = def.label, slots = def.slots, capacity = def.capacity,
            coords = def.coords, owner = owner, authorize = authorize })
    end)
    if not ok then return false, 'database_error' end
    if not handle then return false, reason or 'invalid_stash' end
    if not S.live(source, session) or not allowed(source) then return false, 'session_expired' end
    -- Existing capacities are durable; changing a registration never silently
    -- shrinks storage or discards items. A deliberate migration is required.
    local row = S.cache[handle]
    if row.data.slots ~= def.slots or row.data.capacity ~= def.capacity then return false, 'stash_migration_required' end
    enabled = true
    return S.openContainer(provider, source, handle)
end)

AddEventHandler('onResourceStop', function(resource)
    for id, def in pairs(definitions) do
        if def.resource == resource then
            definitions[id] = nil
        elseif def.locationResource == resource then
            def.coords, def.locationResource, def.binding = nil, nil, {}
        end
    end
end)
