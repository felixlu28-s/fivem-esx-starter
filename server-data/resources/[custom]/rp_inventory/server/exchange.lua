-- Trusted server domains exchange a complete recipe/order under one store lock.
-- Pricing and recipes belong to the caller, capacity and persistence to this provider.
local S, M = Inventory.store, Inventory.model
local function callable(value)
    return type(value) == 'function' or (type(value) == 'table' and value.__cfx_functionReference ~= nil)
end
local function entries(value)
    if type(value) ~= 'table' or #value > 30 then return nil end
    local result = {}
    for key, entry in pairs(value) do
        if not M.integer(key, 1, #value) or type(entry) ~= 'table' or not Inventory.items[entry.name]
            or not M.integer(entry.count, 1, 10000) then return nil end
        if entry.metadata ~= nil and (type(entry.metadata) ~= 'table' or #json.encode(entry.metadata) > 4096) then return nil end
        result[#result + 1] = { name = entry.name, count = entry.count, metadata = entry.metadata and M.copy(entry.metadata) }
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end
exports('rpExchange', function(source, request, remove, add, authorize, beforeCommit, options)
    local resource, session = GetInvokingResource(), S.player(source)
    if not resource or not session or type(request) ~= 'string' or #request < 8 or #request > 55
        or not request:match('^[%w_-]+$') or not callable(authorize)
        or (beforeCommit ~= nil and not callable(beforeCommit)) then return false, 'invalid_request' end
    remove, add = entries(remove), entries(add)
    if not remove or not add or #add == 0 then return false, 'invalid_request' end
    if options ~= nil and (type(options) ~= 'table' or type(options.equipClothing) ~= 'boolean') then return false, 'invalid_request' end
    local equip = options and options.equipClothing == true
    -- Only the fitting-room checkout may commit an already-previewed outfit.
    -- This is a server export, never a client-supplied animation bypass.
    if equip and (resource ~= 'rp_commerce' or #remove > 0) then return false, 'invalid_request' end
    local fingerprint = { remove = remove, add = add }
    if equip then fingerprint.equipClothing = true end
    local operation = resource .. ':' .. request
    if #operation > 80 then return false, 'invalid_request' end
    local function guard() return S.live(source, session) and S.playable(source) and authorize() == true end
    return S.mutate({ session.id }, session.identifier, operation, M.canonical(fingerprint), nil, guard,
        function(copies)
            local data = copies[session.id]
            local worn = {}
            for _, entry in ipairs(remove) do
                local ok, reason = M.remove(data, entry.name, entry.count, entry.metadata)
                if not ok then return false, reason end
            end
            for _, entry in ipairs(add) do
                local metadata = entry.metadata and M.copy(entry.metadata)
                if equip then
                    local category = Inventory.items[entry.name].clothing
                    local garment = metadata and metadata.garment
                    if not data.clothing or not category or entry.count ~= 1 or worn[category] or type(garment) ~= 'table'
                        or garment.id ~= nil or garment.sex ~= data.clothing.sex then return false, 'invalid_garment' end
                    garment.id = S.token('garment')
                    if not M.garment({ name = entry.name, metadata = metadata }) then return false, 'invalid_garment' end
                    worn[category] = garment.id
                end
                local ok, reason = M.add(data, entry.name, entry.count, metadata)
                if not ok then return false, reason end
            end
            for category, id in pairs(worn) do data.clothing.worn[category] = id end
            -- Validate the whole order before ESX debits money. Old garments stay
            -- in their slots; only the worn-ID map changes in this same commit.
            if S.prepareClothing then
                local ok, reason = S.prepareClothing(copies, { session.id })
                if not ok then return false, reason end
            end
            if not M.valid(data) then return false, 'invalid_inventory' end
            if beforeCommit then return beforeCommit() end
            return true
        end, equip)
end)
